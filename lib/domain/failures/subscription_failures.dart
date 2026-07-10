import '../core/failure.dart';

/// Base failure for subscription-related errors.
class SubscriptionFailure extends Failure {
  const SubscriptionFailure({super.message});
}

/// Failure when seat count is invalid.
class InvalidSeatCountFailure extends SubscriptionFailure {
  const InvalidSeatCountFailure()
    : super(message: 'Seat count must be greater than 0');
}

/// Failure when duration is invalid.
class InvalidDurationFailure extends SubscriptionFailure {
  const InvalidDurationFailure()
    : super(message: 'Invalid subscription duration');
}

/// Failure when subscription not found.
class SubscriptionNotFoundFailure extends SubscriptionFailure {
  const SubscriptionNotFoundFailure()
    : super(message: 'Subscription not found');
}

/// Failure when trial has already been used.
class TrialAlreadyUsedFailure extends SubscriptionFailure {
  const TrialAlreadyUsedFailure()
    : super(message: 'Trial period has already been used');
}

/// Failure when coupon is invalid.
class InvalidCouponFailure extends SubscriptionFailure {
  const InvalidCouponFailure({String? message})
    : super(message: message ?? 'Invalid coupon code');
}

/// Failure when subscription has expired.
class SubscriptionExpiredFailure extends SubscriptionFailure {
  const SubscriptionExpiredFailure()
    : super(
        message: 'Your subscription has expired. Please renew to continue.',
      );
}

/// Failure when trial has expired.
class TrialExpiredFailure extends SubscriptionFailure {
  const TrialExpiredFailure()
    : super(
        message: 'Your trial period has expired. Please subscribe to continue.',
      );
}

/// Failure when seat limit is exceeded.
class SeatLimitExceededFailure extends SubscriptionFailure {
  const SeatLimitExceededFailure({required this.maxSeats})
    : super(
        message:
            'You have reached your plan limit of $maxSeats seats. Upgrade your plan for more seats.',
      );

  final int maxSeats;
}
