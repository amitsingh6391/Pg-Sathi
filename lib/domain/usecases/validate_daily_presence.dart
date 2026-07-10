import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../core/core.dart';
import '../entities/membership.dart';
import '../entities/presence.dart';
import '../failures/membership_failures.dart';
import '../failures/presence_failures.dart';
import '../repositories/membership_repository.dart';
import '../repositories/presence_repository.dart';

/// Use case for validating and recording daily presence (check-in).
///
/// Validates that:
/// - Student has active membership
/// - Student is not already checked in today
/// - Records check-in if valid
class ValidateDailyPresence
    implements UseCase<Presence, ValidateDailyPresenceParams> {
  const ValidateDailyPresence({
    required this.presenceRepository,
    required this.membershipRepository,
  });

  final PresenceRepository presenceRepository;
  final MembershipRepository membershipRepository;

  @override
  Future<Either<Failure, Presence>> call(
    ValidateDailyPresenceParams params,
  ) async {
    // Step 1: Validate membership
    final membershipResult = await membershipRepository
        .getActiveMembershipByUserAndLibrary(
          userId: params.userId,
          libraryId: params.libraryId,
        );

    return membershipResult.fold((failure) => Left(failure), (
      membership,
    ) async {
      if (membership == null) {
        return const Left(
          MembershipNotFoundFailure(message: 'No active membership found'),
        );
      }

      if (!membership.isActive(params.checkInTime)) {
        return Left(_getMembershipFailure(membership, params.checkInTime));
      }

      // Step 2: Check if already checked in today
      final existingPresenceResult = await presenceRepository
          .getTodayPresenceByUserAndLibrary(
            userId: params.userId,
            libraryId: params.libraryId,
            date: _getDateOnly(params.checkInTime),
          );

      return existingPresenceResult.fold((failure) => Left(failure), (
        existingPresence,
      ) async {
        if (existingPresence != null && existingPresence.isCurrentlyPresent) {
          return const Left(
            AlreadyCheckedInFailure(message: 'Already checked in today'),
          );
        }

        // Step 3: Record check-in
        final presence = Presence(
          id: params.presenceId,
          userId: params.userId,
          libraryId: params.libraryId,
          date: _getDateOnly(params.checkInTime),
          checkInTime: params.checkInTime,
          seatId: membership.assignedSeatId,
          status: PresenceStatus.checkedIn,
        );

        return presenceRepository.checkIn(presence);
      });
    });
  }

  DateTime _getDateOnly(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }

  Failure _getMembershipFailure(Membership membership, DateTime currentTime) {
    if (membership.isExpired(currentTime)) {
      return const MembershipExpiredFailure();
    }
    if (membership.status == MembershipStatus.suspended) {
      return const MembershipInactiveFailure(
        message: 'Membership is suspended',
      );
    }
    if (membership.status == MembershipStatus.cancelled) {
      return const MembershipInactiveFailure(
        message: 'Membership is cancelled',
      );
    }
    return const MembershipNotActiveFailure();
  }
}

/// Parameters for ValidateDailyPresence use case.
class ValidateDailyPresenceParams extends Equatable {
  const ValidateDailyPresenceParams({
    required this.presenceId,
    required this.userId,
    required this.libraryId,
    required this.checkInTime,
  });

  final String presenceId;
  final String userId;
  final String libraryId;
  final DateTime checkInTime;

  @override
  List<Object?> get props => [presenceId, userId, libraryId, checkInTime];
}
