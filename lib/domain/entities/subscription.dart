import 'package:equatable/equatable.dart';

/// Represents an owner's subscription to the platform.
/// Pricing based on seat count + duration.
/// Uses manual UPI payment with admin verification.
class Subscription extends Equatable {
  const Subscription({
    required this.id,
    required this.ownerId,
    required this.libraryId,
    required this.seatCount,
    required this.planId,
    required this.baseMonthlyPrice,
    required this.durationInMonths,
    required this.discountPercent,
    required this.finalAmount,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.transactionId,
    this.paymentProofUrl,
    this.couponCode,
    this.couponDiscount,
    this.adminDiscountPercent,
    this.adminDiscountAmount,
    this.markedPaidAt,
    this.approvedAt,
    this.approvedBy,
    this.rejectionReason,
    this.createdAt,
    this.updatedAt,
    this.isAdminBypassed = false,
    this.adminBypassNote,
  });

  final String id;
  final String ownerId;
  final String libraryId;
  final int seatCount;
  final String planId;
  final double baseMonthlyPrice;
  final int durationInMonths;
  final double discountPercent;
  final double finalAmount;
  final DateTime startDate;
  final DateTime endDate;
  final SubscriptionStatus status;
  final String? transactionId;
  final String? paymentProofUrl;
  final String? couponCode;
  final double? couponDiscount;
  final double? adminDiscountPercent;
  final double? adminDiscountAmount;
  final DateTime? markedPaidAt;
  final DateTime? approvedAt;
  final String? approvedBy;
  final String? rejectionReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isAdminBypassed;
  final String? adminBypassNote;

  /// Checks if subscription is currently active.
  bool isActive(DateTime currentDate) {
    final currentDateOnly = DateTime(
      currentDate.year,
      currentDate.month,
      currentDate.day,
    );
    final startDateOnly = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );
    final endDateOnly = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
    );
    return status == SubscriptionStatus.active &&
        !currentDateOnly.isBefore(startDateOnly) &&
        !currentDateOnly.isAfter(endDateOnly);
  }

  /// Checks if subscription has expired.
  /// A subscription expires only if the current date is AFTER the end date.
  /// If the current date equals the end date, it's still valid for that day.
  bool isExpired(DateTime currentDate) {
    if (status == SubscriptionStatus.expired) return true;
    final currentDateOnly = DateTime(
      currentDate.year,
      currentDate.month,
      currentDate.day,
    );
    final endDateOnly = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
    );
    return currentDateOnly.isAfter(endDateOnly);
  }

  /// Checks if subscription is pending verification.
  bool get isPendingVerification =>
      status == SubscriptionStatus.pendingVerification;

  /// Days remaining in subscription.
  int daysRemaining(DateTime currentDate) {
    if (isExpired(currentDate)) return 0;
    final currentDateOnly = DateTime(
      currentDate.year,
      currentDate.month,
      currentDate.day,
    );
    final endDateOnly = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
    );
    return endDateOnly.difference(currentDateOnly).inDays;
  }

  /// Calculates the gross amount before discount.
  double get grossAmount => baseMonthlyPrice * durationInMonths;

  /// Calculates the discount amount.
  double get discountAmount => grossAmount * (discountPercent / 100);

  /// Total coupon discount amount.
  double get couponDiscountAmount {
    if (couponDiscount == null || couponDiscount! <= 0) return 0;
    final afterDurationDiscount = grossAmount - discountAmount;
    return afterDurationDiscount * (couponDiscount! / 100);
  }

  @override
  List<Object?> get props => [
    id,
    ownerId,
    libraryId,
    seatCount,
    planId,
    baseMonthlyPrice,
    durationInMonths,
    discountPercent,
    finalAmount,
    startDate,
    endDate,
    status,
    transactionId,
    paymentProofUrl,
    couponCode,
    couponDiscount,
    adminDiscountPercent,
    adminDiscountAmount,
    markedPaidAt,
    approvedAt,
    approvedBy,
    rejectionReason,
    createdAt,
    updatedAt,
    isAdminBypassed,
    adminBypassNote,
  ];

  Subscription copyWith({
    String? id,
    String? ownerId,
    String? libraryId,
    int? seatCount,
    String? planId,
    double? baseMonthlyPrice,
    int? durationInMonths,
    double? discountPercent,
    double? finalAmount,
    DateTime? startDate,
    DateTime? endDate,
    SubscriptionStatus? status,
    String? transactionId,
    String? paymentProofUrl,
    String? couponCode,
    double? couponDiscount,
    double? adminDiscountPercent,
    double? adminDiscountAmount,
    DateTime? markedPaidAt,
    DateTime? approvedAt,
    String? approvedBy,
    String? rejectionReason,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isAdminBypassed,
    String? adminBypassNote,
  }) {
    return Subscription(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      libraryId: libraryId ?? this.libraryId,
      seatCount: seatCount ?? this.seatCount,
      planId: planId ?? this.planId,
      baseMonthlyPrice: baseMonthlyPrice ?? this.baseMonthlyPrice,
      durationInMonths: durationInMonths ?? this.durationInMonths,
      discountPercent: discountPercent ?? this.discountPercent,
      finalAmount: finalAmount ?? this.finalAmount,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      transactionId: transactionId ?? this.transactionId,
      paymentProofUrl: paymentProofUrl ?? this.paymentProofUrl,
      couponCode: couponCode ?? this.couponCode,
      couponDiscount: couponDiscount ?? this.couponDiscount,
      adminDiscountPercent: adminDiscountPercent ?? this.adminDiscountPercent,
      adminDiscountAmount: adminDiscountAmount ?? this.adminDiscountAmount,
      markedPaidAt: markedPaidAt ?? this.markedPaidAt,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isAdminBypassed: isAdminBypassed ?? this.isAdminBypassed,
      adminBypassNote: adminBypassNote ?? this.adminBypassNote,
    );
  }

  /// Marks payment as done by owner (pending admin verification).
  Subscription markPaymentDone({required String txnId, String? proofUrl}) {
    return copyWith(
      status: SubscriptionStatus.pendingVerification,
      transactionId: txnId,
      paymentProofUrl: proofUrl,
      markedPaidAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Approves subscription (by admin).
  Subscription approve({required String adminId}) {
    final now = DateTime.now();
    return copyWith(
      status: SubscriptionStatus.active,
      approvedAt: now,
      approvedBy: adminId,
      startDate: now,
      endDate: DateTime(now.year, now.month + durationInMonths, now.day),
      updatedAt: now,
    );
  }

  /// Approves subscription with specific dates (for extensions).
  Subscription approveWithDates({
    required String adminId,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return copyWith(
      status: SubscriptionStatus.active,
      approvedAt: DateTime.now(),
      approvedBy: adminId,
      startDate: startDate,
      endDate: endDate,
      updatedAt: DateTime.now(),
    );
  }

  /// Rejects subscription (by admin).
  Subscription reject({required String adminId, required String reason}) {
    return copyWith(
      status: SubscriptionStatus.rejected,
      approvedBy: adminId,
      rejectionReason: reason,
      updatedAt: DateTime.now(),
    );
  }

  /// Marks subscription as expired.
  Subscription expire() {
    return copyWith(
      status: SubscriptionStatus.expired,
      updatedAt: DateTime.now(),
    );
  }

  /// Admin grants free bypass (no payment required).
  Subscription adminBypass({required String adminId, String? note}) {
    final now = DateTime.now();
    return copyWith(
      status: SubscriptionStatus.active,
      isAdminBypassed: true,
      adminBypassNote: note,
      approvedAt: now,
      approvedBy: adminId,
      startDate: now,
      // Give 1 year of free access for bypassed accounts
      endDate: DateTime(now.year + 1, now.month, now.day),
      updatedAt: now,
    );
  }

  /// Admin extends expiry date.
  Subscription extendExpiry({
    required String adminId,
    required DateTime newEndDate,
    String? note,
  }) {
    return copyWith(
      endDate: newEndDate,
      status: SubscriptionStatus.active,
      approvedBy: adminId,
      adminBypassNote: note ?? adminBypassNote,
      updatedAt: DateTime.now(),
    );
  }

  /// Admin removes bypass.
  Subscription removeBypass() {
    return copyWith(
      isAdminBypassed: false,
      adminBypassNote: null,
      updatedAt: DateTime.now(),
    );
  }
}

/// Subscription status.
enum SubscriptionStatus {
  /// Payment pending - owner needs to pay
  pending,

  /// Payment marked done, awaiting admin verification
  pendingVerification,

  /// Subscription is active
  active,

  /// Subscription has expired
  expired,

  /// Payment was rejected by admin
  rejected,

  /// Subscription was cancelled
  cancelled,
}

/// Extension for display names.
extension SubscriptionStatusExtension on SubscriptionStatus {
  String get displayName {
    switch (this) {
      case SubscriptionStatus.pending:
        return 'Payment Pending';
      case SubscriptionStatus.pendingVerification:
        return 'Awaiting Verification';
      case SubscriptionStatus.active:
        return 'Active';
      case SubscriptionStatus.expired:
        return 'Expired';
      case SubscriptionStatus.rejected:
        return 'Rejected';
      case SubscriptionStatus.cancelled:
        return 'Cancelled';
    }
  }
}
