import 'package:dartz/dartz.dart';

import '../core/failure.dart';
import '../entities/referral.dart';

abstract class ReferralRepository {
  Future<Either<Failure, Referral>> createReferral(Referral referral);

  Future<Either<Failure, Referral?>> getReferralByOwnerId(String ownerId);

  Future<Either<Failure, Referral?>> getReferralByCode(String code);

  Future<Either<Failure, Referral>> updateReferral(Referral referral);

  Future<Either<Failure, ReferralRedemption>> createRedemption(
    ReferralRedemption redemption,
  );

  Future<Either<Failure, ReferralRedemption>> updateRedemption(
    ReferralRedemption redemption,
  );

  Future<Either<Failure, List<ReferralRedemption>>> getRedemptionsByReferrer(
    String referrerId,
  );

  Future<Either<Failure, ReferralRedemption?>> getRedemptionByReferee(
    String refereeId,
  );

  Future<Either<Failure, List<ReferralRedemption>>> getUnclaimedRewards(
    String referrerId,
  );

  // Wallet
  Future<Either<Failure, ReferralWallet>> getOrCreateWallet(String ownerId);

  Future<Either<Failure, ReferralWallet>> updateWallet(ReferralWallet wallet);

  // Withdrawal
  Future<Either<Failure, WithdrawalRequest>> createWithdrawalRequest(
    WithdrawalRequest request,
  );

  Future<Either<Failure, List<WithdrawalRequest>>> getWithdrawalRequests(
    String ownerId,
  );

  /// Admin: fetch all pending withdrawal requests across all owners.
  Future<Either<Failure, List<WithdrawalRequest>>>
      getAllPendingWithdrawals();

  /// Admin: update a withdrawal request (approve/reject).
  Future<Either<Failure, WithdrawalRequest>> updateWithdrawalRequest(
    WithdrawalRequest request,
  );
}
