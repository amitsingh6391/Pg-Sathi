import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

import '../core/core.dart';
import '../entities/custom_slot.dart';
import '../entities/library.dart';
import '../entities/membership.dart';
import '../entities/slot.dart';
import '../repositories/library_repository.dart';
import '../repositories/membership_repository.dart';
import '../repositories/slot_repository.dart';

/// Use case for getting all memberships for a student.
///
/// Returns all active and pending payment memberships with library details.
/// Used to show both morning and evening slots on student home.
/// Supports both legacy slots and custom slots.
class GetStudentMemberships
    implements
        UseCase<List<StudentMembershipInfo>, GetStudentMembershipsParams> {
  const GetStudentMemberships({
    required this.membershipRepository,
    required this.libraryRepository,
    required this.slotRepository,
  });

  final MembershipRepository membershipRepository;
  final LibraryRepository libraryRepository;
  final SlotRepository slotRepository;

  @override
  Future<Either<Failure, List<StudentMembershipInfo>>> call(
    GetStudentMembershipsParams params,
  ) async {
    final membershipsResult = await membershipRepository.getMembershipsByUserId(
      params.userId,
    );

    return membershipsResult.fold((failure) => Left(failure), (
      memberships,
    ) async {
      final now = DateTime.now();

      final validMemberships = memberships
          .where(
            (m) =>
                m.status == MembershipStatus.active ||
                m.status == MembershipStatus.pendingPayment ||
                m.status == MembershipStatus.expired ||
                (m.startDate.isAfter(now) &&
                    (m.status == MembershipStatus.pendingPayment ||
                        m.status == MembershipStatus.active)),
          )
          .toList();

      final libraryCache = <String, Library>{};
      final customSlotCache = <String, Map<String, CustomSlot>>{};

      // Prefetch all libraries + all slot lists in parallel before the loop.
      final uniqueLibraryIds = validMemberships.map((m) => m.libraryId).toSet();
      final uniqueLibraryIdsWithSlots = validMemberships
          .where((m) => m.slotId != null && m.slotId!.isNotEmpty)
          .map((m) => m.libraryId)
          .toSet();

      await Future.wait([
        ...uniqueLibraryIds.map((id) async {
          final r = await libraryRepository.getLibraryById(id);
          r.fold((_) {}, (lib) { if (lib != null) libraryCache[id] = lib; });
        }),
        ...uniqueLibraryIdsWithSlots.map((id) async {
          final r = await slotRepository.getSlotsByLibraryId(id);
          r.fold((_) {}, (slots) {
            customSlotCache[id] = {for (final s in slots) s.id: s};
          });
        }),
      ]);

      final membershipGroups = <String, List<Membership>>{};

      for (final m in validMemberships) {
        final slotKey = m.slotId ?? m.slot?.name ?? 'unknown';
        final groupKey = '${m.libraryId}_$slotKey';

        if (!membershipGroups.containsKey(groupKey)) {
          membershipGroups[groupKey] = [];
        }
        membershipGroups[groupKey]!.add(m);
      }

      final sortedGroups = membershipGroups.values.toList()
        ..sort((a, b) {
          final aSlot =
              a.first.slot?.index ?? (a.first.slotId != null ? 0 : 999);
          final bSlot =
              b.first.slot?.index ?? (b.first.slotId != null ? 0 : 999);
          if (aSlot != bSlot) return aSlot.compareTo(bSlot);
          return (a.first.startDate).compareTo(b.first.startDate);
        });

      final infos = <StudentMembershipInfo>[];

      for (final group in sortedGroups) {
        // Categorize memberships: expired, current (active/pending that has started), upcoming
        final expiredMemberships = group
            .where((m) => m.isExpired(now))
            .toList();

        // Current: has started (startDate <= now) and is active/pending
        final currentMemberships = group
            .where(
              (m) =>
                  !m.isExpired(now) &&
                  !m.startDate.isAfter(now) &&
                  (m.status == MembershipStatus.active ||
                      m.status == MembershipStatus.pendingPayment),
            )
            .toList();

        // Upcoming: future start date (startDate > now) and is active/pending
        final upcomingMemberships = group
            .where(
              (m) =>
                  m.startDate.isAfter(now) &&
                  (m.status == MembershipStatus.pendingPayment ||
                      m.status == MembershipStatus.active),
            )
            .toList();

        // If there are expired memberships and upcoming memberships with same slot,
        // merge them: show current/upcoming as primary, attach expired info
        // If expired has different slot or no upcoming, show expired separately

        // Determine the primary membership to show (current active/pending, or upcoming if no current)
        Membership? primaryMembership;
        Membership? upcomingMembership;

        if (currentMemberships.isNotEmpty) {
          // Sort: active first, then pending
          // If there's an active membership, don't show pending separately - merge them
          currentMemberships.sort((a, b) {
            if (a.status == MembershipStatus.active &&
                b.status != MembershipStatus.active) {
              return -1;
            }
            if (b.status == MembershipStatus.active &&
                a.status != MembershipStatus.active) {
              return 1;
            }
            return a.startDate.compareTo(b.startDate);
          });

          primaryMembership = currentMemberships.first;

          // If primary is active, attach any pending payment memberships as upcoming
          // If primary is pending, check if there are active ones (shouldn't happen, but handle it)
          if (primaryMembership.status == MembershipStatus.active) {
            // Active membership - attach pending/upcoming as upcoming
            final activePrimary = primaryMembership;
            final pendingCurrent = currentMemberships
                .skip(1)
                .where((m) => m.status == MembershipStatus.pendingPayment)
                .toList();

            if (pendingCurrent.isNotEmpty) {
              // Attach pending payment as upcoming (even though it's current, it's not active)
              pendingCurrent.sort((a, b) => a.startDate.compareTo(b.startDate));
              upcomingMembership = pendingCurrent.first;
            } else {
              // Stacked active renewal: owner activated the next plan before the current
              // period ends. Both have startDate <= now, so the renewal is not in
              // [upcomingMemberships]; still surface it as upcoming on the card.
              final laterActive = currentMemberships
                  .skip(1)
                  .where(
                    (m) =>
                        m.status == MembershipStatus.active &&
                        !m.isExpired(now) &&
                        _membershipDay(m.startDate).isAfter(
                          _membershipDay(activePrimary.startDate),
                        ),
                  )
                  .toList();
              if (laterActive.isNotEmpty) {
                laterActive.sort((a, b) => a.startDate.compareTo(b.startDate));
                upcomingMembership = laterActive.first;
              } else if (upcomingMemberships.isNotEmpty) {
                // Future-dated memberships
                upcomingMemberships.sort(
                  (a, b) => a.startDate.compareTo(b.startDate),
                );
                upcomingMembership = upcomingMemberships.first;
              }
            }
          } else {
            // Primary is pending - check if there are upcoming active ones
            if (upcomingMemberships.isNotEmpty) {
              upcomingMemberships.sort(
                (a, b) => a.startDate.compareTo(b.startDate),
              );
              upcomingMembership = upcomingMemberships.first;
            }
          }
        } else if (upcomingMemberships.isNotEmpty) {
          // No current membership, use upcoming as primary
          upcomingMemberships.sort(
            (a, b) => a.startDate.compareTo(b.startDate),
          );
          primaryMembership = upcomingMemberships.first;
          // Check if there are more upcoming memberships
          if (upcomingMemberships.length > 1) {
            upcomingMembership = upcomingMemberships[1];
          }
        }

        // Process primary membership (if exists)
        if (primaryMembership != null) {
          final library = await _getLibrary(
            primaryMembership.libraryId,
            libraryCache,
            libraryRepository,
          );
          final customSlot = await _getCustomSlot(
            primaryMembership,
            customSlotCache,
            slotRepository,
            libraryCache,
            libraryRepository,
          );

          final isCurrentActive =
              primaryMembership.status == MembershipStatus.active &&
              !primaryMembership.isExpired(now);

          infos.add(
            StudentMembershipInfo(
              membership: primaryMembership,
              library: library,
              libraryName: library?.name,
              customSlot: customSlot,
              daysRemaining: isCurrentActive
                  ? primaryMembership.daysRemaining(now)
                  : (primaryMembership.startDate.isAfter(now)
                        ? primaryMembership.daysRemaining(
                            primaryMembership.startDate,
                          )
                        : 0),
              isPendingPayment:
                  primaryMembership.status == MembershipStatus.pendingPayment,
              isActive: isCurrentActive,
              isExpired: primaryMembership.isExpired(now),
              upcomingMembership: upcomingMembership,
            ),
          );
        }

        // Process expired memberships separately ONLY if they don't have same slot as primary/upcoming
        // AND if there's no active membership for the same library/slot
        for (final expiredMembership in expiredMemberships) {
          // Check if this expired membership has same slot as primary or upcoming
          final hasSameSlotAsPrimary =
              primaryMembership != null &&
              _hasSameSlot(expiredMembership, primaryMembership);
          final hasSameSlotAsUpcoming =
              upcomingMembership != null &&
              _hasSameSlot(expiredMembership, upcomingMembership);

          // Check if there's ANY active membership for the same library/slot
          // If student has active membership, hide expired ones for the same slot
          final hasActiveMembershipForSameSlot = currentMemberships.any(
            (m) =>
                m.status == MembershipStatus.active &&
                !m.isExpired(now) &&
                _hasSameSlot(expiredMembership, m),
          );

          // Only show expired separately if:
          // 1. It has different slot than primary/upcoming, AND
          // 2. There's no active membership for the same library/slot
          if (!hasSameSlotAsPrimary &&
              !hasSameSlotAsUpcoming &&
              !hasActiveMembershipForSameSlot) {
            final library = await _getLibrary(
              expiredMembership.libraryId,
              libraryCache,
              libraryRepository,
            );
            final customSlot = await _getCustomSlot(
              expiredMembership,
              customSlotCache,
              slotRepository,
              libraryCache,
              libraryRepository,
            );

            infos.add(
              StudentMembershipInfo(
                membership: expiredMembership,
                library: library,
                libraryName: library?.name,
                customSlot: customSlot,
                daysRemaining: 0,
                isPendingPayment: false,
                isActive: false,
                isExpired: true,
              ),
            );
          }
        }
      }

      return Right(infos);
    });
  }

  Future<Library?> _getLibrary(
    String libraryId,
    Map<String, Library> libraryCache,
    LibraryRepository libraryRepository,
  ) async {
    if (libraryCache.containsKey(libraryId)) {
      return libraryCache[libraryId];
    }
    final libraryResult = await libraryRepository.getLibraryById(libraryId);
    Library? library;
    libraryResult.fold((_) {}, (lib) {
      if (lib != null) {
        library = lib;
        libraryCache[libraryId] = lib;
      }
    });
    return library;
  }

  /// Helper method to fetch and cache custom slot.
  Future<CustomSlot?> _getCustomSlot(
    Membership membership,
    Map<String, Map<String, CustomSlot>> customSlotCache,
    SlotRepository slotRepository,
    Map<String, Library> libraryCache,
    LibraryRepository libraryRepository,
  ) async {
    if (membership.slotId == null || membership.slotId!.isEmpty) {
      return null;
    }

    // Check cache first
    if (customSlotCache.containsKey(membership.libraryId)) {
      return customSlotCache[membership.libraryId]![membership.slotId!];
    }

    // Fetch all slots for this library and cache them
    final slotsResult = await slotRepository.getSlotsByLibraryId(
      membership.libraryId,
    );
    CustomSlot? customSlot;
    slotsResult.fold((_) {}, (slots) {
      final slotMap = <String, CustomSlot>{};
      for (final slot in slots) {
        slotMap[slot.id] = slot;
      }
      customSlotCache[membership.libraryId] = slotMap;
      customSlot = slotMap[membership.slotId!];
    });
    return customSlot;
  }

  /// Check if two memberships have the same slot (for merging logic).
  DateTime _membershipDay(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _hasSameSlot(Membership a, Membership b) {
    // Compare slotId first (for custom slots)
    if (a.slotId != null &&
        a.slotId!.isNotEmpty &&
        b.slotId != null &&
        b.slotId!.isNotEmpty) {
      return a.slotId == b.slotId;
    }
    // Compare legacy slot enum
    if (a.slot != null && b.slot != null) {
      return a.slot == b.slot;
    }
    // If one has slotId and other has slot enum, they're different
    return false;
  }
}

/// Parameters for GetStudentMemberships use case.
class GetStudentMembershipsParams extends Equatable {
  const GetStudentMembershipsParams({required this.userId});

  final String userId;

  @override
  List<Object?> get props => [userId];
}

/// Information about a student's membership with library details.
class StudentMembershipInfo extends Equatable {
  const StudentMembershipInfo({
    required this.membership,
    required this.daysRemaining,
    required this.isPendingPayment,
    required this.isActive,
    required this.isExpired,
    this.library,
    this.libraryName,
    this.customSlot,
    this.upcomingMembership,
  });

  final Membership membership;
  final int daysRemaining;
  final bool isPendingPayment;
  final bool isActive;
  final bool isExpired;

  /// The library entity for this membership.
  final Library? library;

  /// Name of the library for this membership.
  final String? libraryName;

  /// Custom slot if membership uses custom slot (null for legacy slots).
  final CustomSlot? customSlot;

  /// Upcoming membership for the same slot/plan (if exists).
  /// Used to show future membership details in the same card.
  final Membership? upcomingMembership;

  /// Whether there's an upcoming membership that needs payment.
  bool get hasUpcomingMembershipPendingPayment =>
      upcomingMembership != null &&
      upcomingMembership!.status == MembershipStatus.pendingPayment;

  /// Amount to pay (based on plan, custom slot price, partial payments, and discount).
  double get paymentAmount {
    // Calculate base amount
    double baseAmount;

    // If custom slot is available, calculate based on slot price and effective duration
    if (customSlot != null) {
      final durationInDays = membership.effectiveDurationInDays;
      final months = durationInDays / 30.0;
      baseAmount = customSlot!.price * months;
    } else {
      // Fallback to hardcoded values for legacy slots
      switch (membership.plan) {
        case MembershipPlan.daily:
          baseAmount = 50.0;
          break;
        case MembershipPlan.weekly:
          baseAmount = 300.0;
          break;
        case MembershipPlan.monthly:
          baseAmount = 1000.0;
          break;
        case MembershipPlan.quarterly:
          baseAmount = 2500.0;
          break;
        case MembershipPlan.yearly:
          baseAmount = 8000.0;
          break;
      }
    }

    // Apply discount if present
    final discount = membership.paymentBreakdown?.discount ?? 0.0;
    final amountAfterDiscount = (baseAmount - discount).clamp(
      0.0,
      double.infinity,
    );

    // If there's a partial payment, return the remaining balance (already accounts for discount)
    if (hasPartialPayment && membership.paymentBreakdown != null) {
      return membership.paymentBreakdown!.amountRemaining;
    }

    // Return amount after discount
    return amountAfterDiscount;
  }

  /// Formatted validity date (end date).
  DateTime get validTill => membership.endDate;

  /// Formatted valid till string.
  String get validTillFormatted =>
      DateFormat('MMM dd, yyyy').format(membership.endDate);

  /// Seat number for display.
  String get seatNumber => membership.assignedSeatId ?? 'Not assigned';

  /// Slot display name (supports both legacy and custom slots).
  String get slotName {
    if (customSlot != null) {
      return customSlot!.name;
    }
    return membership.slot?.displayName ?? 'Unknown';
  }

  /// Session timing display (supports both legacy and custom slots).
  String get sessionTiming {
    if (customSlot != null) {
      return customSlot!.displayTime;
    }
    if (membership.slot != null) {
      switch (membership.slot!) {
        case Slot.morning:
          return '6:00 AM – 2:00 PM';
        case Slot.evening:
          return '2:00 PM – 10:00 PM';
      }
    }
    return 'Not assigned';
  }

  /// Get slot for display (legacy slot or derived from custom slot).
  Slot? get displaySlot {
    if (membership.slot != null) {
      return membership.slot;
    }
    // Derive from custom slot timing if available
    if (customSlot != null) {
      final startHour = customSlot!.startTimeOfDay.hour;
      // Morning: 6 AM - 2 PM (6-14), Evening: 2 PM - 10 PM (14-22)
      if (startHour >= 6 && startHour < 14) {
        return Slot.morning;
      } else if (startHour >= 14 && startHour < 22) {
        return Slot.evening;
      }
    }
    return null;
  }

  /// Check if membership has partial payment.
  bool get hasPartialPayment => membership.hasPartialPayment;

  /// Remaining balance if partial payment.
  double get remainingBalance {
    if (membership.paymentBreakdown != null) {
      return membership.paymentBreakdown!.amountRemaining;
    }
    return 0.0;
  }

  @override
  List<Object?> get props => [
    membership,
    daysRemaining,
    isPendingPayment,
    isActive,
    isExpired,
    library,
    libraryName,
    customSlot,
    upcomingMembership,
  ];
}
