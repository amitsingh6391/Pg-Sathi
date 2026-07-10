import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../core/core.dart';
import '../entities/subscription.dart';
import '../failures/subscription_failures.dart';
import '../repositories/subscription_repository.dart';

/// Use case for marking a subscription payment as done.
/// Moves subscription to pendingVerification status.
class MarkSubscriptionPaid
    implements UseCase<Subscription, MarkSubscriptionPaidParams> {
  const MarkSubscriptionPaid({required this.subscriptionRepository});

  final SubscriptionRepository subscriptionRepository;

  @override
  Future<Either<Failure, Subscription>> call(
    MarkSubscriptionPaidParams params,
  ) async {
    // Get subscription
    final subscriptionResult = await subscriptionRepository.getSubscriptionById(
      params.subscriptionId,
    );

    return subscriptionResult.fold((failure) => Left(failure), (
      subscription,
    ) async {
      // Validate subscription is in pending status
      if (subscription.status != SubscriptionStatus.pending) {
        return const Left(
          SubscriptionFailure(
            message: 'Subscription is not in pending payment status',
          ),
        );
      }

      // Validate transaction ID
      if (params.transactionId.trim().isEmpty) {
        return const Left(
          SubscriptionFailure(message: 'Transaction ID is required'),
        );
      }

      // Mark as paid
      final updatedSubscription = subscription.markPaymentDone(
        txnId: params.transactionId.trim(),
        proofUrl: params.paymentProofUrl,
      );

      return subscriptionRepository.updateSubscription(updatedSubscription);
    });
  }
}

/// Parameters for MarkSubscriptionPaid use case.
class MarkSubscriptionPaidParams extends Equatable {
  const MarkSubscriptionPaidParams({
    required this.subscriptionId,
    required this.transactionId,
    this.paymentProofUrl,
  });

  final String subscriptionId;
  final String transactionId;
  final String? paymentProofUrl;

  @override
  List<Object?> get props => [subscriptionId, transactionId, paymentProofUrl];
}
