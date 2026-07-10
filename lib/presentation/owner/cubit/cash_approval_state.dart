import 'package:equatable/equatable.dart';

import '../../../domain/usecases/get_pending_cash_payments.dart';

/// Status for cash approval operations.
enum CashApprovalStatus {
  initial,
  loading,
  loaded,
  processing,
  approved,
  rejected,
  error,
}

/// State for CashApprovalCubit.
class CashApprovalState extends Equatable {
  const CashApprovalState({
    this.status = CashApprovalStatus.initial,
    this.pendingPayments = const [],
    this.processingPaymentId,
    this.errorMessage,
  });

  final CashApprovalStatus status;
  final List<PendingCashPaymentInfo> pendingPayments;
  final String? processingPaymentId;
  final String? errorMessage;

  bool get isLoading => status == CashApprovalStatus.loading;
  bool get isLoaded => status == CashApprovalStatus.loaded;
  bool get isProcessing => status == CashApprovalStatus.processing;
  bool get isApproved => status == CashApprovalStatus.approved;
  bool get isRejected => status == CashApprovalStatus.rejected;
  bool get isError => status == CashApprovalStatus.error;
  bool get hasPendingPayments => pendingPayments.isNotEmpty;
  int get pendingCount => pendingPayments.length;

  bool isProcessingPayment(String paymentId) =>
      isProcessing && processingPaymentId == paymentId;

  CashApprovalState copyWith({
    CashApprovalStatus? status,
    List<PendingCashPaymentInfo>? pendingPayments,
    String? processingPaymentId,
    String? errorMessage,
  }) {
    return CashApprovalState(
      status: status ?? this.status,
      pendingPayments: pendingPayments ?? this.pendingPayments,
      processingPaymentId: processingPaymentId,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    pendingPayments,
    processingPaymentId,
    errorMessage,
  ];
}
