import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/membership.dart';
import '../../domain/entities/payment.dart';
import '../../domain/entities/payment_breakdown.dart';
import '../../domain/entities/slot.dart';
import '../models/membership_dto.dart';

/// Mapper for Membership entity <-> MembershipDto conversion.
class MembershipMapper {
  const MembershipMapper._();

  static Membership toEntity(MembershipDto dto) {
    return Membership(
      id: dto.id,
      userId: dto.userId,
      studentName: dto.studentName,
      libraryId: dto.libraryId,
      plan: _parsePlan(dto.plan),
      startDate: dto.startDate.toDate(),
      endDate: dto.endDate.toDate(),
      status: _parseStatus(dto.status),
      phoneNumber: dto.phoneNumber,
      assignedSeatId: dto.assignedSeatId,
      slot: Slot.fromString(dto.slot),
      slotId: dto.slotId,
      createdAt: dto.createdAt?.toDate(),
      paymentMethod: _parsePaymentMode(dto.paymentMethod),
      paymentStatus: _parsePaymentStatus(dto.paymentStatus),
      paymentBreakdown: _parsePaymentBreakdown(dto.paymentBreakdown),
      assignedByOwner: dto.assignedByOwner ?? false,
      customDurationDays: dto.customDurationDays,
      customDurationMonths: dto.customDurationMonths,
    );
  }

  static MembershipDto toDto(Membership entity) {
    return MembershipDto(
      id: entity.id,
      userId: entity.userId,
      studentName: entity.studentName,
      libraryId: entity.libraryId,
      plan: entity.plan.name,
      startDate: Timestamp.fromDate(entity.startDate),
      endDate: Timestamp.fromDate(entity.endDate),
      status: entity.status.name,
      phoneNumber: entity.phoneNumber,
      assignedSeatId: entity.assignedSeatId,
      slot: entity.slot?.name,
      slotId: entity.slotId,
      createdAt: entity.createdAt != null
          ? Timestamp.fromDate(entity.createdAt!)
          : null,
      paymentMethod: entity.paymentMethod?.name,
      paymentStatus: entity.paymentStatus.name,
      paymentBreakdown: _paymentBreakdownToMap(entity.paymentBreakdown),
      assignedByOwner: entity.assignedByOwner,
      customDurationDays: entity.customDurationDays,
      customDurationMonths: entity.customDurationMonths,
    );
  }

  static MembershipPlan _parsePlan(String plan) {
    return MembershipPlan.values.firstWhere(
      (e) => e.name == plan,
      orElse: () => MembershipPlan.monthly,
    );
  }

  static MembershipStatus _parseStatus(String status) {
    return MembershipStatus.values.firstWhere(
      (e) => e.name == status,
      orElse: () => MembershipStatus.active,
    );
  }

  static PaymentMode? _parsePaymentMode(String? mode) {
    if (mode == null) return null;
    return PaymentMode.values.firstWhere(
      (e) => e.name == mode,
      orElse: () => PaymentMode.online,
    );
  }

  static MembershipPaymentStatus _parsePaymentStatus(String? status) {
    if (status == null) return MembershipPaymentStatus.pending;
    return MembershipPaymentStatus.values.firstWhere(
      (e) => e.name == status,
      orElse: () => MembershipPaymentStatus.pending,
    );
  }

  static PaymentBreakdown? _parsePaymentBreakdown(Map<String, dynamic>? map) {
    if (map == null) return null;
    return PaymentBreakdown(
      amountPaid: (map['amountPaid'] as num?)?.toDouble() ?? 0.0,
      amountRemaining: (map['amountRemaining'] as num?)?.toDouble() ?? 0.0,
      notes: map['notes'] as String?,
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  static Map<String, dynamic>? _paymentBreakdownToMap(
    PaymentBreakdown? breakdown,
  ) {
    if (breakdown == null) return null;
    return {
      'amountPaid': breakdown.amountPaid,
      'amountRemaining': breakdown.amountRemaining,
      if (breakdown.notes != null) 'notes': breakdown.notes,
      if (breakdown.discount > 0) 'discount': breakdown.discount,
    };
  }
}
