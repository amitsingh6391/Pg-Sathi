import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../core/core.dart';
import '../entities/subscription.dart';
import '../repositories/referral_repository.dart';
import '../repositories/subscription_repository.dart';

/// Use case for auto-approving Razorpay subscriptions.
/// Razorpay payments are instant and verified, so they bypass manual approval.
/// This activates the subscription immediately after successful payment.
class AutoApproveRazorpaySubscription
    implements UseCase<Subscription, AutoApproveRazorpaySubscriptionParams> {
  const AutoApproveRazorpaySubscription({
    required this.subscriptionRepository,
    this.referralRepository,
  });

  final SubscriptionRepository subscriptionRepository;
  final ReferralRepository? referralRepository;

  @override
  Future<Either<Failure, Subscription>> call(
    AutoApproveRazorpaySubscriptionParams params,
  ) async {
    // Get subscription
    final subscriptionResult = await subscriptionRepository.getSubscriptionById(
      params.subscriptionId,
    );

    return subscriptionResult.fold((failure) => Left(failure), (
      subscription,
    ) async {
      // Fetch trial info early — needed for remaining-days calculation
      final trialResult = await subscriptionRepository.getTrial(
        subscription.ownerId,
      );
      final trial = trialResult.fold((_) => null, (t) => t);

      // Check for existing active subscriptions to extend from
      final historyResult = await subscriptionRepository.getSubscriptionHistory(
        subscription.ownerId,
      );

      final allActiveSubscriptions = historyResult.fold(
        (_) => <Subscription>[],
        (subs) => subs
            .where(
              (s) =>
                  s.status == SubscriptionStatus.active &&
                  s.id != subscription.id,
            )
            .toList(),
      );

      // Find the subscription with the latest end date to extend from
      Subscription? existingToExtendFrom;
      if (allActiveSubscriptions.isNotEmpty) {
        allActiveSubscriptions.sort((a, b) => b.endDate.compareTo(a.endDate));
        existingToExtendFrom = allActiveSubscriptions.first;
      }

      // Determine start date: extend from existing subscription or start now
      final now = DateTime.now();
      final isExtendingExisting =
          existingToExtendFrom != null &&
          existingToExtendFrom.endDate.isAfter(now);

      final DateTime startDate;
      if (isExtendingExisting) {
        // Extend from existing subscription's end date
        startDate = existingToExtendFrom.endDate;
      } else {
        // No existing subscription or it has ended - start now
        startDate = now;
      }

      // Calculate new end date
      var endDate = DateTime(
        startDate.year,
        startDate.month + subscription.durationInMonths,
        startDate.day,
      );

      // Carry over remaining trial days when the owner subscribes during
      // an active trial. Only applies to fresh subscriptions, not extensions
      // of an already-active paid plan.
      if (!isExtendingExisting &&
          trial != null &&
          !trial.isUsed &&
          trial.isActive(now)) {
        final remainingTrialDays = trial.daysRemaining(now);
        if (remainingTrialDays > 0) {
          endDate = endDate.add(Duration(days: remainingTrialDays));
        }
      }

      // Approve subscription with calculated dates
      // Use 'razorpay_auto' as adminId to indicate auto-approval
      final approvedSubscription = subscription
          .approveWithDates(
            adminId: 'razorpay_auto',
            startDate: startDate,
            endDate: endDate,
          )
          .copyWith(transactionId: params.razorpayPaymentId);

      // Mark trial as used
      if (trial != null && !trial.isUsed) {
        await subscriptionRepository.updateTrial(trial.markUsed());
      }

      final updateResult = await subscriptionRepository.updateSubscription(
        approvedSubscription,
      );

      // Convert any pending referral redemption for this owner
      if (referralRepository != null) {
        await _convertReferralRedemption(
          subscription.ownerId,
          approvedSubscription.id,
        );
      }

      return updateResult;
    });
  }

  Future<void> _convertReferralRedemption(
    String refereeId,
    String subscriptionId,
  ) async {
    final redemptionResult = await referralRepository!.getRedemptionByReferee(
      refereeId,
    );

    final redemption = redemptionResult.fold((_) => null, (r) => r);
    if (redemption == null || !redemption.isPending) return;

    final converted = redemption.markConverted(subscriptionId: subscriptionId);
    await referralRepository!.updateRedemption(converted);

    final referralResult = await referralRepository!.getReferralByCode(
      redemption.referralCode,
    );
    final referral = referralResult.fold((_) => null, (r) => r);
    if (referral != null) {
      await referralRepository!.updateReferral(referral.incrementConversion());
    }
  }
}

/// Parameters for AutoApproveRazorpaySubscription use case.
class AutoApproveRazorpaySubscriptionParams extends Equatable {
  const AutoApproveRazorpaySubscriptionParams({
    required this.subscriptionId,
    required this.razorpayPaymentId,
  });

  final String subscriptionId;
  final String razorpayPaymentId;

  @override
  List<Object?> get props => [subscriptionId, razorpayPaymentId];
}
