import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../core/core.dart';
import '../entities/owner_trial.dart';
import '../entities/subscription.dart';
import '../repositories/subscription_repository.dart';

/// Combined subscription status result.
class OwnerSubscriptionStatus extends Equatable {
  const OwnerSubscriptionStatus({
    this.subscription,
    this.trial,
    required this.accessStatus,
    this.hasPreviousSubscription = false,
    this.pendingUpgrade,
  });

  /// Current active subscription (if any).
  final Subscription? subscription;

  /// Trial information (if any).
  final OwnerTrial? trial;

  /// Overall access status for the owner.
  final OwnerAccessStatus accessStatus;

  /// Whether owner has any previous subscription (for upgrade/renewal detection).
  final bool hasPreviousSubscription;

  /// Pending upgrade/renewal subscription waiting for verification.
  /// This is set when owner has active subscription but also has a pending upgrade.
  final Subscription? pendingUpgrade;

  /// Whether owner has full access.
  /// Includes pendingVerification since user already paid - don't lock them out.
  bool get hasAccess =>
      accessStatus == OwnerAccessStatus.subscriptionActive ||
      accessStatus == OwnerAccessStatus.trialActive ||
      accessStatus == OwnerAccessStatus.freeTier ||
      accessStatus == OwnerAccessStatus.newOwner ||
      accessStatus == OwnerAccessStatus.pendingVerification;

  /// Paid subscription is active (excludes trial-only access).
  /// Use for features that only apply once the owner is a paying customer (e.g. referrals).
  bool get hasActivePaidPlan =>
      accessStatus == OwnerAccessStatus.subscriptionActive;

  /// Whether this is an upgrade or renewal (has previous subscription history).
  bool get isUpgradeOrRenewal => hasPreviousSubscription;

  /// Whether there's a pending upgrade waiting for verification.
  bool get hasPendingUpgrade => pendingUpgrade != null;

  /// Days remaining for access.
  int get daysRemaining {
    final now = DateTime.now();
    if (subscription != null && subscription!.isActive(now)) {
      return subscription!.daysRemaining(now);
    }
    if (trial != null && trial!.isActive(now)) {
      return trial!.daysRemaining(now);
    }
    return 0;
  }

  @override
  List<Object?> get props => [
    subscription,
    trial,
    accessStatus,
    hasPreviousSubscription,
    pendingUpgrade,
  ];
}

/// Access status for an owner.
enum OwnerAccessStatus {
  /// Has active paid subscription
  subscriptionActive,

  /// Using free tier (up to 7 seats)
  freeTier,

  /// Has active trial (legacy - kept for backward compatibility)
  trialActive,

  /// Trial has expired (legacy - now maps to freeTier)
  trialExpired,

  /// Subscription has expired, needs renewal
  subscriptionExpired,

  /// New owner, using free tier
  newOwner,

  /// Payment made, waiting for admin verification
  pendingVerification,
}

/// Use case for getting owner's current subscription status.
/// Trial is automatically calculated from account creation date.
class GetOwnerSubscription
    implements UseCase<OwnerSubscriptionStatus, GetOwnerSubscriptionParams> {
  const GetOwnerSubscription({required this.subscriptionRepository});

  final SubscriptionRepository subscriptionRepository;

  @override
  Future<Either<Failure, OwnerSubscriptionStatus>> call(
    GetOwnerSubscriptionParams params,
  ) async {
    final now = DateTime.now();

    // Get active subscription
    final subscriptionResult = await subscriptionRepository
        .getActiveSubscription(params.ownerId);

    return subscriptionResult.fold(Left.new, (subscription) async {
      // Check for pending verification subscriptions
      final pendingResult = await subscriptionRepository
          .getLatestPendingSubscription(params.ownerId);

      final pendingSubscription = pendingResult.fold((_) => null, (sub) => sub);

      // Check for admin bypass first - grants full access regardless of status
      if (subscription != null && subscription.isAdminBypassed) {
        return Right(
          OwnerSubscriptionStatus(
            subscription: subscription,
            accessStatus: OwnerAccessStatus.subscriptionActive,
            pendingUpgrade: pendingSubscription, // Include pending upgrade info
          ),
        );
      }

      // If has active subscription
      if (subscription != null && subscription.isActive(now)) {
        return Right(
          OwnerSubscriptionStatus(
            subscription: subscription,
            accessStatus: OwnerAccessStatus.subscriptionActive,
            pendingUpgrade: pendingSubscription,
            hasPreviousSubscription: true,
          ),
        );
      }

      // No active subscription - check if there's a pending verification
      if (pendingSubscription != null) {
        // Check if owner has previous subscriptions (for upgrade/renewal detection)
        final historyResult = await subscriptionRepository
            .getSubscriptionHistory(params.ownerId);
        final previousSubscriptions = historyResult.fold(
          (_) => <Subscription>[],
          (subs) => subs
              .where(
                (s) =>
                    s.id != pendingSubscription.id &&
                    (s.status == SubscriptionStatus.active ||
                        s.status == SubscriptionStatus.expired ||
                        s.status == SubscriptionStatus.cancelled),
              )
              .toList(),
        );

        return Right(
          OwnerSubscriptionStatus(
            subscription: pendingSubscription,
            accessStatus: OwnerAccessStatus.pendingVerification,
            hasPreviousSubscription: previousSubscriptions.isNotEmpty,
          ),
        );
      }

      // If subscription exists but expired - use free tier
      if (subscription != null) {
        return Right(
          OwnerSubscriptionStatus(
            subscription: subscription,
            accessStatus: OwnerAccessStatus.freeTier,
          ),
        );
      }

      // No subscription - owner is on free tier (can use up to 7 seats)
      return const Right(
        OwnerSubscriptionStatus(accessStatus: OwnerAccessStatus.freeTier),
      );
    });
  }
}

/// Parameters for GetOwnerSubscription use case.
class GetOwnerSubscriptionParams extends Equatable {
  const GetOwnerSubscriptionParams({
    required this.ownerId,
    this.libraryCreatedAt,
  });

  final String ownerId;

  /// Library creation date for automatic trial calculation.
  /// Trial starts from when the library was first created.
  final DateTime? libraryCreatedAt;

  @override
  List<Object?> get props => [ownerId, libraryCreatedAt];
}
