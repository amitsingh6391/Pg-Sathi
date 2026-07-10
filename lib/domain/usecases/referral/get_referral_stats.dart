import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../core/core.dart';
import '../../entities/referral.dart';
import '../../repositories/referral_repository.dart';

/// Aggregated referral data for the owner's referral screen.
class ReferralStats extends Equatable {
  const ReferralStats({
    this.referral,
    this.wallet,
    this.redemptions = const [],
    this.unclaimedRewards = const [],
    this.withdrawalRequests = const [],
  });

  final Referral? referral;
  final ReferralWallet? wallet;
  final List<ReferralRedemption> redemptions;
  final List<ReferralRedemption> unclaimedRewards;
  final List<WithdrawalRequest> withdrawalRequests;

  /// Uses the Referral entity counters as primary source (always updated
  /// atomically during create/approve). Falls back to redemption list count.
  int get totalReferred =>
      referral?.totalRedemptions ?? redemptions.length;
  int get totalConverted =>
      referral?.successfulConversions ??
      redemptions.where((r) => r.isConverted).length;

  @override
  List<Object?> get props => [
    referral,
    wallet,
    redemptions,
    unclaimedRewards,
    withdrawalRequests,
  ];
}

/// Loads all referral data for an owner in a single call.
class GetReferralStats
    implements UseCase<ReferralStats, GetReferralStatsParams> {
  const GetReferralStats({required this.referralRepository});

  final ReferralRepository referralRepository;

  @override
  Future<Either<Failure, ReferralStats>> call(
    GetReferralStatsParams params,
  ) async {
    final referralResult = await referralRepository.getReferralByOwnerId(
      params.ownerId,
    );

    final referral = referralResult.fold((_) => null, (r) => r);

    if (referral == null) {
      return const Right(ReferralStats());
    }

    final results = await Future.wait([
      referralRepository.getRedemptionsByReferrer(params.ownerId),
      referralRepository.getUnclaimedRewards(params.ownerId),
      referralRepository.getOrCreateWallet(params.ownerId),
      referralRepository.getWithdrawalRequests(params.ownerId),
    ]);

    final redemptions = (results[0] as Either<Failure, List<ReferralRedemption>>)
        .fold((_) => <ReferralRedemption>[], (r) => r);

    final unclaimed = (results[1] as Either<Failure, List<ReferralRedemption>>)
        .fold((_) => <ReferralRedemption>[], (r) => r);

    final wallet = (results[2] as Either<Failure, ReferralWallet>)
        .fold((_) => null, (w) => w);

    final withdrawals = (results[3] as Either<Failure, List<WithdrawalRequest>>)
        .fold((_) => <WithdrawalRequest>[], (w) => w);

    return Right(ReferralStats(
      referral: referral,
      wallet: wallet,
      redemptions: redemptions,
      unclaimedRewards: unclaimed,
      withdrawalRequests: withdrawals,
    ));
  }
}

class GetReferralStatsParams extends Equatable {
  const GetReferralStatsParams({required this.ownerId});

  final String ownerId;

  @override
  List<Object?> get props => [ownerId];
}
