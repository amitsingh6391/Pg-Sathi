import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/services/subscription_notification_service.dart';
import '../../../domain/core/usecase.dart';
import '../../../domain/entities/referral.dart';
import '../../../domain/usecases/referral/referral_usecases.dart';

enum WithdrawalApprovalStatus { initial, loading, loaded, error }

class WithdrawalApprovalState extends Equatable {
  const WithdrawalApprovalState({
    this.status = WithdrawalApprovalStatus.initial,
    this.pendingRequests = const [],
    this.errorMessage,
    this.successMessage,
  });

  final WithdrawalApprovalStatus status;
  final List<WithdrawalRequest> pendingRequests;
  final String? errorMessage;
  final String? successMessage;

  bool get isLoading => status == WithdrawalApprovalStatus.loading;

  WithdrawalApprovalState copyWith({
    WithdrawalApprovalStatus? status,
    List<WithdrawalRequest>? pendingRequests,
    String? errorMessage,
    String? successMessage,
    bool clearMessages = false,
  }) {
    return WithdrawalApprovalState(
      status: status ?? this.status,
      pendingRequests: pendingRequests ?? this.pendingRequests,
      errorMessage: clearMessages ? null : errorMessage,
      successMessage: clearMessages ? null : successMessage,
    );
  }

  @override
  List<Object?> get props =>
      [status, pendingRequests, errorMessage, successMessage];
}

class WithdrawalApprovalCubit extends Cubit<WithdrawalApprovalState> {
  WithdrawalApprovalCubit({
    required this.getPendingWithdrawals,
    required this.approveWithdrawal,
    required this.rejectWithdrawal,
    required this.notificationService,
  }) : super(const WithdrawalApprovalState());

  final GetPendingWithdrawals getPendingWithdrawals;
  final ApproveWithdrawal approveWithdrawal;
  final RejectWithdrawal rejectWithdrawal;
  final SubscriptionNotificationService notificationService;

  Future<void> load() async {
    emit(state.copyWith(
      status: WithdrawalApprovalStatus.loading,
      clearMessages: true,
    ));

    final result = await getPendingWithdrawals(NoParams());

    result.fold(
      (f) => emit(state.copyWith(
        status: WithdrawalApprovalStatus.error,
        errorMessage: f.message ?? 'Failed to load withdrawals',
      )),
      (list) => emit(state.copyWith(
        status: WithdrawalApprovalStatus.loaded,
        pendingRequests: list,
      )),
    );
  }

  Future<void> approve(String withdrawalId) async {
    emit(state.copyWith(clearMessages: true));

    final request = state.pendingRequests
        .where((w) => w.id == withdrawalId)
        .firstOrNull;

    final result = await approveWithdrawal(
      ApproveWithdrawalParams(withdrawalId: withdrawalId),
    );

    result.fold(
      (f) => emit(state.copyWith(
        errorMessage: f.message ?? 'Failed to approve',
      )),
      (_) {
        if (request != null) {
          notificationService.notifyOwnerWithdrawalApproved(
            ownerId: request.ownerId,
            amount: request.amount,
          );
        }
        emit(state.copyWith(successMessage: 'Withdrawal approved'));
        load();
      },
    );
  }

  Future<void> reject(String withdrawalId, String reason) async {
    emit(state.copyWith(clearMessages: true));

    final request = state.pendingRequests
        .where((w) => w.id == withdrawalId)
        .firstOrNull;

    final result = await rejectWithdrawal(
      RejectWithdrawalParams(withdrawalId: withdrawalId, reason: reason),
    );

    result.fold(
      (f) => emit(state.copyWith(
        errorMessage: f.message ?? 'Failed to reject',
      )),
      (_) {
        if (request != null) {
          notificationService.notifyOwnerWithdrawalRejected(
            ownerId: request.ownerId,
            amount: request.amount,
            reason: reason,
          );
        }
        emit(state.copyWith(
          successMessage: 'Withdrawal rejected, balance refunded',
        ));
        load();
      },
    );
  }
}
