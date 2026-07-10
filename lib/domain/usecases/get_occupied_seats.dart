import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../core/core.dart';
import '../entities/membership.dart';
import '../entities/user.dart';
import '../repositories/membership_repository.dart';
import '../repositories/user_repository.dart';

/// Use case for retrieving occupied AND reserved seats with membership details.
/// Returns list of active and pendingPayment memberships for a library.
/// Now includes student name and phone for each membership.
class GetOccupiedSeats
    implements UseCase<List<OccupiedSeatInfo>, GetOccupiedSeatsParams> {
  const GetOccupiedSeats({
    required this.membershipRepository,
    required this.userRepository,
  });

  final MembershipRepository membershipRepository;
  final UserRepository userRepository;

  @override
  Future<Either<Failure, List<OccupiedSeatInfo>>> call(
    GetOccupiedSeatsParams params,
  ) async {
    if (params.libraryId.trim().isEmpty) {
      return const Right([]);
    }

    // Fetch both active AND reserved memberships (already filtered by status at DB level)
    final result = await membershipRepository
        .getActiveAndReservedMembershipsForLibrary(params.libraryId);

    return result.fold((failure) => Left(failure), (memberships) async {
      final now = DateTime.now();

      // Filter memberships with assigned seats (in memory - Firestore doesn't support null checks)
      // Also exclude any expired-status memberships that may have slipped through
      final membershipsWithSeats = memberships
          .where(
            (m) =>
                m.assignedSeatId != null &&
                m.assignedSeatId!.isNotEmpty &&
                m.status != MembershipStatus.expired &&
                m.status != MembershipStatus.cancelled,
          )
          .toList();

      // Group memberships by bed. PG occupancy is bed-based, not slot/time-based.
      final membershipGroups = <String, List<Membership>>{};

      for (final m in membershipsWithSeats) {
        final groupKey = m.assignedSeatId!;

        if (!membershipGroups.containsKey(groupKey)) {
          membershipGroups[groupKey] = [];
        }
        membershipGroups[groupKey]!.add(m);
      }

      // Collect all userIds for batch fetch (much faster than N individual queries!)
      final userIds = membershipsWithSeats
          .where((m) => m.userId != null)
          .map((m) => m.userId!)
          .toSet()
          .toList();

      // Batch fetch all users at once (uses Future.wait internally)
      Map<String, User> usersMap = {};
      if (userIds.isNotEmpty) {
        final usersResult = await userRepository.getUsersByIds(userIds);
        usersResult.fold(
          (_) {
            // Failed to fetch users, continue with empty map
          },
          (users) {
            usersMap = users;
          },
        );
      }

      // Process each bed group and pick the current stay plus any upcoming stay.
      final processedMemberships = <Membership>[];
      final upcomingMemberships0 = <String, Membership>{};

      for (final group in membershipGroups.values) {
        // Categorize: expired, current (active/pending that has started), upcoming (future start date)
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

        // Determine primary membership to show
        Membership? primaryMembership;
        Membership? upcomingMembership;

        if (currentMemberships.isNotEmpty) {
          // Sort: active first, then pending
          // If there's an active membership, don't show pending separately - attach as upcoming
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
              final laterActive = currentMemberships
                  .skip(1)
                  .where(
                    (m) =>
                        m.status == MembershipStatus.active &&
                        !m.isExpired(now) &&
                        _membershipDay(
                          m.startDate,
                        ).isAfter(_membershipDay(activePrimary.startDate)),
                  )
                  .toList();
              if (laterActive.isNotEmpty) {
                laterActive.sort((a, b) => a.startDate.compareTo(b.startDate));
                upcomingMembership = laterActive.first;
              } else if (upcomingMemberships.isNotEmpty) {
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
          // No current, use upcoming as primary
          upcomingMemberships.sort(
            (a, b) => a.startDate.compareTo(b.startDate),
          );
          primaryMembership = upcomingMemberships.first;
          // Check if there are more upcoming memberships
          if (upcomingMemberships.length > 1) {
            upcomingMembership = upcomingMemberships[1];
          }
        } else if (expiredMemberships.isNotEmpty) {
          // Only expired memberships - show the most recent expired
          expiredMemberships.sort(
            (a, b) => (b.createdAt ?? DateTime(1970)).compareTo(
              a.createdAt ?? DateTime(1970),
            ),
          );
          primaryMembership = expiredMemberships.first;
        }

        if (primaryMembership != null) {
          // Store primary with upcoming for later processing
          processedMemberships.add(primaryMembership);
          // Store upcoming membership mapping
          if (upcomingMembership != null) {
            upcomingMemberships0[primaryMembership.id] = upcomingMembership;
          }
        }
      }

      // Build occupied seats list using the processed memberships
      final occupiedSeats = processedMemberships.map((membership) {
        String? studentName;
        String? studentPhone = membership.phoneNumber;
        String? studentAvatarUrl;

        if (membership.userId != null) {
          // Registered student - get from pre-fetched map
          final user = usersMap[membership.userId];
          if (user != null) {
            studentName = user.displayName;
            studentPhone = user.phone;
            studentAvatarUrl = user.avatarUrl;
          }
        } else {
          // Unregistered student - use studentName from membership if available
          studentName = membership.studentName;
        }

        return OccupiedSeatInfo(
          seatId: membership.assignedSeatId!,
          membership: membership,
          studentName: studentName,
          studentPhone: studentPhone,
          studentAvatarUrl: studentAvatarUrl,
          upcomingMembership: upcomingMemberships0[membership.id],
        );
      }).toList();

      // Sort by seat serial (1, 2, 3…) so the list matches physical layout.
      occupiedSeats.sort((a, b) {
        final bySeat = a.seatNumber.compareTo(b.seatNumber);
        if (bySeat != 0) return bySeat;
        return a.seatId.compareTo(b.seatId);
      });

      return Right(occupiedSeats);
    });
  }

  DateTime _membershipDay(DateTime d) => DateTime(d.year, d.month, d.day);
}

/// Parameters for GetOccupiedSeats use case.
class GetOccupiedSeatsParams extends Equatable {
  const GetOccupiedSeatsParams({required this.libraryId});

  final String libraryId;

  @override
  List<Object?> get props => [libraryId];
}

/// Information about an occupied or reserved seat.
/// Now includes student name and phone for owner display.
class OccupiedSeatInfo extends Equatable {
  const OccupiedSeatInfo({
    required this.seatId,
    required this.membership,
    this.studentName,
    this.studentPhone,
    this.studentAvatarUrl,
    this.upcomingMembership,
  });

  final String seatId;
  final Membership membership;

  /// Student's display name (from User entity).
  final String? studentName;

  /// Student's phone number.
  final String? studentPhone;

  /// Student's profile picture URL (from User entity).
  final String? studentAvatarUrl;

  /// Upcoming membership for the same slot (if exists).
  /// Used to show future membership details in the same card.
  final Membership? upcomingMembership;

  /// Seat number extracted from seatId (e.g., "S01" -> 1).
  int get seatNumber {
    final numStr = seatId.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(numStr) ?? 0;
  }

  /// Whether membership is pending payment (reserved).
  bool get isReserved => membership.status == MembershipStatus.pendingPayment;

  /// Whether membership is active (occupied).
  bool get isOccupied => membership.status == MembershipStatus.active;

  /// Whether membership is expired.
  /// Uses date-only comparison to match daysRemaining logic.
  /// A membership expiring today (daysRemaining == 0) is not considered expired.
  bool get isExpired {
    if (membership.status == MembershipStatus.expired) return true;
    if (membership.status != MembershipStatus.active) return false;

    // Use date-only comparison to match daysRemaining calculation
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endDateOnly = DateTime(
      membership.endDate.year,
      membership.endDate.month,
      membership.endDate.day,
    );

    // Only expired if today (current date) is AFTER the end date
    // If today equals end date, membership is still valid for that day
    return today.isAfter(endDateOnly);
  }

  /// Days until membership expires.
  int get daysRemaining => membership.daysRemaining(DateTime.now());

  /// Whether membership is expiring soon (within 7 days, including today and expired).
  bool get isExpiringSoon =>
      isOccupied && daysRemaining <= 7 && daysRemaining >= 0;

  /// Display name for UI (falls back to phone number).
  String get displayName =>
      studentName ?? studentPhone ?? membership.phoneNumber;

  /// Whether there's an upcoming membership that needs payment.
  bool get hasUpcomingMembershipPendingPayment =>
      upcomingMembership != null &&
      upcomingMembership!.status == MembershipStatus.pendingPayment;

  /// True when the primary row is an **active** current plan but a **future-dated**
  /// [upcomingMembership] is still awaiting payment. Owner must record payment here;
  /// the main "Activate" button only targets [membership], not the upcoming row.
  bool get hasFuturePendingPlanNeedingPayment =>
      upcomingMembership != null &&
      upcomingMembership!.status == MembershipStatus.pendingPayment &&
      upcomingMembership!.paymentStatus == MembershipPaymentStatus.pending;

  @override
  List<Object?> get props => [
    seatId,
    membership,
    studentName,
    studentPhone,
    studentAvatarUrl,
    upcomingMembership,
  ];
}
