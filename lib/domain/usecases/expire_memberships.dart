import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../core/core.dart';
import '../repositories/membership_repository.dart';

/// Use case for expiring memberships that have passed their end date.
///
/// This is typically run as a scheduled job or on app startup.
/// It finds all memberships that should be expired and updates their status.
/// Seat and slot information is preserved so owners can easily reassign without
/// filling all details again. Seat availability is automatically updated since
/// it's computed from active memberships only.
class ExpireMemberships
    implements UseCase<ExpireMembershipsResult, ExpireMembershipsParams> {
  const ExpireMemberships({required this.membershipRepository});

  final MembershipRepository membershipRepository;

  @override
  Future<Either<Failure, ExpireMembershipsResult>> call(
    ExpireMembershipsParams params,
  ) async {
    // Step 1: Get all memberships that should be expired
    final expiredResult = await membershipRepository.getExpiredMemberships(
      params.currentDate,
    );

    return expiredResult.fold((failure) => Left(failure), (memberships) async {
      if (memberships.isEmpty) {
        return const Right(
          ExpireMembershipsResult(expiredCount: 0, expiredMembershipIds: []),
        );
      }

      // Safety check: only expire memberships whose endDate has truly passed.
      // Normalize dates to date-only to prevent time-of-day mismatches.
      final today = DateTime(
        params.currentDate.year,
        params.currentDate.month,
        params.currentDate.day,
      );
      final trulyExpired = memberships.where((m) {
        final endDateOnly = DateTime(
          m.endDate.year,
          m.endDate.month,
          m.endDate.day,
        );
        return today.isAfter(endDateOnly);
      }).toList();

      if (trulyExpired.isEmpty) {
        return const Right(
          ExpireMembershipsResult(expiredCount: 0, expiredMembershipIds: []),
        );
      }

      // Step 2: Mark memberships as expired but keep seat/slot info
      // This allows owners to see expired memberships and reassign easily
      final expiredMemberships = trulyExpired.map((m) {
        // Only change status to expired, keep seat and slot for reassignment
        return m.expire();
      }).toList();

      final updateResult = await membershipRepository
          .batchUpdateMembershipStatus(expiredMemberships);

      return updateResult.fold(
        (failure) => Left(failure),
        (_) => Right(
          ExpireMembershipsResult(
            expiredCount: trulyExpired.length,
            expiredMembershipIds: trulyExpired.map((m) => m.id).toList(),
          ),
        ),
      );
    });
  }
}

/// Parameters for ExpireMemberships use case.
class ExpireMembershipsParams extends Equatable {
  const ExpireMembershipsParams({required this.currentDate});

  final DateTime currentDate;

  @override
  List<Object?> get props => [currentDate];
}

/// Result of expire memberships operation.
class ExpireMembershipsResult extends Equatable {
  const ExpireMembershipsResult({
    required this.expiredCount,
    required this.expiredMembershipIds,
  });

  final int expiredCount;
  final List<String> expiredMembershipIds;

  @override
  List<Object?> get props => [expiredCount, expiredMembershipIds];
}
