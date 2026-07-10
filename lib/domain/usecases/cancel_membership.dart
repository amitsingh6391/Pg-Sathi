import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../core/core.dart';
import '../entities/membership.dart';
import '../failures/membership_failures.dart';
import '../repositories/membership_repository.dart';

/// Use case for cancelling a membership (early exit).
/// Frees the seat immediately - membership data is retained.
/// Only the targeted membership is affected; sibling memberships are untouched.
class CancelMembership implements UseCase<Membership, CancelMembershipParams> {
  const CancelMembership({required this.membershipRepository});

  final MembershipRepository membershipRepository;

  @override
  Future<Either<Failure, Membership>> call(
    CancelMembershipParams params,
  ) async {
    if (params.membershipId.trim().isEmpty) {
      return const Left(
        InvalidMembershipDataFailure(message: 'Membership ID is required'),
      );
    }

    final existingResult = await membershipRepository.getMembershipById(
      params.membershipId,
    );

    return existingResult.fold((failure) => Left(failure), (existing) async {
      if (existing.status != MembershipStatus.active &&
          existing.status != MembershipStatus.pendingPayment &&
          existing.status != MembershipStatus.expired) {
        return const Left(
          MembershipNotActiveFailure(
            message:
                'Only active, pending, or expired memberships can be removed',
          ),
        );
      }

      final cancelled = existing.cancel();
      return membershipRepository.updateMembership(cancelled);
    });
  }
}

/// Parameters for CancelMembership use case.
class CancelMembershipParams extends Equatable {
  const CancelMembershipParams({required this.membershipId, this.reason});

  final String membershipId;
  final String? reason; // Optional cancellation reason for audit

  @override
  List<Object?> get props => [membershipId, reason];
}
