import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/subscription.dart';

void main() {
  group('Subscription', () {
    late Subscription subscription;

    setUp(() {
      subscription = Subscription(
        id: 'test-id',
        ownerId: 'owner-1',
        libraryId: 'library-1',
        seatCount: 50,
        planId: 'tier_99',
        baseMonthlyPrice: 99,
        durationInMonths: 3,
        discountPercent: 10,
        finalAmount: 267.3,
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 4, 1),
        status: SubscriptionStatus.active,
      );
    });

    group('isActive', () {
      test(
        'should return true when current date is within subscription period',
        () {
          final currentDate = DateTime(2024, 2, 15);
          expect(subscription.isActive(currentDate), true);
        },
      );

      test('should return true on start date', () {
        final currentDate = DateTime(2024, 1, 1);
        expect(subscription.isActive(currentDate), true);
      });

      test('should return true on end date', () {
        final currentDate = DateTime(2024, 4, 1);
        expect(subscription.isActive(currentDate), true);
      });

      test('should return false when current date is before start date', () {
        final currentDate = DateTime(2023, 12, 31);
        expect(subscription.isActive(currentDate), false);
      });

      test('should return false when current date is after end date', () {
        final currentDate = DateTime(2024, 4, 2);
        expect(subscription.isActive(currentDate), false);
      });

      test('should return false when subscription status is not active', () {
        final expiredSubscription = subscription.copyWith(
          status: SubscriptionStatus.expired,
        );
        final currentDate = DateTime(2024, 2, 15);
        expect(expiredSubscription.isActive(currentDate), false);
      });
    });

    group('isExpired', () {
      test('should return true when current date is after end date', () {
        final currentDate = DateTime(2024, 4, 2);
        expect(subscription.isExpired(currentDate), true);
      });

      test('should return false when current date is before end date', () {
        final currentDate = DateTime(2024, 2, 15);
        expect(subscription.isExpired(currentDate), false);
      });

      test('should return true when status is expired', () {
        final expiredSubscription = subscription.copyWith(
          status: SubscriptionStatus.expired,
        );
        final currentDate = DateTime(2024, 2, 15);
        expect(expiredSubscription.isExpired(currentDate), true);
      });
    });

    group('daysRemaining', () {
      test('should return correct days remaining', () {
        final currentDate = DateTime(2024, 3, 1);
        expect(subscription.daysRemaining(currentDate), 31);
      });

      test('should return 0 when expired', () {
        final currentDate = DateTime(2024, 5, 1);
        expect(subscription.daysRemaining(currentDate), 0);
      });

      test('should return correct days on last day', () {
        final currentDate = DateTime(2024, 4, 1);
        expect(subscription.daysRemaining(currentDate), 0);
      });
    });

    group('grossAmount', () {
      test('should calculate gross amount correctly', () {
        // 99 * 3 = 297
        expect(subscription.grossAmount, 99 * 3);
      });
    });

    group('discountAmount', () {
      test('should calculate discount amount correctly', () {
        // 297 * 10% = 29.7
        expect(subscription.discountAmount, closeTo(29.7, 0.01));
      });
    });

    group('isPendingVerification', () {
      test('should return true when status is pendingVerification', () {
        final pendingSubscription = subscription.copyWith(
          status: SubscriptionStatus.pendingVerification,
        );
        expect(pendingSubscription.isPendingVerification, true);
      });

      test('should return false when status is not pendingVerification', () {
        expect(subscription.isPendingVerification, false);
      });
    });

    group('markPaymentDone', () {
      test('should update status to pendingVerification', () {
        final updated = subscription
            .copyWith(status: SubscriptionStatus.pending)
            .markPaymentDone(txnId: 'txn-123');

        expect(updated.status, SubscriptionStatus.pendingVerification);
        expect(updated.transactionId, 'txn-123');
        expect(updated.markedPaidAt, isNotNull);
      });
    });

    group('approve', () {
      test('should update status to active and set dates', () {
        final pendingSubscription = subscription.copyWith(
          status: SubscriptionStatus.pendingVerification,
        );

        final approved = pendingSubscription.approve(adminId: 'admin-1');

        expect(approved.status, SubscriptionStatus.active);
        expect(approved.approvedBy, 'admin-1');
        expect(approved.approvedAt, isNotNull);
      });
    });

    group('reject', () {
      test('should update status to rejected with reason from pendingVerification', () {
        final pendingSubscription = subscription.copyWith(
          status: SubscriptionStatus.pendingVerification,
        );

        final rejected = pendingSubscription.reject(
          adminId: 'admin-1',
          reason: 'Invalid transaction',
        );

        expect(rejected.status, SubscriptionStatus.rejected);
        expect(rejected.approvedBy, 'admin-1');
        expect(rejected.rejectionReason, 'Invalid transaction');
      });

      test('should update status to rejected with reason from pending', () {
        final pendingSubscription = subscription.copyWith(
          status: SubscriptionStatus.pending,
        );

        final rejected = pendingSubscription.reject(
          adminId: 'admin-1',
          reason: 'Invalid transaction',
        );

        expect(rejected.status, SubscriptionStatus.rejected);
        expect(rejected.approvedBy, 'admin-1');
        expect(rejected.rejectionReason, 'Invalid transaction');
      });
    });

    group('couponDiscountAmount', () {
      test('should return 0 when no coupon applied', () {
        expect(subscription.couponDiscountAmount, 0);
      });

      test('should calculate coupon discount correctly', () {
        final subscriptionWithCoupon = subscription.copyWith(
          couponDiscount: 10, // 10% coupon discount
        );

        // After duration discount: 267.3
        // Coupon discount: 267.3 * 10% = 26.73
        expect(
          subscriptionWithCoupon.couponDiscountAmount,
          closeTo(26.73, 0.01),
        );
      });
    });
  });

  group('SubscriptionStatus', () {
    test('displayName should return correct strings', () {
      expect(SubscriptionStatus.pending.displayName, 'Payment Pending');
      expect(
        SubscriptionStatus.pendingVerification.displayName,
        'Awaiting Verification',
      );
      expect(SubscriptionStatus.active.displayName, 'Active');
      expect(SubscriptionStatus.expired.displayName, 'Expired');
      expect(SubscriptionStatus.rejected.displayName, 'Rejected');
      expect(SubscriptionStatus.cancelled.displayName, 'Cancelled');
    });
  });
}
