import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/payment.dart';
import '../models/payment_dto.dart';

/// Mapper for Payment entity <-> PaymentDto conversion.
class PaymentMapper {
  const PaymentMapper._();

  static Payment toEntity(PaymentDto dto) {
    return Payment(
      id: dto.id,
      membershipId: dto.membershipId,
      userId: dto.userId,
      libraryId: dto.libraryId,
      amount: dto.amount,
      currency: dto.currency,
      status: _parseStatus(dto.status),
      mode: _parseMode(dto.mode),
      gatewayOrderId: dto.gatewayOrderId,
      gatewayPaymentId: dto.gatewayPaymentId,
      failureReason: dto.failureReason,
      createdAt: dto.createdAt?.toDate(),
      updatedAt: dto.updatedAt?.toDate(),
      expiresAt: dto.expiresAt?.toDate(),
      approvedAt: dto.approvedAt?.toDate(),
      approvedByOwnerId: dto.approvedByOwnerId,
      utrNumber: dto.utrNumber,
      paymentProofUrl: dto.paymentProofUrl,
      studentMarkedPaidAt: dto.studentMarkedPaidAt?.toDate(),
    );
  }

  static PaymentDto toDto(Payment entity) {
    return PaymentDto(
      id: entity.id,
      membershipId: entity.membershipId,
      userId: entity.userId,
      libraryId: entity.libraryId,
      amount: entity.amount,
      currency: entity.currency,
      status: entity.status.name,
      mode: entity.mode.name,
      gatewayOrderId: entity.gatewayOrderId,
      gatewayPaymentId: entity.gatewayPaymentId,
      failureReason: entity.failureReason,
      createdAt: entity.createdAt != null
          ? Timestamp.fromDate(entity.createdAt!)
          : null,
      updatedAt: entity.updatedAt != null
          ? Timestamp.fromDate(entity.updatedAt!)
          : null,
      expiresAt: entity.expiresAt != null
          ? Timestamp.fromDate(entity.expiresAt!)
          : null,
      approvedAt: entity.approvedAt != null
          ? Timestamp.fromDate(entity.approvedAt!)
          : null,
      approvedByOwnerId: entity.approvedByOwnerId,
      utrNumber: entity.utrNumber,
      paymentProofUrl: entity.paymentProofUrl,
      studentMarkedPaidAt: entity.studentMarkedPaidAt != null
          ? Timestamp.fromDate(entity.studentMarkedPaidAt!)
          : null,
    );
  }

  static PaymentStatus _parseStatus(String status) {
    return PaymentStatus.values.firstWhere(
      (e) => e.name == status,
      orElse: () => PaymentStatus.initiated,
    );
  }

  static PaymentMode _parseMode(String mode) {
    return PaymentMode.values.firstWhere(
      (e) => e.name == mode,
      orElse: () => PaymentMode.online,
    );
  }
}
