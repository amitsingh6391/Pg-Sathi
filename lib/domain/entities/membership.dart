import 'package:equatable/equatable.dart';

import 'payment.dart';
import 'payment_breakdown.dart';
import 'slot.dart';

/// Represents a student's membership to a library.
/// Now includes slot (morning/evening) for seat occupancy.
/// Supports both registered users (with userId) and unregistered members (phone-only).
/// Supports custom slots via slotId and partial payments via paymentBreakdown.
class Membership extends Equatable {
  const Membership({
    required this.id,
    required this.libraryId,
    required this.plan,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.phoneNumber,
    this.userId,
    this.studentName,
    this.assignedSeatId,
    this.slot,
    this.slotId,
    this.createdAt,
    this.paymentMethod,
    this.paymentStatus = MembershipPaymentStatus.pending,
    this.paymentBreakdown,
    this.assignedByOwner = false,
    this.customDurationDays,
    this.customDurationMonths,
  });

  final String id;

  /// User ID - nullable for unregistered members (assigned by phone number only).
  /// When student logs in later, this gets populated via sync.
  final String? userId;

  /// Student name - optional, used for unregistered students assigned by owner.
  /// When student registers, this is replaced by their actual name from user profile.
  final String? studentName;
  final String libraryId;
  final MembershipPlan plan;
  final DateTime startDate;
  final DateTime endDate;
  final MembershipStatus status;

  /// Phone number - always required for membership assignment.
  /// Used to link unregistered memberships when student logs in.
  final String phoneNumber;
  final String? assignedSeatId;

  /// Legacy slot enum (morning/evening) - kept for backward compatibility.
  /// Use slotId for custom slots.
  final Slot? slot;

  /// Custom slot ID - used when library has custom slots defined.
  /// If set, slot enum should be null.
  final String? slotId;
  final DateTime? createdAt;

  /// Payment method chosen during assignment (cash/upi).
  final PaymentMode? paymentMethod;

  /// Payment status for this membership.
  /// - pending: Awaiting payment/approval
  /// - markedPaid: Owner marked cash/UPI as received
  /// - autoPaid: Online payment succeeded automatically
  final MembershipPaymentStatus paymentStatus;

  /// Payment breakdown for partial payments.
  /// If null, full payment is expected/assumed.
  final PaymentBreakdown? paymentBreakdown;

  /// Whether this membership was assigned by owner without student login.
  final bool assignedByOwner;

  /// Checks if membership is currently active.
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
    return status == MembershipStatus.active &&
        !currentDateOnly.isBefore(startDateOnly) &&
        !currentDateOnly.isAfter(endDateOnly);
  }

  /// Checks if membership has expired.
  /// A membership expires only if the current date is AFTER the end date.
  /// If the current date equals the end date, it's still valid for that day.
  bool isExpired(DateTime currentDate) {
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

  /// Days remaining in membership.
  int daysRemaining(DateTime currentDate) {
    if (isExpired(currentDate)) return 0;
    final currentDateOnly = DateTime(currentDate.year, currentDate.month, currentDate.day);
    final endDateOnly = DateTime(endDate.year, endDate.month, endDate.day);
    return endDateOnly.difference(currentDateOnly).inDays;
  }

  /// Checks if this is an unregistered membership (no userId yet).
  bool get isUnregistered => userId == null;

  /// Whether this membership uses a custom slot.
  bool get usesCustomSlot => slotId != null && slotId!.isNotEmpty;

  /// Whether this membership has partial payment.
  bool get hasPartialPayment => paymentBreakdown?.isPartial ?? false;

  /// Custom duration in days (optional, for flexible membership periods).
  /// If set, overrides plan.durationInDays.
  final int? customDurationDays;

  /// Custom duration in months (optional, for flexible membership periods).
  /// If set, used to calculate duration alongside or instead of customDurationDays.
  final int? customDurationMonths;

  /// Gets the effective duration in days for this membership.
  /// Uses custom duration if available, otherwise falls back to plan duration.
  int get effectiveDurationInDays {
    if (customDurationMonths != null && customDurationMonths! > 0) {
      // Approximate: 1 month = 30 days
      return customDurationMonths! * 30;
    }
    if (customDurationDays != null && customDurationDays! > 0) {
      return customDurationDays!;
    }
    return plan.durationInDays;
  }

  /// True when assignment used a custom duration override (days or months).
  bool get hasCustomDuration =>
      (customDurationMonths != null && customDurationMonths! > 0) ||
      (customDurationDays != null && customDurationDays! > 0);

  /// Short label for lists/cards: custom duration when set, else [plan.displayLabel].
  String get planDisplayLabel {
    if (customDurationMonths != null && customDurationMonths! > 0) {
      final m = customDurationMonths!;
      return m == 1 ? '1 month (custom)' : '$m months (custom)';
    }
    if (customDurationDays != null && customDurationDays! > 0) {
      final d = customDurationDays!;
      return d == 1 ? '1 day (custom)' : '$d days (custom)';
    }
    return plan.displayLabel;
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    studentName,
    libraryId,
    plan,
    startDate,
    endDate,
    status,
    phoneNumber,
    assignedSeatId,
    slot,
    slotId,
    createdAt,
    paymentMethod,
    paymentStatus,
    paymentBreakdown,
    assignedByOwner,
    customDurationDays,
    customDurationMonths,
  ];

  Membership copyWith({
    String? id,
    String? userId,
    String? studentName,
    String? libraryId,
    MembershipPlan? plan,
    DateTime? startDate,
    DateTime? endDate,
    MembershipStatus? status,
    String? phoneNumber,
    String? assignedSeatId,
    Slot? slot,
    String? slotId,
    DateTime? createdAt,
    PaymentMode? paymentMethod,
    MembershipPaymentStatus? paymentStatus,
    PaymentBreakdown? paymentBreakdown,
    bool? assignedByOwner,
    int? customDurationDays,
    int? customDurationMonths,
  }) {
    return Membership(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      studentName: studentName ?? this.studentName,
      libraryId: libraryId ?? this.libraryId,
      plan: plan ?? this.plan,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      assignedSeatId: assignedSeatId ?? this.assignedSeatId,
      slot: slot ?? this.slot,
      slotId: slotId ?? this.slotId,
      createdAt: createdAt ?? this.createdAt,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentBreakdown: paymentBreakdown ?? this.paymentBreakdown,
      assignedByOwner: assignedByOwner ?? this.assignedByOwner,
      customDurationDays: customDurationDays ?? this.customDurationDays,
      customDurationMonths: customDurationMonths ?? this.customDurationMonths,
    );
  }

  /// Marks membership as expired.
  Membership expire() {
    return copyWith(status: MembershipStatus.expired);
  }

  /// Assigns a seat to this membership.
  Membership assignSeat(String seatId) {
    return copyWith(assignedSeatId: seatId);
  }

  /// Clears the seat assignment (makes seat available).
  Membership clearSeat() {
    return Membership(
      id: id,
      userId: userId,
      libraryId: libraryId,
      plan: plan,
      startDate: startDate,
      endDate: endDate,
      status: status,
      phoneNumber: phoneNumber,
      assignedSeatId: null,
      slot: null,
      slotId: null,
      createdAt: createdAt,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
      paymentBreakdown: null,
      assignedByOwner: assignedByOwner,
    );
  }

  /// Assigns seat and slot to this membership.
  Membership assignSeatAndSlot({required String seatId, required Slot slot}) {
    return Membership(
      id: id,
      userId: userId,
      libraryId: libraryId,
      plan: plan,
      startDate: startDate,
      endDate: endDate,
      status: status,
      phoneNumber: phoneNumber,
      assignedSeatId: seatId,
      slot: slot,
      slotId: null,
      createdAt: createdAt,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
      paymentBreakdown: paymentBreakdown,
      assignedByOwner: assignedByOwner,
    );
  }

  /// Assigns seat and custom slot to this membership.
  Membership assignSeatAndCustomSlot({
    required String seatId,
    required String customSlotId,
  }) {
    return Membership(
      id: id,
      userId: userId,
      libraryId: libraryId,
      plan: plan,
      startDate: startDate,
      endDate: endDate,
      status: status,
      phoneNumber: phoneNumber,
      assignedSeatId: seatId,
      slot: null,
      slotId: customSlotId,
      createdAt: createdAt,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
      paymentBreakdown: paymentBreakdown,
      assignedByOwner: assignedByOwner,
    );
  }

  /// Cancels membership (early exit).
  Membership cancel() {
    return Membership(
      id: id,
      userId: userId,
      libraryId: libraryId,
      plan: plan,
      startDate: startDate,
      endDate: endDate,
      status: MembershipStatus.cancelled,
      phoneNumber: phoneNumber,
      assignedSeatId: null,
      slot: null,
      slotId: null,
      createdAt: createdAt,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
      paymentBreakdown: null,
      assignedByOwner: assignedByOwner,
    );
  }

  /// Activates membership after successful payment.
  Membership activate() {
    return copyWith(status: MembershipStatus.active);
  }

  /// Checks if membership is pending payment.
  bool get isPendingPayment => status == MembershipStatus.pendingPayment;

  /// Whether this membership can still have its seat, dates, or student name
  /// updated by the owner.
  ///
  /// Editable when the membership is currently in flight — either already
  /// [MembershipStatus.active] or [MembershipStatus.pendingPayment] (seat
  /// reserved, awaiting cash/UPI approval). Terminal states (expired,
  /// cancelled, suspended) are intentionally excluded — those flows should
  /// renew or reassign instead of mutate in place.
  bool get isEditable =>
      status == MembershipStatus.active ||
      status == MembershipStatus.pendingPayment;

  /// Checks if seat is reserved (pending payment).
  bool get hasSeatReserved =>
      assignedSeatId != null && status == MembershipStatus.pendingPayment;

  /// Links this unregistered membership to a user ID.
  /// Called when student logs in and phone number matches.
  Membership linkToUser(String userId) {
    return copyWith(userId: userId);
  }

  /// Marks payment as received (for cash/UPI).
  Membership markPaymentReceived() {
    return copyWith(
      paymentStatus: MembershipPaymentStatus.markedPaid,
      status: MembershipStatus.active,
    );
  }

  /// Checks if payment is marked as received (cash/UPI approved).
  bool get isPaymentMarkedReceived =>
      paymentStatus == MembershipPaymentStatus.markedPaid;

  /// Checks if payment is pending approval.
  bool get isPaymentPendingApproval =>
      paymentStatus == MembershipPaymentStatus.pending &&
      (paymentMethod == PaymentMode.cash || paymentMethod == PaymentMode.upi);

  /// Checks if seat should be counted as occupied.
  /// Only counts if payment is marked received or auto-paid (razorpay).
  bool shouldCountAsOccupied(DateTime currentDate) {
    if (!isActive(currentDate) && status != MembershipStatus.pendingPayment) {
      return false;
    }
    // For pendingPayment status, only count if payment is marked received
    if (status == MembershipStatus.pendingPayment) {
      return paymentStatus == MembershipPaymentStatus.markedPaid ||
          paymentStatus == MembershipPaymentStatus.autoPaid;
    }
    return true;
  }
}

/// Payment status for membership.
/// Tracks payment state separately from membership status.
enum MembershipPaymentStatus {
  /// Awaiting payment or owner approval.
  pending,

  /// Owner marked cash/UPI as received.
  markedPaid,

  /// Online payment succeeded automatically.
  autoPaid,
}

/// Membership plan types.
enum MembershipPlan { daily, weekly, monthly, quarterly, yearly }

/// Membership status.
/// - pendingPayment: Seat reserved, awaiting payment
/// - active: Payment complete, membership active
/// - expired: Membership period ended
/// - cancelled: Cancelled by owner/student
/// - suspended: Temporarily suspended (e.g., for payment issues)
enum MembershipStatus { pendingPayment, active, expired, cancelled, suspended }

/// Extension for plan duration calculation.
extension MembershipPlanExtension on MembershipPlan {
  int get durationInDays {
    switch (this) {
      case MembershipPlan.daily:
        return 1;
      case MembershipPlan.weekly:
        return 7;
      case MembershipPlan.monthly:
        return 30;
      case MembershipPlan.quarterly:
        return 90;
      case MembershipPlan.yearly:
        return 365;
    }
  }

  /// Display label for the plan (shows plan name, not duration).
  String get displayLabel {
    switch (this) {
      case MembershipPlan.daily:
        return 'Daily';
      case MembershipPlan.weekly:
        return 'Weekly';
      case MembershipPlan.monthly:
        return 'Monthly';
      case MembershipPlan.quarterly:
        return 'Quarterly';
      case MembershipPlan.yearly:
        return 'Yearly';
    }
  }

  /// Display label with duration (e.g., "Monthly (30 Days)").
  String get displayLabelWithDuration {
    switch (this) {
      case MembershipPlan.daily:
        return 'Daily (1 Day)';
      case MembershipPlan.weekly:
        return 'Weekly (7 Days)';
      case MembershipPlan.monthly:
        return 'Monthly (30 Days)';
      case MembershipPlan.quarterly:
        return 'Quarterly (90 Days)';
      case MembershipPlan.yearly:
        return 'Yearly (365 Days)';
    }
  }
}
