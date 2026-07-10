import 'package:equatable/equatable.dart';

/// Paid entitlement for a student.
///
/// A single active row per user grants ad-free UX, priority push delivery,
/// and future premium features. Lifecycle is idempotent: renewals extend
/// [validTill]; cancellations set [isActive] false but preserve history.
class StudentPremiumSubscription extends Equatable {
  const StudentPremiumSubscription({
    required this.id,
    required this.userId,
    required this.plan,
    required this.amountPaise,
    required this.startedAt,
    required this.validTill,
    required this.isActive,
    required this.createdAt,
    this.paymentId,
    this.paymentProvider,
    this.cancelledAt,
  });

  final String id;
  final String userId;
  final StudentPremiumPlan plan;

  /// Amount actually charged in paise (₹49 → 4900).
  final int amountPaise;

  final DateTime startedAt;

  /// Inclusive end of entitlement. Gating logic compares against
  /// [DateTime.now] using [isCurrentlyActive].
  final DateTime validTill;

  /// Server-side flag; may be false while [validTill] is still in future
  /// (e.g. admin-cancelled or refunded).
  final bool isActive;

  final DateTime createdAt;
  final String? paymentId;
  final String? paymentProvider;
  final DateTime? cancelledAt;

  /// Effective gating predicate — combines the activation flag with the
  /// validity window, guarding against clock drift on the client by treating
  /// "within 1 minute of expiry" as still-active.
  bool get isCurrentlyActive {
    if (!isActive) return false;
    final now = DateTime.now();
    return validTill.isAfter(now);
  }

  StudentPremiumSubscription copyWith({
    String? id,
    String? userId,
    StudentPremiumPlan? plan,
    int? amountPaise,
    DateTime? startedAt,
    DateTime? validTill,
    bool? isActive,
    DateTime? createdAt,
    String? paymentId,
    String? paymentProvider,
    DateTime? cancelledAt,
  }) {
    return StudentPremiumSubscription(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      plan: plan ?? this.plan,
      amountPaise: amountPaise ?? this.amountPaise,
      startedAt: startedAt ?? this.startedAt,
      validTill: validTill ?? this.validTill,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      paymentId: paymentId ?? this.paymentId,
      paymentProvider: paymentProvider ?? this.paymentProvider,
      cancelledAt: cancelledAt ?? this.cancelledAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        plan,
        amountPaise,
        startedAt,
        validTill,
        isActive,
        createdAt,
        paymentId,
        paymentProvider,
        cancelledAt,
      ];
}

/// Catalogue of offered plans. Pricing is authoritative here because
/// payment amount validation happens before persisting.
enum StudentPremiumPlan {
  monthly(
    label: 'Monthly',
    priceInPaise: 4900,
    durationDays: 30,
  ),
  quarterly(
    label: '3 Months',
    priceInPaise: 12900,
    durationDays: 90,
  ),
  yearly(
    label: 'Yearly',
    priceInPaise: 39900,
    durationDays: 365,
  );

  const StudentPremiumPlan({
    required this.label,
    required this.priceInPaise,
    required this.durationDays,
  });

  final String label;
  final int priceInPaise;
  final int durationDays;

  int get priceInRupees => priceInPaise ~/ 100;
}
