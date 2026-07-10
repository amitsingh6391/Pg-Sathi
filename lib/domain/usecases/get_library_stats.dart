import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../core/core.dart';
import '../entities/library_stats.dart';
import '../entities/membership.dart';
import '../repositories/membership_repository.dart';
import '../repositories/slot_repository.dart';

/// Use case for getting library statistics with slot-aware occupancy.
///
/// Stats are computed from:
/// - Active slots capacity (total seats from all active slots)
/// - Distinct physical seats (slot + seat id): active vs pending payment
///
/// Multiple membership documents for the same seat (e.g. renewal queued early)
/// count as **one** seat so dashboard availability matches reality.
///
/// Total seats are calculated from the sum of capacities of all active slots.
/// If no slots exist, total seats will be 0.
class GetLibraryStats implements UseCase<LibraryStats, GetLibraryStatsParams> {
  const GetLibraryStats({
    required this.membershipRepository,
    required this.slotRepository,
  });

  final MembershipRepository membershipRepository;
  final SlotRepository slotRepository;

  @override
  Future<Either<Failure, LibraryStats>> call(
    GetLibraryStatsParams params,
  ) async {
    if (params.libraryId.trim().isEmpty) {
      return const Right(LibraryStats.empty());
    }

    // Get active slots for the library to calculate total seats
    final slotsResult = await slotRepository.getActiveSlotsByLibraryId(
      params.libraryId,
    );

    return slotsResult.fold((failure) => Left(failure), (slots) async {
      final slotSum = slots.fold<int>(0, (sum, slot) => sum + slot.capacity);
      final totalSeats = (params.totalSeatCapacity != null && params.totalSeatCapacity! > 0)
          ? params.totalSeatCapacity!
          : slotSum;

      // Get active AND reserved memberships for this library
      final membershipsResult = await membershipRepository
          .getActiveAndReservedMembershipsForLibrary(params.libraryId);

      return membershipsResult.fold((failure) => Left(failure), (memberships) {
        // Count physical seats, not membership rows. Stacked renewals (active + pending
        // or two active periods) on the same seat/slot are one seat — counting rows
        // inflates occupancy and can show negative "available" on the dashboard.
        final now = DateTime.now();
        final seatGroups = <String, List<Membership>>{};

        for (final m in memberships) {
          final seatId = m.assignedSeatId;
          if (seatId == null || seatId.isEmpty) continue;

          final slotKey = (m.slotId != null && m.slotId!.isNotEmpty)
              ? m.slotId!
              : (m.slot?.name ?? '');
          if (slotKey.isEmpty) continue;

          final key = '$slotKey::$seatId';
          seatGroups.putIfAbsent(key, () => []).add(m);
        }

        var occupied = 0;
        var reserved = 0;

        for (final group in seatGroups.values) {
          // isActive checks status == active AND startDate <= now <= endDate,
          // so future-dated advance bookings don't inflate the occupied count.
          final hasActiveSeat = group.any((m) => m.isActive(now));
          final hasPendingSeat = group.any(
            (m) => m.status == MembershipStatus.pendingPayment,
          );

          if (hasActiveSeat) {
            occupied++;
          } else if (hasPendingSeat) {
            reserved++;
          }
        }

        return Right(
          LibraryStats(
            totalSeats: totalSeats,
            occupiedSeats: occupied,
            reservedSeats: reserved,
          ),
        );
      });
    });
  }
}

/// Parameters for GetLibraryStats use case.
class GetLibraryStatsParams extends Equatable {
  const GetLibraryStatsParams({
    required this.libraryId,
    this.totalSeatCapacity,
  });

  final String libraryId;
  final int? totalSeatCapacity;

  @override
  List<Object?> get props => [libraryId, totalSeatCapacity];
}
