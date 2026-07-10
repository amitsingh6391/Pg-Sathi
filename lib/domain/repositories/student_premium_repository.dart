import 'package:dartz/dartz.dart';

import '../core/failure.dart';
import '../entities/student_premium_subscription.dart';

/// Repository for managing the student premium (ad-free + priority push)
/// subscription lifecycle.
abstract class StudentPremiumRepository {
  /// Returns the most recent subscription for [userId], or null if the user
  /// has never subscribed. Callers use [StudentPremiumSubscription.isCurrentlyActive]
  /// to gate features.
  Future<Either<Failure, StudentPremiumSubscription?>> getActiveSubscription(
    String userId,
  );

  /// Creates or extends a subscription after payment verification.
  /// Idempotent on [paymentId]: calling twice with the same payment id
  /// returns the existing subscription rather than double-charging.
  Future<Either<Failure, StudentPremiumSubscription>> activateSubscription({
    required String userId,
    required StudentPremiumPlan plan,
    required int amountPaise,
    required String paymentId,
    required String paymentProvider,
  });

  /// Marks the subscription as cancelled immediately. The validity window
  /// is preserved so the student retains access until [validTill]; only
  /// auto-renewal (if ever added) is stopped.
  Future<Either<Failure, void>> cancelSubscription(String subscriptionId);

  /// Admin-facing list of all subscriptions, for revenue analytics.
  Future<Either<Failure, List<StudentPremiumSubscription>>>
      getAllSubscriptions();
}
