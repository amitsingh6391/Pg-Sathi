import 'package:flutter_test/flutter_test.dart';

import 'package:pg_manager/domain/entities/payment_breakdown.dart';

void main() {
  group('PaymentBreakdown', () {
    test('should create a full payment breakdown', () {
      const breakdown = PaymentBreakdown(
        amountPaid: 1000.0,
        amountRemaining: 0.0,
      );

      expect(breakdown.amountPaid, 1000.0);
      expect(breakdown.amountRemaining, 0.0);
      expect(breakdown.totalAmount, 1000.0);
      expect(breakdown.isComplete, true);
      expect(breakdown.isPartial, false);
    });

    test('should create a partial payment breakdown', () {
      const breakdown = PaymentBreakdown(
        amountPaid: 500.0,
        amountRemaining: 500.0,
        notes: 'Partial payment received',
      );

      expect(breakdown.amountPaid, 500.0);
      expect(breakdown.amountRemaining, 500.0);
      expect(breakdown.totalAmount, 1000.0);
      expect(breakdown.isComplete, false);
      expect(breakdown.isPartial, true);
      expect(breakdown.notes, 'Partial payment received');
    });

    test('should create full payment using factory', () {
      final breakdown = PaymentBreakdown.fullPayment(1000.0);

      expect(breakdown.amountPaid, 1000.0);
      expect(breakdown.amountRemaining, 0.0);
      expect(breakdown.isComplete, true);
    });

    test('should create partial payment using factory', () {
      final breakdown = PaymentBreakdown.partial(
        amountPaid: 300.0,
        totalAmount: 1000.0,
        notes: 'First installment',
      );

      expect(breakdown.amountPaid, 300.0);
      expect(breakdown.amountRemaining, 700.0);
      expect(breakdown.totalAmount, 1000.0);
      expect(breakdown.isPartial, true);
      expect(breakdown.notes, 'First installment');
    });

    test('should update payment breakdown', () {
      const breakdown = PaymentBreakdown(
        amountPaid: 500.0,
        amountRemaining: 500.0,
      );

      final updated = breakdown.copyWith(
        amountPaid: 800.0,
        amountRemaining: 200.0,
      );

      expect(updated.amountPaid, 800.0);
      expect(updated.amountRemaining, 200.0);
      expect(updated.totalAmount, 1000.0);
    });
  });
}
