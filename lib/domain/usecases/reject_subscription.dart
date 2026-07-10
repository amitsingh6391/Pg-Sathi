import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../core/services/analytics_service.dart';
import '../core/core.dart';
import '../entities/subscription.dart';
import '../failures/subscription_failures.dart';
import '../repositories/subscription_repository.dart';

/// Use case for rejecting a subscription (admin only).
class RejectSubscription
    implements UseCase<Subscription, RejectSubscriptionParams> {
  const RejectSubscription({
    required this.subscriptionRepository,
    required this.analyticsService,
  });

  final SubscriptionRepository subscriptionRepository;
  final AnalyticsService analyticsService;

  @override
  Future<Either<Failure, Subscription>> call(
    RejectSubscriptionParams params,
  ) async {
    // Get subscription
    final subscriptionResult = await subscriptionRepository.getSubscriptionById(
      params.subscriptionId,
    );

    return subscriptionResult.fold((failure) => Left(failure), (
      subscription,
    ) async {
      // Validate subscription can be rejected (pending or pendingVerification)
      // Admin should be able to reject subscriptions that haven't been approved yet
      if (subscription.status != SubscriptionStatus.pending &&
          subscription.status != SubscriptionStatus.pendingVerification) {
        return Left(
          SubscriptionFailure(
            message:
                'Subscription cannot be rejected. Current status: ${subscription.status.displayName}',
          ),
        );
      }

      // Reject subscription
      final rejectedSubscription = subscription.reject(
        adminId: params.adminId,
        reason: params.reason,
      );

      final updateResult = await subscriptionRepository.updateSubscription(rejectedSubscription);
      
      // Track subscription cancelled
      if (updateResult.isRight()) {
        await analyticsService.trackSubscriptionCancelled(
          subscriptionPlan: '${rejectedSubscription.seatCount} seats',
          cancellationReason: params.reason,
        );
      }
      
      return updateResult;
    });
  }
}

/// Parameters for RejectSubscription use case.
class RejectSubscriptionParams extends Equatable {
  const RejectSubscriptionParams({
    required this.subscriptionId,
    required this.adminId,
    required this.reason,
  });

  final String subscriptionId;
  final String adminId;
  final String reason;

  @override
  List<Object?> get props => [subscriptionId, adminId, reason];
}
