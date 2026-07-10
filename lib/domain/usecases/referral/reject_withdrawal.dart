import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../core/core.dart';
import '../../entities/referral.dart';
import '../../failures/referral_failures.dart';
import '../../repositories/referral_repository.dart';

/// Admin rejects a withdrawal request and refunds the held balance.
class RejectWithdrawal
    implements UseCase<WithdrawalRequest, RejectWithdrawalParams> {
  const RejectWithdrawal({required this.referralRepository});

  final ReferralRepository referralRepository;

  @override
  Future<Either<Failure, WithdrawalRequest>> call(
    RejectWithdrawalParams params,
  ) async {
    final allResult = await referralRepository.getAllPendingWithdrawals();

    return allResult.fold(Left.new, (pending) async {
      final match = pending.where((w) => w.id == params.withdrawalId);
      if (match.isEmpty) {
        return const Left(
          ReferralFailure(message: 'Withdrawal request not found'),
        );
      }

      final request = match.first;
      final rejected = request.reject(params.reason);

      final updateResult =
          await referralRepository.updateWithdrawalRequest(rejected);

      return updateResult.fold(Left.new, (updated) async {
        // Refund the held amount back to the wallet
        final walletResult =
            await referralRepository.getOrCreateWallet(request.ownerId);

        await walletResult.fold((_) => null, (wallet) async {
          final refunded = wallet.addCredit(request.amount);
          await referralRepository.updateWallet(refunded);
        });

        return Right(updated);
      });
    });
  }
}

class RejectWithdrawalParams extends Equatable {
  const RejectWithdrawalParams({
    required this.withdrawalId,
    required this.reason,
  });

  final String withdrawalId;
  final String reason;

  @override
  List<Object?> get props => [withdrawalId, reason];
}
