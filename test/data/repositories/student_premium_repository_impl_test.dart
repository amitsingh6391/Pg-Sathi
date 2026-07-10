import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/data/repositories/student_premium_repository_impl.dart';
import 'package:pg_manager/domain/entities/student_premium_subscription.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late StudentPremiumRepositoryImpl repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = StudentPremiumRepositoryImpl(firestore: firestore);
  });

  group('StudentPremiumRepositoryImpl', () {
    group('getActiveSubscription', () {
      test(
        'should_return_null_when_no_subscription_exists_for_user',
        () async {
          final result = await repository.getActiveSubscription('u1');

          expect(result.isRight(), true);
          result.fold(
            (_) => fail('unexpected failure'),
            (sub) => expect(sub, isNull),
          );
        },
      );

      test(
        'should_return_active_subscription_when_flag_true_and_valid_till_future',
        () async {
          final now = DateTime.now();
          await firestore
              .collection('studentPremiumSubscriptions')
              .doc('sub1')
              .set({
            'userId': 'u1',
            'plan': 'monthly',
            'amountPaise': 4900,
            'startedAt': Timestamp.fromDate(now),
            'validTill': Timestamp.fromDate(now.add(const Duration(days: 10))),
            'isActive': true,
            'createdAt': Timestamp.fromDate(now),
          });

          final result = await repository.getActiveSubscription('u1');

          expect(result.isRight(), true);
          result.fold(
            (_) => fail('unexpected failure'),
            (sub) {
              expect(sub, isNotNull);
              expect(sub!.id, 'sub1');
              expect(sub.isCurrentlyActive, true);
            },
          );
        },
      );

      test(
        'should_return_null_when_flag_active_but_valid_till_in_past',
        () async {
          final now = DateTime.now();
          await firestore
              .collection('studentPremiumSubscriptions')
              .doc('expired')
              .set({
            'userId': 'u1',
            'plan': 'monthly',
            'amountPaise': 4900,
            'startedAt':
                Timestamp.fromDate(now.subtract(const Duration(days: 40))),
            'validTill':
                Timestamp.fromDate(now.subtract(const Duration(days: 1))),
            'isActive': true,
            'createdAt':
                Timestamp.fromDate(now.subtract(const Duration(days: 40))),
          });

          final result = await repository.getActiveSubscription('u1');

          result.fold(
            (_) => fail('unexpected failure'),
            (sub) => expect(sub, isNull),
          );
        },
      );

      test('should_not_return_other_users_subscription', () async {
        final now = DateTime.now();
        await firestore
            .collection('studentPremiumSubscriptions')
            .doc('other')
            .set({
          'userId': 'someone_else',
          'plan': 'monthly',
          'amountPaise': 4900,
          'startedAt': Timestamp.fromDate(now),
          'validTill': Timestamp.fromDate(now.add(const Duration(days: 30))),
          'isActive': true,
          'createdAt': Timestamp.fromDate(now),
        });

        final result = await repository.getActiveSubscription('u1');

        result.fold(
          (_) => fail('unexpected failure'),
          (sub) => expect(sub, isNull),
        );
      });
    });

    group('activateSubscription', () {
      test(
        'should_create_subscription_with_validTill_based_on_plan_duration',
        () async {
          final before = DateTime.now();
          final result = await repository.activateSubscription(
            userId: 'u1',
            plan: StudentPremiumPlan.monthly,
            amountPaise: 4900,
            paymentId: 'pay_1',
            paymentProvider: 'razorpay',
          );

          expect(result.isRight(), true);
          result.fold(
            (_) => fail('unexpected failure'),
            (sub) {
              expect(sub.id, 'pay_1');
              expect(sub.userId, 'u1');
              expect(sub.plan, StudentPremiumPlan.monthly);
              expect(sub.amountPaise, 4900);
              expect(sub.isActive, true);
              expect(sub.paymentId, 'pay_1');
              expect(sub.paymentProvider, 'razorpay');
              // Should be ~30 days in the future.
              final days = sub.validTill.difference(before).inDays;
              expect(days, inInclusiveRange(29, 30));
            },
          );
        },
      );

      test(
        'should_return_existing_subscription_when_payment_id_already_used',
        () async {
          final first = await repository.activateSubscription(
            userId: 'u1',
            plan: StudentPremiumPlan.monthly,
            amountPaise: 4900,
            paymentId: 'pay_dup',
            paymentProvider: 'razorpay',
          );

          final second = await repository.activateSubscription(
            userId: 'u1',
            plan: StudentPremiumPlan.yearly,
            amountPaise: 39900,
            paymentId: 'pay_dup',
            paymentProvider: 'razorpay',
          );

          expect(first.isRight(), true);
          expect(second.isRight(), true);

          final firstSub = first.getOrElse(() => throw 'a');
          final secondSub = second.getOrElse(() => throw 'b');

          // Idempotent: second call returns the first row unchanged.
          expect(secondSub.id, firstSub.id);
          expect(secondSub.plan, firstSub.plan);
          expect(secondSub.amountPaise, firstSub.amountPaise);
        },
      );

      test(
        'should_extend_validity_from_existing_when_user_already_active',
        () async {
          // Seed an active subscription with 10 days remaining.
          final now = DateTime.now();
          final existingValidTill = now.add(const Duration(days: 10));
          await firestore
              .collection('studentPremiumSubscriptions')
              .doc('seed')
              .set({
            'userId': 'u1',
            'plan': 'monthly',
            'amountPaise': 4900,
            'startedAt':
                Timestamp.fromDate(now.subtract(const Duration(days: 20))),
            'validTill': Timestamp.fromDate(existingValidTill),
            'isActive': true,
            'createdAt':
                Timestamp.fromDate(now.subtract(const Duration(days: 20))),
          });

          final result = await repository.activateSubscription(
            userId: 'u1',
            plan: StudentPremiumPlan.monthly,
            amountPaise: 4900,
            paymentId: 'pay_extend',
            paymentProvider: 'razorpay',
          );

          result.fold(
            (_) => fail('unexpected failure'),
            (sub) {
              // New validTill should be ~30 days from the existing end date,
              // not from "now". Total window therefore ≥ 39 days from now.
              final diff = sub.validTill.difference(now).inDays;
              expect(diff, greaterThanOrEqualTo(39));
            },
          );
        },
      );
    });

    group('cancelSubscription', () {
      test('should_flip_isActive_false_and_set_cancelledAt', () async {
        final now = DateTime.now();
        await firestore
            .collection('studentPremiumSubscriptions')
            .doc('sub1')
            .set({
          'userId': 'u1',
          'plan': 'monthly',
          'amountPaise': 4900,
          'startedAt': Timestamp.fromDate(now),
          'validTill': Timestamp.fromDate(now.add(const Duration(days: 30))),
          'isActive': true,
          'createdAt': Timestamp.fromDate(now),
        });

        final result = await repository.cancelSubscription('sub1');

        expect(result.isRight(), true);
        final updated = await firestore
            .collection('studentPremiumSubscriptions')
            .doc('sub1')
            .get();
        expect(updated.data()?['isActive'], false);
        expect(updated.data()?['cancelledAt'], isNotNull);
      });

      test('should_return_failure_when_subscription_id_missing', () async {
        final result = await repository.cancelSubscription('does_not_exist');

        // fake_cloud_firestore rejects updates to missing docs. Our repo
        // wraps that into a ServerFailure.
        expect(result.isLeft(), true);
      });
    });

    group('getAllSubscriptions', () {
      test('should_return_items_ordered_by_createdAt_desc', () async {
        final base = DateTime(2025, 1, 1);
        for (var i = 0; i < 3; i++) {
          await firestore
              .collection('studentPremiumSubscriptions')
              .doc('s$i')
              .set({
            'userId': 'u$i',
            'plan': 'monthly',
            'amountPaise': 4900,
            'startedAt': Timestamp.fromDate(base),
            'validTill': Timestamp.fromDate(
              base.add(const Duration(days: 30)),
            ),
            'isActive': true,
            'createdAt': Timestamp.fromDate(base.add(Duration(days: i))),
          });
        }

        final result = await repository.getAllSubscriptions();

        result.fold(
          (_) => fail('unexpected failure'),
          (items) {
            expect(items.length, 3);
            expect(items.first.id, 's2');
            expect(items.last.id, 's0');
          },
        );
      });
    });
  });
}
