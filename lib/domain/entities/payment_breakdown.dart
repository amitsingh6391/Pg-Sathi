import 'package:equatable/equatable.dart';

/// Represents payment breakdown for partial payments.
/// Used when a membership is booked with partial payment received.
class PaymentBreakdown extends Equatable {
  const PaymentBreakdown({
    required this.amountPaid,
    required this.amountRemaining,
    this.notes,
    this.discount = 0.0,
  });

  /// Amount already paid (in INR).
  final double amountPaid;

  /// Remaining amount to be paid (in INR).
  final double amountRemaining;

  /// Optional notes about the partial payment.
  final String? notes;

  /// Discount amount applied (in INR).
  final double discount;

  /// Total expected amount (before discount).
  double get totalAmountBeforeDiscount =>
      amountPaid + amountRemaining + discount;

  /// Total expected amount (after discount).
  double get totalAmount => amountPaid + amountRemaining;

  /// Whether payment is complete (no remaining amount).
  bool get isComplete => amountRemaining <= 0;

  /// Whether this is a partial payment.
  bool get isPartial => amountPaid > 0 && amountRemaining > 0;

  @override
  List<Object?> get props => [amountPaid, amountRemaining, notes, discount];

  PaymentBreakdown copyWith({
    double? amountPaid,
    double? amountRemaining,
    String? notes,
    double? discount,
  }) {
    return PaymentBreakdown(
      amountPaid: amountPaid ?? this.amountPaid,
      amountRemaining: amountRemaining ?? this.amountRemaining,
      notes: notes ?? this.notes,
      discount: discount ?? this.discount,
    );
  }

  /// Create a full payment breakdown (no partial payment).
  factory PaymentBreakdown.fullPayment(double totalAmount) {
    return PaymentBreakdown(amountPaid: totalAmount, amountRemaining: 0);
  }

  /// Create a partial payment breakdown.
  factory PaymentBreakdown.partial({
    required double amountPaid,
    required double totalAmount,
    String? notes,
    double discount = 0.0,
  }) {
    return PaymentBreakdown(
      amountPaid: amountPaid,
      amountRemaining: totalAmount - amountPaid,
      notes: notes,
      discount: discount,
    );
  }

  /// Whether discount has been applied.
  bool get hasDiscount => discount > 0;
}
