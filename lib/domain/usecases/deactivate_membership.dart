import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../core/core.dart';
import '../entities/membership.dart';
import '../failures/membership_failures.dart';
import '../repositories/membership_repository.dart';

/// Use case for deactivating a membership (student leaves early).
/// Marks membership as cancelled, seat becomes available.
/// Membership data is retained (no delete).
class DeactivateMembership
    implements UseCase<Membership, DeactivateMembershipParams> {
  const DeactivateMembership({required this.membershipRepository});

  final MembershipRepository membershipRepository;

  @override
  Future<Either<Failure, Membership>> call(
    DeactivateMembershipParams params,
  ) async {
    // Validate input
    if (params.membershipId.trim().isEmpty) {
      return const Left(
        InvalidMembershipDataFailure(message: 'Membership ID is required'),
      );
    }

    // Get existing membership
    final existingResult = await membershipRepository.getMembershipById(
      params.membershipId,
    );

    return existingResult.fold((failure) => Left(failure), (existing) async {
      // Check if already inactive
      if (existing.status != MembershipStatus.active) {
        return const Left(
          MembershipNotActiveFailure(message: 'Membership is already inactive'),
        );
      }

      // Mark as cancelled (not expired - explicit deactivation)
      // Clear seat assignment to make it available
      final deactivated = existing
          .copyWith(status: MembershipStatus.cancelled)
          .clearSeat();

      return membershipRepository.updateMembership(deactivated);
    });
  }
}

/// Parameters for DeactivateMembership use case.
class DeactivateMembershipParams extends Equatable {
  const DeactivateMembershipParams({required this.membershipId});

  final String membershipId;

  @override
  List<Object?> get props => [membershipId];
}
