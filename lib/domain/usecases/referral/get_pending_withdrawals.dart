import 'package:dartz/dartz.dart';

import '../../core/core.dart';
import '../../entities/referral.dart';
import '../../repositories/referral_repository.dart';

/// Admin: fetches all pending withdrawal requests.
class GetPendingWithdrawals
    implements UseCase<List<WithdrawalRequest>, NoParams> {
  const GetPendingWithdrawals({required this.referralRepository});

  final ReferralRepository referralRepository;

  @override
  Future<Either<Failure, List<WithdrawalRequest>>> call(
    NoParams params,
  ) async {
    return referralRepository.getAllPendingWithdrawals();
  }
}
