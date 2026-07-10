import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/referral.dart';

void main() {
  group('Referral', () {
    const referral = Referral(
      id: 'ref_1',
      ownerId: 'owner_1',
      code: 'LT-ABC-1234',
      isActive: true,
      totalRedemptions: 3,
      successfulConversions: 1,
    );

    test('should_have_correct_hasConversions_when_conversions_exist', () {
      expect(referral.hasConversions, isTrue);
    });

    test('should_return_false_hasConversions_when_no_conversions', () {
      final noConversions = referral.copyWith(successfulConversions: 0);
      expect(noConversions.hasConversions, isFalse);
    });

    test('should_increment_redemption_count', () {
      final incremented = referral.incrementRedemption();
      expect(incremented.totalRedemptions, 4);
      expect(incremented.updatedAt, isNotNull);
    });

    test('should_increment_conversion_count', () {
      final incremented = referral.incrementConversion();
      expect(incremented.successfulConversions, 2);
      expect(incremented.updatedAt, isNotNull);
    });

    test('should_preserve_other_fields_on_copyWith', () {
      final copy = referral.copyWith(isActive: false);
      expect(copy.id, referral.id);
      expect(copy.ownerId, referral.ownerId);
      expect(copy.code, referral.code);
      expect(copy.isActive, isFalse);
      expect(copy.totalRedemptions, referral.totalRedemptions);
    });
  });

  group('ReferralRedemption', () {
    final redemption = ReferralRedemption(
      id: 'red_1',
      referralCode: 'LT-ABC-1234',
      referrerId: 'owner_1',
      refereeId: 'owner_2',
      status: ReferralRedemptionStatus.pending,
      createdAt: DateTime(2026, 1, 1),
    );

    test('should_be_pending_when_status_is_pending', () {
      expect(redemption.isPending, isTrue);
      expect(redemption.isConverted, isFalse);
    });

    test('should_mark_as_converted_with_subscription_id', () {
      final converted = redemption.markConverted(subscriptionId: 'sub_1');
      expect(converted.status, ReferralRedemptionStatus.converted);
      expect(converted.subscriptionId, 'sub_1');
      expect(converted.convertedAt, isNotNull);
      expect(converted.isConverted, isTrue);
    });

    test('should_claim_reward_with_type', () {
      final converted = redemption.markConverted(subscriptionId: 'sub_1');
      final claimed = converted.claimReward(ReferralRewardType.freeMonth);
      expect(claimed.rewardType, ReferralRewardType.freeMonth);
      expect(claimed.rewardClaimed, isTrue);
    });

    test('should_claim_wallet_credit_reward', () {
      final converted = redemption.markConverted(subscriptionId: 'sub_1');
      final claimed = converted.claimReward(ReferralRewardType.walletCredit);
      expect(claimed.rewardType, ReferralRewardType.walletCredit);
      expect(claimed.rewardClaimed, isTrue);
    });
  });

  group('ReferralWallet', () {
    const wallet = ReferralWallet(
      ownerId: 'owner_1',
      balance: 149,
      totalEarned: 298,
      totalWithdrawn: 149,
    );

    test('should_add_credit_correctly', () {
      final updated = wallet.addCredit(149);
      expect(updated.balance, 298);
      expect(updated.totalEarned, 447);
      expect(updated.totalWithdrawn, 149);
    });

    test('should_withdraw_correctly', () {
      final updated = wallet.withdraw(100);
      expect(updated.balance, 49);
      expect(updated.totalWithdrawn, 249);
      expect(updated.totalEarned, 298);
    });

    test('should_check_canWithdraw_when_sufficient_balance', () {
      expect(wallet.canWithdraw(149), isTrue);
      expect(wallet.canWithdraw(150), isFalse);
    });

    test('should_have_correct_creditPerReferral_constant', () {
      expect(ReferralWallet.creditPerReferral, 149.0);
    });
  });

  group('WithdrawalRequest', () {
    test('should_create_with_pending_status', () {
      final request = WithdrawalRequest(
        id: 'wd_1',
        ownerId: 'owner_1',
        amount: 149,
        status: WithdrawalStatus.pending,
        upiId: 'test@upi',
        createdAt: DateTime.now(),
      );

      expect(request.status, WithdrawalStatus.pending);
      expect(request.amount, 149);
      expect(request.upiId, 'test@upi');
    });
  });
}
