import '../../domain/entities/owner_trial.dart';
import '../../domain/entities/subscription.dart';
import '../models/subscription_dto.dart';

/// Mapper for Subscription entity <-> DTO conversions.
class SubscriptionMapper {
  const SubscriptionMapper._();

  /// Converts DTO to domain entity.
  static Subscription toDomain(SubscriptionDto dto) {
    return Subscription(
      id: dto.id,
      ownerId: dto.ownerId,
      libraryId: dto.libraryId,
      seatCount: dto.seatCount,
      planId: dto.planId,
      baseMonthlyPrice: dto.baseMonthlyPrice,
      durationInMonths: dto.durationInMonths,
      discountPercent: dto.discountPercent,
      finalAmount: dto.finalAmount,
      startDate: dto.startDate,
      endDate: dto.endDate,
      status: _parseStatus(dto.status),
      transactionId: dto.transactionId,
      paymentProofUrl: dto.paymentProofUrl,
      couponCode: dto.couponCode,
      couponDiscount: dto.couponDiscount,
      adminDiscountPercent: dto.adminDiscountPercent,
      adminDiscountAmount: dto.adminDiscountAmount,
      markedPaidAt: dto.markedPaidAt,
      approvedAt: dto.approvedAt,
      approvedBy: dto.approvedBy,
      rejectionReason: dto.rejectionReason,
      createdAt: dto.createdAt,
      updatedAt: dto.updatedAt,
      isAdminBypassed: dto.isAdminBypassed,
      adminBypassNote: dto.adminBypassNote,
    );
  }

  /// Converts domain entity to DTO.
  static SubscriptionDto toDto(Subscription entity) {
    return SubscriptionDto(
      id: entity.id,
      ownerId: entity.ownerId,
      libraryId: entity.libraryId,
      seatCount: entity.seatCount,
      planId: entity.planId,
      baseMonthlyPrice: entity.baseMonthlyPrice,
      durationInMonths: entity.durationInMonths,
      discountPercent: entity.discountPercent,
      finalAmount: entity.finalAmount,
      startDate: entity.startDate,
      endDate: entity.endDate,
      status: entity.status.name,
      transactionId: entity.transactionId,
      paymentProofUrl: entity.paymentProofUrl,
      couponCode: entity.couponCode,
      couponDiscount: entity.couponDiscount,
      adminDiscountPercent: entity.adminDiscountPercent,
      adminDiscountAmount: entity.adminDiscountAmount,
      markedPaidAt: entity.markedPaidAt,
      approvedAt: entity.approvedAt,
      approvedBy: entity.approvedBy,
      rejectionReason: entity.rejectionReason,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      isAdminBypassed: entity.isAdminBypassed,
      adminBypassNote: entity.adminBypassNote,
    );
  }

  static SubscriptionStatus _parseStatus(String status) {
    return SubscriptionStatus.values.firstWhere(
      (e) => e.name == status,
      orElse: () => SubscriptionStatus.pending,
    );
  }
}

/// Mapper for OwnerTrial entity <-> DTO conversions.
class OwnerTrialMapper {
  const OwnerTrialMapper._();

  /// Converts DTO to domain entity.
  static OwnerTrial toDomain(OwnerTrialDto dto) {
    return OwnerTrial(
      ownerId: dto.ownerId,
      startDate: dto.startDate,
      endDate: dto.endDate,
      isUsed: dto.isUsed,
    );
  }

  /// Converts domain entity to DTO.
  static OwnerTrialDto toDto(OwnerTrial entity) {
    return OwnerTrialDto(
      ownerId: entity.ownerId,
      startDate: entity.startDate,
      endDate: entity.endDate,
      isUsed: entity.isUsed,
    );
  }
}
