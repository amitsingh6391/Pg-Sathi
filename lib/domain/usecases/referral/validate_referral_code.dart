import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../core/core.dart';
import '../../entities/referral.dart';
import '../../failures/referral_failures.dart';
import '../../repositories/referral_repository.dart';
import '../../repositories/subscription_repository.dart';

/// Validates a referral code before applying it at checkout.
/// Ensures the referrer has an active subscription and the
/// referee hasn't already used a referral code.
class ValidateReferralCode
    implements UseCase<Referral, ValidateReferralCodeParams> {
  const ValidateReferralCode({
    required this.referralRepository,
    required this.subscriptionRepository,
  });

  final ReferralRepository referralRepository;
  final SubscriptionRepository subscriptionRepository;

  @override
  Future<Either<Failure, Referral>> call(
    ValidateReferralCodeParams params,
  ) async {
    if (params.code.trim().isEmpty) {
      return const Left(InvalidReferralCodeFailure());
    }

    final referralResult = await referralRepository.getReferralByCode(
      params.code.trim().toUpperCase(),
    );

    return referralResult.fold(Left.new, (referral) async {
      if (referral == null || !referral.isActive) {
        return const Left(ReferralCodeNotFoundFailure());
      }

      // Prevent self-referral
      if (referral.ownerId == params.refereeOwnerId) {
        return const Left(SelfReferralNotAllowedFailure());
      }

      // Ensure referee hasn't already used a referral
      final existingRedemption = await referralRepository
          .getRedemptionByReferee(params.refereeOwnerId);

      final alreadyUsed = existingRedemption.fold(
        (_) => false,
        (r) => r != null,
      );

      if (alreadyUsed) {
        return const Left(ReferralAlreadyAppliedFailure());
      }

      // Verify the referrer still has an active subscription
      final subResult = await subscriptionRepository.getActiveSubscription(
        referral.ownerId,
      );

      final referrerActive = subResult.fold(
        (_) => false,
        (sub) => sub != null && sub.isActive(DateTime.now()),
      );

      if (!referrerActive) {
        return const Left(ReferrerNoActiveSubscriptionFailure());
      }

      return Right(referral);
    });
  }
}

class ValidateReferralCodeParams extends Equatable {
  const ValidateReferralCodeParams({
    required this.code,
    required this.refereeOwnerId,
  });

  final String code;
  final String refereeOwnerId;

  @override
  List<Object?> get props => [code, refereeOwnerId];
}
