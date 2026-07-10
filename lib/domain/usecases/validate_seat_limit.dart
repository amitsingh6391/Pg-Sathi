import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../core/core.dart';
import '../entities/subscription_plan.dart';
import '../failures/subscription_failures.dart';
import '../repositories/library_repository.dart';
import '../repositories/membership_repository.dart';
import '../repositories/subscription_repository.dart';

/// Use case for validating if owner can add more seats.
/// Freemium model: Up to 7 free seats, then paid plan required.
/// With subscription: seats limited by plan tier purchased.
class ValidateSeatLimit implements UseCase<bool, ValidateSeatLimitParams> {
  const ValidateSeatLimit({
    required this.subscriptionRepository,
    required this.libraryRepository,
    required this.membershipRepository,
  });

  final SubscriptionRepository subscriptionRepository;
  final LibraryRepository libraryRepository;
  final MembershipRepository membershipRepository;

  @override
  Future<Either<Failure, bool>> call(ValidateSeatLimitParams params) async {
    final now = DateTime.now();

    // Get owner's library
    final libraryResult = await libraryRepository.getLibraryByOwnerId(params.ownerId);
    
    return libraryResult.fold(
      (failure) => Left(failure),
      (library) async {
        if (library == null) {
          // No library yet - allow up to free limit
          return const Right(true);
        }

        // Count current active/pending memberships for the library
        final membershipsResult = await membershipRepository
            .getActiveAndReservedMembershipsForLibrary(library.id);

        return membershipsResult.fold(
          (failure) => Left(failure),
          (memberships) async {
            final currentActiveSeats = memberships.length;
            final requestedTotalSeats = currentActiveSeats + 1;

            // Check for active subscription
            final subscriptionResult = await subscriptionRepository
                .getActiveSubscription(params.ownerId);

            return subscriptionResult.fold(
              (failure) => Left(failure),
              (subscription) {
                // If has active subscription, check seat limit based on plan
                if (subscription != null && subscription.isActive(now)) {
                  final planSeats = subscription.seatCount;

                  // -1 or very large number means unlimited
                  if (planSeats < 0 || planSeats >= 999999) {
                    return const Right(true);
                  }

                  if (requestedTotalSeats > planSeats) {
                    return Left(SeatLimitExceededFailure(maxSeats: planSeats));
                  }

                  return const Right(true);
                }

                // No active subscription - use freemium model (7 free seats)
                if (requestedTotalSeats <= SubscriptionPlan.freeSeatsLimit) {
                  return const Right(true);
                }

                // Exceeding free limit without subscription
                return Left(SeatLimitExceededFailure(maxSeats: SubscriptionPlan.freeSeatsLimit));
              },
            );
          },
        );
      },
    );
  }
}

/// Parameters for ValidateSeatLimit use case.
class ValidateSeatLimitParams extends Equatable {
  const ValidateSeatLimitParams({
    required this.ownerId,
  });

  final String ownerId;

  @override
  List<Object?> get props => [ownerId];
}
