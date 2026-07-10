import 'package:cloud_firestore/cloud_firestore.dart';

/// Data Transfer Object for Payment entity.
class PaymentDto {
  const PaymentDto({
    required this.id,
    required this.membershipId,
    required this.userId,
    required this.libraryId,
    required this.amount,
    required this.currency,
    required this.status,
    this.mode = 'online',
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
  final String status;
  final String mode;
  final String? gatewayOrderId;
  final String? gatewayPaymentId;
  final String? failureReason;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  final Timestamp? expiresAt;
  final Timestamp? approvedAt;
  final String? approvedByOwnerId;
  final String? utrNumber;
  final String? paymentProofUrl;
  final Timestamp? studentMarkedPaidAt;

  factory PaymentDto.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return PaymentDto(
      id: doc.id,
      membershipId: data['membershipId'] as String,
      userId: data['userId'] as String,
      libraryId: data['libraryId'] as String,
      amount: (data['amount'] as num).toDouble(),
      currency: data['currency'] as String,
      status: data['status'] as String,
      mode: data['mode'] as String? ?? 'online',
      gatewayOrderId: data['gatewayOrderId'] as String?,
      gatewayPaymentId: data['gatewayPaymentId'] as String?,
      failureReason: data['failureReason'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
      expiresAt: data['expiresAt'] as Timestamp?,
      approvedAt: data['approvedAt'] as Timestamp?,
      approvedByOwnerId: data['approvedByOwnerId'] as String?,
      utrNumber: data['utrNumber'] as String?,
      paymentProofUrl: data['paymentProofUrl'] as String?,
      studentMarkedPaidAt: data['studentMarkedPaidAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'membershipId': membershipId,
      'userId': userId,
      'libraryId': libraryId,
      'amount': amount,
      'currency': currency,
      'status': status,
      'mode': mode,
      'gatewayOrderId': gatewayOrderId,
      'gatewayPaymentId': gatewayPaymentId,
      'failureReason': failureReason,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': updatedAt ?? FieldValue.serverTimestamp(),
      'expiresAt': expiresAt,
      'approvedAt': approvedAt,
      'approvedByOwnerId': approvedByOwnerId,
      'utrNumber': utrNumber,
      'paymentProofUrl': paymentProofUrl,
      'studentMarkedPaidAt': studentMarkedPaidAt,
    };
  }

  static const String collectionName = 'payments';
}
