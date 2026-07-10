import '../core/failure.dart';

class ReferralFailure extends Failure {
  const ReferralFailure({super.message});
}

class NoActiveSubscriptionForReferralFailure extends ReferralFailure {
  const NoActiveSubscriptionForReferralFailure()
    : super(
        message:
            'You need an active subscription to create a referral code',
      );
}

class ReferralCodeAlreadyExistsFailure extends ReferralFailure {
  const ReferralCodeAlreadyExistsFailure()
    : super(message: 'You already have a referral code');
}

class InvalidReferralCodeFailure extends ReferralFailure {
  const InvalidReferralCodeFailure()
    : super(message: 'Invalid referral code');
}

class SelfReferralNotAllowedFailure extends ReferralFailure {
  const SelfReferralNotAllowedFailure()
    : super(message: 'You cannot use your own referral code');
}

class ReferralCodeNotFoundFailure extends ReferralFailure {
  const ReferralCodeNotFoundFailure()
    : super(message: 'Referral code not found');
}

class ReferralAlreadyAppliedFailure extends ReferralFailure {
  const ReferralAlreadyAppliedFailure()
    : super(message: 'You have already used a referral code');
}

class InsufficientWalletBalanceFailure extends ReferralFailure {
  const InsufficientWalletBalanceFailure()
    : super(message: 'Insufficient wallet balance');
}

class NoUnclaimedRewardsFailure extends ReferralFailure {
  const NoUnclaimedRewardsFailure()
    : super(message: 'No unclaimed rewards available');
}

class ReferrerNoActiveSubscriptionFailure extends ReferralFailure {
  const ReferrerNoActiveSubscriptionFailure()
    : super(
        message:
            'This referral code is inactive because the owner does not '
            'have an active subscription',
      );
}
