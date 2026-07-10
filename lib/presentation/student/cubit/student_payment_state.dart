import 'package:equatable/equatable.dart';

import '../../../domain/core/failure.dart';
import '../../../domain/entities/membership.dart';
import '../../../domain/entities/payment.dart'
    show Payment, PaymentMode, PaymentStatus;

/// Payment flow status for student.
enum StudentPaymentStatus {
  initial,
  initiating,
  success,
  failed,
  cashPending, // Cash payment initiated, waiting for owner approval
  upiAwaitingPayment, // UPI payment created, waiting for student to pay
  upiPending, // UPI payment marked as paid, waiting for owner approval
}

/// State for StudentPaymentCubit.
class StudentPaymentState extends Equatable {
  const StudentPaymentState({
    this.status = StudentPaymentStatus.initial,
    this.payment,
    this.activatedMembership,
    this.failure,
    this.existingCashPayment,
  });

  final StudentPaymentStatus status;
  final Payment? payment;
  final Membership? activatedMembership;
  final Failure? failure;

  /// If there's an existing pending cash payment for this membership.
  final Payment? existingCashPayment;

  bool get isLoading => status == StudentPaymentStatus.initiating;

  /// Check if there's an existing pending cash payment.
  /// Cash payments use 'initiated' status with mode 'cash'.
  bool get hasPendingCashPayment =>
      existingCashPayment != null &&
      existingCashPayment!.mode == PaymentMode.cash &&
      existingCashPayment!.status == PaymentStatus.initiated;

  bool get isSuccess => status == StudentPaymentStatus.success;

  bool get isFailed => status == StudentPaymentStatus.failed;

  bool get isCashPending => status == StudentPaymentStatus.cashPending;

  bool get isUpiAwaitingPayment =>
      status == StudentPaymentStatus.upiAwaitingPayment;

  bool get isUpiPending => status == StudentPaymentStatus.upiPending;

  /// Check if there's an existing pending UPI payment.
  bool get hasPendingUpiPayment =>
      existingCashPayment != null &&
      existingCashPayment!.mode == PaymentMode.upi &&
      existingCashPayment!.status == PaymentStatus.initiated;

  StudentPaymentState copyWith({
    StudentPaymentStatus? status,
    Payment? payment,
    Membership? activatedMembership,
    Failure? failure,
    Payment? existingCashPayment,
    bool clearFailure = false,
    bool clearExistingCashPayment = false,
  }) {
    return StudentPaymentState(
      status: status ?? this.status,
      payment: payment ?? this.payment,
      activatedMembership: activatedMembership ?? this.activatedMembership,
      failure: clearFailure ? null : (failure ?? this.failure),
      existingCashPayment: clearExistingCashPayment
          ? null
          : (existingCashPayment ?? this.existingCashPayment),
    );
  }

  @override
  List<Object?> get props => [
    status,
    payment,
    activatedMembership,
    failure,
    existingCashPayment,
  ];
}
