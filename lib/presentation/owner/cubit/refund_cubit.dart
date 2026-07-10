import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/core/failure.dart';
import '../../../domain/entities/invoice.dart';
import '../../../domain/entities/membership.dart';
import '../../../domain/entities/payment.dart';
import '../../../domain/usecases/refund_payment.dart';

/// Status for refund operations.
enum RefundStatus { initial, loading, success, error }

/// State for RefundCubit.
class RefundState extends Equatable {
  const RefundState({
    this.status = RefundStatus.initial,
    this.refundedPayment,
    this.cancelledMembership,
    this.invoice,
    this.errorMessage,
  });

  final RefundStatus status;
  final Payment? refundedPayment;
  final Membership? cancelledMembership;
  final Invoice? invoice;
  final String? errorMessage;

  bool get isLoading => status == RefundStatus.loading;
  bool get isSuccess => status == RefundStatus.success;
  bool get isError => status == RefundStatus.error;

  RefundState copyWith({
    RefundStatus? status,
    Payment? refundedPayment,
    Membership? cancelledMembership,
    Invoice? invoice,
    String? errorMessage,
  }) {
    return RefundState(
      status: status ?? this.status,
      refundedPayment: refundedPayment ?? this.refundedPayment,
      cancelledMembership: cancelledMembership ?? this.cancelledMembership,
      invoice: invoice ?? this.invoice,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    refundedPayment,
    cancelledMembership,
    invoice,
    errorMessage,
  ];
}

/// Cubit for managing refund operations.
class RefundCubit extends Cubit<RefundState> {
  RefundCubit({required this.refundPayment}) : super(const RefundState());

  final RefundPayment refundPayment;

  /// Processes a refund for a payment and cancels the associated membership.
  ///
  /// [paymentId] - ID of the payment to refund
  /// [reason] - Reason for the refund
  /// [refundedBy] - Owner ID who is processing the refund
  Future<void> processRefund({
    required String paymentId,
    required String reason,
    required String refundedBy,
  }) async {
    emit(state.copyWith(status: RefundStatus.loading));

    final result = await refundPayment(
      RefundPaymentParams(
        paymentId: paymentId,
        reason: reason,
        refundedBy: refundedBy,
      ),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: RefundStatus.error,
          errorMessage: _getErrorMessage(failure),
        ),
      ),
      (refundResult) => emit(
        state.copyWith(
          status: RefundStatus.success,
          refundedPayment: refundResult.refundedPayment,
          cancelledMembership: refundResult.cancelledMembership,
          invoice: refundResult.invoice,
        ),
      ),
    );
  }

  /// Resets the refund state to initial.
  void reset() {
    emit(const RefundState());
  }

  /// Maps failure to user-friendly error message.
  String _getErrorMessage(Failure failure) {
    if (failure.message != null) {
      return failure.message!;
    }
    return 'Failed to process refund. Please try again.';
  }
}
