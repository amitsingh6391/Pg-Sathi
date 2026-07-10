import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/services/subscription_notification_service.dart';
import '../../../domain/entities/referral.dart';
import '../../../domain/usecases/referral/referral_usecases.dart';

// =========================================================================
// State
// =========================================================================

enum ReferralScreenStatus {
  initial,
  loading,
  loaded,
  creating,
  claimingReward,
  requestingWithdrawal,
  success,
  error,
}

class ReferralState extends Equatable {
  const ReferralState({
    this.status = ReferralScreenStatus.initial,
    this.stats,
    this.errorMessage,
    this.successMessage,
  });

  final ReferralScreenStatus status;
  final ReferralStats? stats;
  final String? errorMessage;
  final String? successMessage;

  bool get isLoading =>
      status == ReferralScreenStatus.loading ||
      status == ReferralScreenStatus.creating ||
      status == ReferralScreenStatus.claimingReward ||
      status == ReferralScreenStatus.requestingWithdrawal;

  bool get hasReferralCode => stats?.referral != null;

  ReferralState copyWith({
    ReferralScreenStatus? status,
    ReferralStats? stats,
    String? errorMessage,
    String? successMessage,
    bool clearMessages = false,
  }) {
    return ReferralState(
      status: status ?? this.status,
      stats: stats ?? this.stats,
      errorMessage: clearMessages ? null : errorMessage,
      successMessage: clearMessages ? null : successMessage,
    );
  }

  @override
  List<Object?> get props => [status, stats, errorMessage, successMessage];
}

// =========================================================================
// Cubit
// =========================================================================

class ReferralCubit extends Cubit<ReferralState> {
  ReferralCubit({
    required this.createReferralCode,
    required this.getReferralStats,
    required this.claimReferralReward,
    required this.requestWalletWithdrawal,
    required this.notificationService,
  }) : super(const ReferralState());

  final CreateReferralCode createReferralCode;
  final GetReferralStats getReferralStats;
  final ClaimReferralReward claimReferralReward;
  final RequestWalletWithdrawal requestWalletWithdrawal;
  final SubscriptionNotificationService notificationService;

  Future<void> loadStats(String ownerId) async {
    emit(state.copyWith(
      status: ReferralScreenStatus.loading,
      clearMessages: true,
    ));

    final result = await getReferralStats(
      GetReferralStatsParams(ownerId: ownerId),
    );

    result.fold(
      (failure) => emit(state.copyWith(
        status: ReferralScreenStatus.error,
        errorMessage: failure.message ?? 'Failed to load referral data',
      )),
      (stats) => emit(state.copyWith(
        status: ReferralScreenStatus.loaded,
        stats: stats,
      )),
    );
  }

  Future<void> generateCode({
    required String ownerId,
    String? ownerName,
  }) async {
    emit(state.copyWith(
      status: ReferralScreenStatus.creating,
      clearMessages: true,
    ));

    final result = await createReferralCode(
      CreateReferralCodeParams(ownerId: ownerId, ownerName: ownerName),
    );

    result.fold(
      (failure) => emit(state.copyWith(
        status: ReferralScreenStatus.error,
        errorMessage: failure.message ?? 'Failed to create referral code',
      )),
      (_) => loadStats(ownerId),
    );
  }

  Future<void> claimReward({
    required String ownerId,
    required String redemptionId,
    required ReferralRewardType rewardType,
  }) async {
    emit(state.copyWith(
      status: ReferralScreenStatus.claimingReward,
      clearMessages: true,
    ));

    final result = await claimReferralReward(
      ClaimReferralRewardParams(
        ownerId: ownerId,
        redemptionId: redemptionId,
        rewardType: rewardType,
      ),
    );

    result.fold(
      (failure) => emit(state.copyWith(
        status: ReferralScreenStatus.error,
        errorMessage: failure.message ?? 'Failed to claim reward',
      )),
      (_) {
        final label = rewardType == ReferralRewardType.freeMonth
            ? 'Subscription extended by 1 month!'
            : '₹149 added to your wallet!';
        emit(state.copyWith(
          status: ReferralScreenStatus.success,
          successMessage: label,
        ));
        loadStats(ownerId);
      },
    );
  }

  Future<void> requestWithdrawal({
    required String ownerId,
    required double amount,
    String? upiId,
  }) async {
    emit(state.copyWith(
      status: ReferralScreenStatus.requestingWithdrawal,
      clearMessages: true,
    ));

    final result = await requestWalletWithdrawal(
      RequestWalletWithdrawalParams(
        ownerId: ownerId,
        amount: amount,
        upiId: upiId,
      ),
    );

    result.fold(
      (failure) => emit(state.copyWith(
        status: ReferralScreenStatus.error,
        errorMessage: failure.message ?? 'Failed to request withdrawal',
      )),
      (_) {
        notificationService.notifyAdminWithdrawalRequested(
          ownerId: ownerId,
          amount: amount,
          upiId: upiId,
        );
        emit(state.copyWith(
          status: ReferralScreenStatus.success,
          successMessage: 'Withdrawal request submitted',
        ));
        loadStats(ownerId);
      },
    );
  }
}
