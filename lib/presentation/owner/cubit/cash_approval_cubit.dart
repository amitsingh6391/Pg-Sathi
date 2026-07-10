import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/usecases/approve_cash_payment.dart';
import '../../../domain/usecases/get_pending_approval_payments.dart';
import '../../../domain/usecases/get_pending_cash_payments.dart';
import '../../../domain/usecases/reject_cash_payment.dart';
import 'cash_approval_state.dart';

/// Cubit for managing owner payment approvals (cash + UPI).
class CashApprovalCubit extends Cubit<CashApprovalState> {
  CashApprovalCubit({
    required this.getPendingCashPayments,
    required this.getPendingApprovalPayments,
    required this.approveCashPayment,
    required this.rejectCashPayment,
  }) : super(const CashApprovalState());

  final GetPendingCashPayments getPendingCashPayments;
  final GetPendingApprovalPayments getPendingApprovalPayments;
  final ApproveCashPayment approveCashPayment;
  final RejectCashPayment rejectCashPayment;

  /// Load all pending approval payments (cash + UPI) for a library.
  Future<void> loadPendingPayments(String libraryId) async {
    emit(state.copyWith(status: CashApprovalStatus.loading));

    final result = await getPendingApprovalPayments(
      GetPendingApprovalPaymentsParams(libraryId: libraryId),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: CashApprovalStatus.error,
          errorMessage: failure.message ?? 'Failed to load pending payments',
        ),
      ),
      (payments) => emit(
        state.copyWith(
          status: CashApprovalStatus.loaded,
          pendingPayments: payments,
        ),
      ),
    );
  }

  /// Approve a cash payment.
  Future<void> approve({
    required String paymentId,
    required String ownerId,
    required String libraryId,
  }) async {
    emit(
      state.copyWith(
        status: CashApprovalStatus.processing,
        processingPaymentId: paymentId,
      ),
    );

    final result = await approveCashPayment(
      ApproveCashPaymentParams(paymentId: paymentId, ownerId: ownerId),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: CashApprovalStatus.error,
          errorMessage: failure.message ?? 'Failed to approve payment',
          processingPaymentId: null,
        ),
      ),
      (result) {
        emit(
          state.copyWith(
            status: CashApprovalStatus.approved,
            processingPaymentId: null,
          ),
        );
        // Reload list after approval
        loadPendingPayments(libraryId);
      },
    );
  }

  /// Reject a cash payment.
  Future<void> reject({
    required String paymentId,
    required String ownerId,
    required String libraryId,
    String? reason,
  }) async {
    emit(
      state.copyWith(
        status: CashApprovalStatus.processing,
        processingPaymentId: paymentId,
      ),
    );

    final result = await rejectCashPayment(
      RejectCashPaymentParams(
        paymentId: paymentId,
        ownerId: ownerId,
        reason: reason,
      ),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: CashApprovalStatus.error,
          errorMessage: failure.message ?? 'Failed to reject payment',
          processingPaymentId: null,
        ),
      ),
      (result) {
        emit(
          state.copyWith(
            status: CashApprovalStatus.rejected,
            processingPaymentId: null,
          ),
        );
        // Reload list after rejection
        loadPendingPayments(libraryId);
      },
    );
  }

  /// Reset to loaded state after showing success message.
  void resetToLoaded() {
    emit(state.copyWith(status: CashApprovalStatus.loaded));
  }
}
