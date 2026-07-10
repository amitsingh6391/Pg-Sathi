import 'package:equatable/equatable.dart';

/// Represents a payment transaction for membership activation.
class Payment extends Equatable {
  const Payment({
    required this.id,
    required this.membershipId,
    required this.userId,
    required this.libraryId,
    required this.amount,
    required this.currency,
    required this.status,
    this.mode = PaymentMode.online,
    this.gatewayOrderId,
    this.gatewayPaymentId,
    this.failureReason,
    this.createdAt,
    this.updatedAt,
    this.expiresAt,
    this.approvedAt,
    this.approvedByOwnerId,
    this.utrNumber,
    this.paymentProofUrl,
    this.studentMarkedPaidAt,
  });

  final String id;
  final String membershipId;
  final String userId;
  final String libraryId;
  final double amount;
  final String currency;
  final PaymentStatus status;
  final PaymentMode mode;
  final String?
  gatewayOrderId; // Payment gateway order ID (for online payments)
  final String? gatewayPaymentId; // Payment gateway payment ID (on success)
  final String? failureReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? expiresAt; // Payment expiry time
  final DateTime? approvedAt; // For cash/UPI payments - when owner approved
  final String? approvedByOwnerId; // For cash/UPI payments - who approved
  final String? utrNumber; // UPI transaction reference number
  final String? paymentProofUrl; // Screenshot/proof URL for UPI payments
  final DateTime? studentMarkedPaidAt; // When student marked as paid (UPI)

  /// Default reservation expiry duration (15 minutes).
  static const reservationExpiryMinutes = 15;

  @override
  List<Object?> get props => [
    id,
    membershipId,
    userId,
    libraryId,
    amount,
    currency,
    status,
    mode,
    gatewayOrderId,
    gatewayPaymentId,
    failureReason,
    createdAt,
    updatedAt,
    expiresAt,
    approvedAt,
    approvedByOwnerId,
    utrNumber,
    paymentProofUrl,
    studentMarkedPaidAt,
  ];

  Payment copyWith({
    String? id,
    String? membershipId,
    String? userId,
    String? libraryId,
    double? amount,
    String? currency,
    PaymentStatus? status,
    PaymentMode? mode,
    String? gatewayOrderId,
    String? gatewayPaymentId,
    String? failureReason,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? expiresAt,
    DateTime? approvedAt,
    String? approvedByOwnerId,
    String? utrNumber,
    String? paymentProofUrl,
    DateTime? studentMarkedPaidAt,
  }) {
    return Payment(
      id: id ?? this.id,
      membershipId: membershipId ?? this.membershipId,
      userId: userId ?? this.userId,
      libraryId: libraryId ?? this.libraryId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      mode: mode ?? this.mode,
      gatewayOrderId: gatewayOrderId ?? this.gatewayOrderId,
      gatewayPaymentId: gatewayPaymentId ?? this.gatewayPaymentId,
      failureReason: failureReason ?? this.failureReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedByOwnerId: approvedByOwnerId ?? this.approvedByOwnerId,
      utrNumber: utrNumber ?? this.utrNumber,
      paymentProofUrl: paymentProofUrl ?? this.paymentProofUrl,
      studentMarkedPaidAt: studentMarkedPaidAt ?? this.studentMarkedPaidAt,
    );
  }

  /// Marks payment as successful.
  Payment markSuccess(String paymentId) {
    return copyWith(
      status: PaymentStatus.success,
      gatewayPaymentId: paymentId,
      updatedAt: DateTime.now(),
    );
  }

  /// Marks payment as failed.
  Payment markFailed(String reason) {
    return copyWith(
      status: PaymentStatus.failed,
      failureReason: reason,
      updatedAt: DateTime.now(),
    );
  }

  /// Marks payment as expired.
  Payment markExpired() {
    return copyWith(status: PaymentStatus.expired, updatedAt: DateTime.now());
  }

  /// Checks if payment has expired.
  bool isExpired(DateTime currentTime) {
    if (expiresAt == null) return false;
    return currentTime.isAfter(expiresAt!);
  }

  /// Checks if payment is pending.
  bool get isPending => status == PaymentStatus.initiated;

  /// Checks if this is a cash payment.
  bool get isCashPayment => mode == PaymentMode.cash;

  /// Checks if this is an online payment.
  bool get isOnlinePayment => mode == PaymentMode.online;

  /// Checks if cash payment is pending approval.
  bool get isPendingCashApproval =>
      isCashPayment && status == PaymentStatus.initiated;

  /// Checks if cash payment was approved.
  bool get isCashApproved =>
      isCashPayment && status == PaymentStatus.success && approvedAt != null;

  /// Checks if cash payment was rejected.
  bool get isCashRejected => isCashPayment && status == PaymentStatus.failed;

  /// Checks if this is a UPI payment.
  bool get isUpiPayment => mode == PaymentMode.upi;

  /// Checks if UPI payment is awaiting student to mark as paid.
  bool get isAwaitingUpiPayment =>
      isUpiPayment &&
      status == PaymentStatus.initiated &&
      studentMarkedPaidAt == null;

  /// Checks if UPI payment is pending approval (student marked paid, awaiting owner).
  bool get isPendingUpiApproval =>
      isUpiPayment &&
      status == PaymentStatus.initiated &&
      studentMarkedPaidAt != null;

  /// Checks if UPI payment was approved.
  bool get isUpiApproved =>
      isUpiPayment && status == PaymentStatus.success && approvedAt != null;

  /// Checks if UPI payment was rejected.
  bool get isUpiRejected => isUpiPayment && status == PaymentStatus.failed;

  /// Checks if payment requires manual approval (cash or UPI).
  bool get requiresApproval => mode.requiresApproval;

  /// Checks if payment is pending any form of approval.
  bool get isPendingApproval =>
      (isPendingCashApproval || isPendingUpiApproval) &&
      status == PaymentStatus.initiated;

  /// Marks cash payment as approved by owner.
  Payment approveCashPayment(String ownerId, {DateTime? approvalDate}) {
    final now = approvalDate ?? DateTime.now();
    return copyWith(
      status: PaymentStatus.success,
      approvedAt: now,
      approvedByOwnerId: ownerId,
      updatedAt: now,
    );
  }

  /// Marks UPI payment as paid by student (awaiting owner approval).
  Payment markUpiAsPaid({String? utr, String? proofUrl}) {
    return copyWith(
      utrNumber: utr,
      paymentProofUrl: proofUrl,
      studentMarkedPaidAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Approves UPI payment by owner.
  Payment approveUpiPayment(String ownerId, {DateTime? approvalDate}) {
    final now = approvalDate ?? DateTime.now();
    return copyWith(
      status: PaymentStatus.success,
      approvedAt: now,
      approvedByOwnerId: ownerId,
      updatedAt: now,
    );
  }

  /// Marks payment as refunded.
  /// Used when a seat/membership is cancelled after payment was made.
  /// This removes the payment from revenue calculations.
  Payment markAsRefunded({required String reason, required String refundedBy}) {
    return copyWith(
      status: PaymentStatus.refunded,
      failureReason: reason,
      approvedByOwnerId: refundedBy,
      updatedAt: DateTime.now(),
    );
  }

  /// Checks if payment was refunded.
  bool get isRefunded => status == PaymentStatus.refunded;

  /// Checks if payment contributes to revenue.
  /// Only successful (not refunded) payments count toward revenue.
  bool get countsAsRevenue => status == PaymentStatus.success;

  /// Creates a cash payment record.
  static Payment createCashPayment({
    required String id,
    required String membershipId,
    required String userId,
    required String libraryId,
    required double amount,
    String currency = 'INR',
    DateTime? createdAt,
  }) {
    final now = createdAt ?? DateTime.now();
    return Payment(
      id: id,
      membershipId: membershipId,
      userId: userId,
      libraryId: libraryId,
      amount: amount,
      currency: currency,
      status: PaymentStatus.initiated,
      mode: PaymentMode.cash,
      createdAt: now,
      updatedAt: now,
      // Cash payments don't expire like online payments
      expiresAt: null,
    );
  }

  /// Creates a UPI payment record.
  static Payment createUpiPayment({
    required String id,
    required String membershipId,
    required String userId,
    required String libraryId,
    required double amount,
    String currency = 'INR',
    DateTime? createdAt,
  }) {
    final now = createdAt ?? DateTime.now();
    return Payment(
      id: id,
      membershipId: membershipId,
      userId: userId,
      libraryId: libraryId,
      amount: amount,
      currency: currency,
      status: PaymentStatus.initiated,
      mode: PaymentMode.upi,
      createdAt: now,
      updatedAt: now,
      // UPI payments don't expire - seat stays reserved until approval/rejection
      expiresAt: null,
    );
  }
}

/// Payment mode.
enum PaymentMode { online, cash, upi }

/// Extension for PaymentMode display names.
extension PaymentModeExtension on PaymentMode {
  String get displayName {
    switch (this) {
      case PaymentMode.online:
        return 'Online';
      case PaymentMode.cash:
        return 'Cash';
      case PaymentMode.upi:
        return 'UPI';
    }
  }

  String get description {
    switch (this) {
      case PaymentMode.online:
        return 'Online payment';
      case PaymentMode.cash:
        return 'Pay cash at the library';
      case PaymentMode.upi:
        return 'Pay directly to owner UPI';
    }
  }

  /// Whether this payment mode requires manual approval.
  bool get requiresApproval {
    switch (this) {
      case PaymentMode.online:
        return false;
      case PaymentMode.cash:
      case PaymentMode.upi:
        return true;
    }
  }
}

/// Payment status.
enum PaymentStatus { initiated, success, failed, expired, refunded }

/// Extension for display names.
extension PaymentStatusExtension on PaymentStatus {
  String get displayName {
    switch (this) {
      case PaymentStatus.initiated:
        return 'Pending';
      case PaymentStatus.success:
        return 'Successful';
      case PaymentStatus.failed:
        return 'Failed';
      case PaymentStatus.expired:
        return 'Expired';
      case PaymentStatus.refunded:
        return 'Refunded';
    }
  }

  String get cashPaymentDisplayName {
    switch (this) {
      case PaymentStatus.initiated:
        return 'Pending Approval';
      case PaymentStatus.success:
        return 'Approved';
      case PaymentStatus.failed:
        return 'Rejected';
      case PaymentStatus.expired:
        return 'Expired';
      case PaymentStatus.refunded:
        return 'Refunded';
    }
  }
}
