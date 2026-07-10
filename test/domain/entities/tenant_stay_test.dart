import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/tenant_stay.dart';

void main() {
  group('TenantStay entity', () {
    final stay = TenantStay(
      id: 'stay-1',
      pgPropertyId: 'pg-1',
      roomId: 'room-1',
      bedId: 'bed-1',
      tenantName: 'Amit Kumar',
      phoneNumber: '9876543210',
      startDate: DateTime(2026, 1, 1),
      monthlyRent: 8500,
      securityDeposit: 10000,
    );

    test('starts as pending payment by default', () {
      expect(stay.isPendingPayment, true);
      expect(stay.status, TenantStayStatus.pendingPayment);
      expect(stay.paymentStatus, TenantPaymentStatus.pending);
    });

    test('activate marks stay active and payment received', () {
      final active = stay.activate();

      expect(active.status, TenantStayStatus.active);
      expect(active.paymentStatus, TenantPaymentStatus.markedPaid);
      expect(active.isActive(DateTime(2026, 1, 2)), true);
    });

    test('checkout marks stay checked out and stores checkout date', () {
      final checkoutDate = DateTime(2026, 2, 1);
      final checkedOut = stay.activate().checkout(checkoutDate);

      expect(checkedOut.isCheckedOut, true);
      expect(checkedOut.actualCheckoutDate, checkoutDate);
      expect(checkedOut.isActive(DateTime(2026, 2, 2)), false);
    });

    test('cancel marks stay cancelled', () {
      final cancelled = stay.cancel();

      expect(cancelled.status, TenantStayStatus.cancelled);
    });
  });
}
