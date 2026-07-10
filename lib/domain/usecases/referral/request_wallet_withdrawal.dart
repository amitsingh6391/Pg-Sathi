import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

import '../../core/core.dart';
import '../../entities/referral.dart';
import '../../failures/referral_failures.dart';
import '../../repositories/referral_repository.dart';

/// Submits a withdrawal request for referral wallet balance.
class RequestWalletWithdrawal
    implements UseCase<WithdrawalRequest, RequestWalletWithdrawalParams> {
  const RequestWalletWithdrawal({required this.referralRepository});

  final ReferralRepository referralRepository;

  @override
  Future<Either<Failure, WithdrawalRequest>> call(
    RequestWalletWithdrawalParams params,
  ) async {
    if (params.amount <= 0) {
      return const Left(
        ReferralFailure(message: 'Withdrawal amount must be positive'),
      );
    }

    final walletResult = await referralRepository.getOrCreateWallet(
      params.ownerId,
    );

    return walletResult.fold(Left.new, (wallet) async {
      if (!wallet.canWithdraw(params.amount)) {
        return const Left(InsufficientWalletBalanceFailure());
      }

      final request = WithdrawalRequest(
        id: const Uuid().v4(),
        ownerId: params.ownerId,
        amount: params.amount,
        status: WithdrawalStatus.pending,
        upiId: params.upiId,
        createdAt: DateTime.now(),
      );

      final createResult = await referralRepository.createWithdrawalRequest(
        request,
      );

      return createResult.fold(Left.new, (created) async {
        // Deduct from wallet immediately (hold)
        final updated = wallet.withdraw(params.amount);
        await referralRepository.updateWallet(updated);
        return Right(created);
      });
    });
  }
}

class RequestWalletWithdrawalParams extends Equatable {
  const RequestWalletWithdrawalParams({
    required this.ownerId,
    required this.amount,
    this.upiId,
  });

  final String ownerId;
  final double amount;
  final String? upiId;

  @override
  List<Object?> get props => [ownerId, amount, upiId];
}
