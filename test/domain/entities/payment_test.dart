import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/payment.dart';

void main() {
  group('Payment', () {
    group('PaymentMode', () {
      test('should have correct display names', () {
        expect(PaymentMode.online.displayName, 'Online');
        expect(PaymentMode.cash.displayName, 'Cash');
        expect(PaymentMode.upi.displayName, 'UPI');
      });

      test('should correctly identify modes requiring approval', () {
        expect(PaymentMode.online.requiresApproval, false);
        expect(PaymentMode.cash.requiresApproval, true);
        expect(PaymentMode.upi.requiresApproval, true);
      });
    });

    group('createCashPayment', () {
      test('should create payment with correct mode and status', () {
        final payment = Payment.createCashPayment(
          id: 'test-id',
          membershipId: 'membership-1',
          userId: 'user-1',
          libraryId: 'library-1',
          amount: 1000.0,
        );

        expect(payment.mode, PaymentMode.cash);
        expect(payment.status, PaymentStatus.initiated);
        expect(payment.amount, 1000.0);
        expect(payment.currency, 'INR');
        expect(payment.expiresAt, isNull);
      });
    });

    group('createUpiPayment', () {
      test('should create payment with correct mode and status', () {
        final payment = Payment.createUpiPayment(
          id: 'test-id',
          membershipId: 'membership-1',
          userId: 'user-1',
          libraryId: 'library-1',
          amount: 1500.0,
        );

        expect(payment.mode, PaymentMode.upi);
        expect(payment.status, PaymentStatus.initiated);
        expect(payment.amount, 1500.0);
        expect(payment.studentMarkedPaidAt, isNull);
        expect(payment.utrNumber, isNull);
      });
    });

    group('payment status helpers', () {
      test(
        'isPendingCashApproval should return true for initiated cash payment',
        () {
          final payment = Payment.createCashPayment(
            id: 'test-id',
            membershipId: 'membership-1',
            userId: 'user-1',
            libraryId: 'library-1',
            amount: 1000.0,
          );

          expect(payment.isPendingCashApproval, true);
          expect(payment.isCashPayment, true);
        },
      );

      test('isAwaitingUpiPayment should return true for new UPI payment', () {
        final payment = Payment.createUpiPayment(
          id: 'test-id',
          membershipId: 'membership-1',
          userId: 'user-1',
          libraryId: 'library-1',
          amount: 1000.0,
        );

        expect(payment.isAwaitingUpiPayment, true);
        expect(payment.isPendingUpiApproval, false);
        expect(payment.isUpiPayment, true);
      });

      test('isPendingUpiApproval should return true after marking as paid', () {
        final payment = Payment.createUpiPayment(
          id: 'test-id',
          membershipId: 'membership-1',
          userId: 'user-1',
          libraryId: 'library-1',
          amount: 1000.0,
        );

        final markedPaid = payment.markUpiAsPaid(utr: 'UTR123');

        expect(markedPaid.isPendingUpiApproval, true);
        expect(markedPaid.isAwaitingUpiPayment, false);
        expect(markedPaid.studentMarkedPaidAt, isNotNull);
        expect(markedPaid.utrNumber, 'UTR123');
      });

      test('isPendingApproval should work for both cash and UPI', () {
        final cashPayment = Payment.createCashPayment(
          id: 'cash-id',
          membershipId: 'membership-1',
          userId: 'user-1',
          libraryId: 'library-1',
          amount: 1000.0,
        );

        final upiPayment = Payment.createUpiPayment(
          id: 'upi-id',
          membershipId: 'membership-2',
          userId: 'user-1',
          libraryId: 'library-1',
          amount: 1500.0,
        ).markUpiAsPaid();

        expect(cashPayment.isPendingApproval, true);
        expect(upiPayment.isPendingApproval, true);
      });
    });

    group('markUpiAsPaid', () {
      test('should set studentMarkedPaidAt and UTR', () {
        final payment = Payment.createUpiPayment(
          id: 'test-id',
          membershipId: 'membership-1',
          userId: 'user-1',
          libraryId: 'library-1',
          amount: 1000.0,
        );

        final markedPaid = payment.markUpiAsPaid(
          utr: 'UTR12345',
          proofUrl: 'https://example.com/proof.jpg',
        );

        expect(markedPaid.studentMarkedPaidAt, isNotNull);
        expect(markedPaid.utrNumber, 'UTR12345');
        expect(markedPaid.paymentProofUrl, 'https://example.com/proof.jpg');
        expect(markedPaid.status, PaymentStatus.initiated);
      });

      test('should work without optional parameters', () {
        final payment = Payment.createUpiPayment(
          id: 'test-id',
          membershipId: 'membership-1',
          userId: 'user-1',
          libraryId: 'library-1',
          amount: 1000.0,
        );

        final markedPaid = payment.markUpiAsPaid();

        expect(markedPaid.studentMarkedPaidAt, isNotNull);
        expect(markedPaid.utrNumber, isNull);
        expect(markedPaid.paymentProofUrl, isNull);
      });
    });

    group('approveUpiPayment', () {
      test('should set status to success and approvedAt', () {
        final payment = Payment.createUpiPayment(
          id: 'test-id',
          membershipId: 'membership-1',
          userId: 'user-1',
          libraryId: 'library-1',
          amount: 1000.0,
        ).markUpiAsPaid(utr: 'UTR123');

        final approved = payment.approveUpiPayment('owner-1');

        expect(approved.status, PaymentStatus.success);
        expect(approved.approvedAt, isNotNull);
        expect(approved.approvedByOwnerId, 'owner-1');
        expect(approved.isUpiApproved, true);
      });
    });

    group('approveCashPayment', () {
      test('should set status to success and approvedAt', () {
        final payment = Payment.createCashPayment(
          id: 'test-id',
          membershipId: 'membership-1',
          userId: 'user-1',
          libraryId: 'library-1',
          amount: 1000.0,
        );

        final approved = payment.approveCashPayment('owner-1');

        expect(approved.status, PaymentStatus.success);
        expect(approved.approvedAt, isNotNull);
        expect(approved.approvedByOwnerId, 'owner-1');
        expect(approved.isCashApproved, true);
      });
    });

  });
}
