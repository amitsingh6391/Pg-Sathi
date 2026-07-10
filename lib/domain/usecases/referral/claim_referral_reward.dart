import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../core/core.dart';
import '../../entities/referral.dart';
import '../../failures/referral_failures.dart';
import '../../repositories/referral_repository.dart';
import '../../repositories/subscription_repository.dart';

/// Lets the referrer choose their reward for a successful conversion:
/// - [ReferralRewardType.freeMonth]: extends current subscription by 1 month
/// - [ReferralRewardType.walletCredit]: adds ₹149 to referral wallet
class ClaimReferralReward
    implements UseCase<void, ClaimReferralRewardParams> {
  const ClaimReferralReward({
    required this.referralRepository,
    required this.subscriptionRepository,
  });

  final ReferralRepository referralRepository;
  final SubscriptionRepository subscriptionRepository;

  @override
  Future<Either<Failure, void>> call(
    ClaimReferralRewardParams params,
  ) async {
    // Fetch the unclaimed redemption
    final unclaimedResult = await referralRepository.getUnclaimedRewards(
      params.ownerId,
    );

    final unclaimed = unclaimedResult.fold(
      (_) => <ReferralRedemption>[],
      (list) => list,
    );

    final redemption = unclaimed.where(
      (r) => r.id == params.redemptionId,
    );

    if (redemption.isEmpty) {
      return const Left(NoUnclaimedRewardsFailure());
    }

    final target = redemption.first;

    if (params.rewardType == ReferralRewardType.freeMonth) {
      // Extend current subscription by 1 month
      final subResult = await subscriptionRepository.getActiveSubscription(
        params.ownerId,
      );

      return subResult.fold(Left.new, (sub) async {
        if (sub == null || !sub.isActive(DateTime.now())) {
          return const Left(
            ReferralFailure(
              message: 'No active subscription to extend',
            ),
          );
        }

        final newEnd = DateTime(
          sub.endDate.year,
          sub.endDate.month + 1,
          sub.endDate.day,
        );

        final extended = sub.copyWith(endDate: newEnd, updatedAt: DateTime.now());
        await subscriptionRepository.updateSubscription(extended);

        // Mark redemption as claimed
        await referralRepository.updateRedemption(
          target.claimReward(ReferralRewardType.freeMonth),
        );

        return const Right(null);
      });
    } else {
      // Add ₹149 to wallet
      final walletResult = await referralRepository.getOrCreateWallet(
        params.ownerId,
      );

      return walletResult.fold(Left.new, (wallet) async {
        final updated = wallet.addCredit(ReferralWallet.creditPerReferral);
        await referralRepository.updateWallet(updated);

        // Mark redemption as claimed
        await referralRepository.updateRedemption(
          target.claimReward(ReferralRewardType.walletCredit),
        );

        return const Right(null);
      });
    }
  }
}

class ClaimReferralRewardParams extends Equatable {
  const ClaimReferralRewardParams({
    required this.ownerId,
    required this.redemptionId,
    required this.rewardType,
  });

  final String ownerId;
  final String redemptionId;
  final ReferralRewardType rewardType;

  @override
  List<Object?> get props => [ownerId, redemptionId, rewardType];
}
