import 'package:dartz/dartz.dart';

import '../core/failure.dart';
import '../entities/coupon.dart';
import '../entities/owner_trial.dart';
import '../entities/subscription.dart';

/// Repository interface for Subscription aggregate.
abstract class SubscriptionRepository {
  /// Creates a new subscription record.
  Future<Either<Failure, Subscription>> createSubscription(
    Subscription subscription,
  );

  /// Updates an existing subscription.
  Future<Either<Failure, Subscription>> updateSubscription(
    Subscription subscription,
  );

  /// Gets the current active subscription for an owner.
  Future<Either<Failure, Subscription?>> getActiveSubscription(String ownerId);

  /// Gets subscription by ID.
  Future<Either<Failure, Subscription>> getSubscriptionById(String id);

  /// Gets all subscriptions for an owner (history).
  Future<Either<Failure, List<Subscription>>> getSubscriptionHistory(
    String ownerId,
  );

  /// Gets all subscriptions pending verification (for admin).
  Future<Either<Failure, List<Subscription>>>
  getPendingVerificationSubscriptions();

  /// Gets the latest pending subscription for an owner.
  Future<Either<Failure, Subscription?>> getLatestPendingSubscription(
    String ownerId,
  );

  /// Gets all subscriptions (for admin revenue view).
  Future<Either<Failure, List<Subscription>>> getAllSubscriptions();

  /// Deletes a subscription (admin only).
  Future<Either<Failure, void>> deleteSubscription(String subscriptionId);

  /// Creates or gets owner trial.
  Future<Either<Failure, OwnerTrial>> getOrCreateTrial(String ownerId);

  /// Gets owner trial.
  Future<Either<Failure, OwnerTrial?>> getTrial(String ownerId);

  /// Updates owner trial.
  Future<Either<Failure, OwnerTrial>> updateTrial(OwnerTrial trial);

  // =========================================================================
  // Coupon Methods
  // =========================================================================

  /// Gets a coupon by code.
  Future<Either<Failure, Coupon?>> getCouponByCode(String code);

  /// Creates a new coupon (admin only).
  Future<Either<Failure, Coupon>> createCoupon(Coupon coupon);

  /// Updates a coupon (admin only).
  Future<Either<Failure, Coupon>> updateCoupon(Coupon coupon);

  /// Gets all coupons (admin only).
  Future<Either<Failure, List<Coupon>>> getAllCoupons();
}
