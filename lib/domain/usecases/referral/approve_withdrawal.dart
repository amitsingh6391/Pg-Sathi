import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../core/core.dart';
import '../../entities/referral.dart';
import '../../failures/referral_failures.dart';
import '../../repositories/referral_repository.dart';

/// Admin approves a pending withdrawal request.
/// The wallet balance was already deducted when the request was created.
class ApproveWithdrawal
    implements UseCase<WithdrawalRequest, ApproveWithdrawalParams> {
  const ApproveWithdrawal({required this.referralRepository});

  final ReferralRepository referralRepository;

  @override
  Future<Either<Failure, WithdrawalRequest>> call(
    ApproveWithdrawalParams params,
  ) async {
    final allResult = await referralRepository.getAllPendingWithdrawals();

    return allResult.fold(Left.new, (pending) async {
      final match = pending.where((w) => w.id == params.withdrawalId);
      if (match.isEmpty) {
        return const Left(
          ReferralFailure(message: 'Withdrawal request not found'),
        );
      }

      final approved = match.first.approve();
      return referralRepository.updateWithdrawalRequest(approved);
    });
  }
}

class ApproveWithdrawalParams extends Equatable {
  const ApproveWithdrawalParams({required this.withdrawalId});

  final String withdrawalId;

  @override
  List<Object?> get props => [withdrawalId];
}
