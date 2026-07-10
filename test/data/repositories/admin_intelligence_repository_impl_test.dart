import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/data/repositories/admin_intelligence_repository_impl.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late AdminIntelligenceRepositoryImpl repository;
  late DateTime now;
  late DateTime todayStart;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = AdminIntelligenceRepositoryImpl(firestore: firestore);
    now = DateTime.now();
    todayStart = DateTime(now.year, now.month, now.day);
  });

  Future<void> seedSubscription({
    required String id,
    required String libraryId,
    required String status,
    required double finalAmount,
    required DateTime approvedAt,
    DateTime? endDate,
    bool isAdminBypassed = false,
    int durationInMonths = 1,
    String planId = 'plan_basic',
    String planName = 'Basic',
    int seatCount = 30,
    double? baseMonthlyPrice,
  }) {
    return firestore.collection('subscriptions').doc(id).set({
      'libraryId': libraryId,
      'status': status,
      'finalAmount': finalAmount,
      'approvedAt': Timestamp.fromDate(approvedAt),
      'createdAt': Timestamp.fromDate(approvedAt),
      'endDate': Timestamp.fromDate(
        endDate ??
            DateTime(
              approvedAt.year,
              approvedAt.month + durationInMonths,
              approvedAt.day,
            ),
      ),
      'planId': planId,
      'planName': planName,
      'seatCount': seatCount,
      'durationInMonths': durationInMonths,
      'isAdminBypassed': isAdminBypassed,
      if (baseMonthlyPrice != null) 'baseMonthlyPrice': baseMonthlyPrice,
    });
  }

  DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

  group('getRevenueStats \u2014 dailyRevenueData (last 7 days)', () {
    test(
      'should_return_seven_zero_buckets_when_no_subscriptions_exist',
      () async {
        final result = await repository.getRevenueStats();

        final stats = result.getOrElse(() => throw StateError('left'));
        expect(stats.dailyRevenueData.length, 7);
        expect(stats.dailyRevenueData.every((p) => p.revenue == 0.0), isTrue);
        expect(stats.dailyRevenueData.last.date, todayStart);
      },
    );

    test(
      'should_bucket_payment_into_correct_calendar_day_when_paid_yesterday',
      () async {
        final yesterday = todayStart.subtract(const Duration(days: 1));
        await seedSubscription(
          id: 'sub_paid_yest',
          libraryId: 'lib_1',
          status: 'active',
          finalAmount: 499,
          approvedAt: yesterday.add(const Duration(hours: 14, minutes: 23)),
        );

        final result = await repository.getRevenueStats();
        final stats = result.getOrElse(() => throw StateError('left'));

        final yesterdayBucket =
            stats.dailyRevenueData.firstWhere((p) => p.date == yesterday);
        final todayBucket =
            stats.dailyRevenueData.firstWhere((p) => p.date == todayStart);
        expect(yesterdayBucket.revenue, 499);
        expect(todayBucket.revenue, 0);
      },
    );

    test(
      'should_keep_zero_for_days_without_payments_when_other_days_have_revenue',
      () async {
        final threeDaysAgo = todayStart.subtract(const Duration(days: 3));
        await seedSubscription(
          id: 'sub_3d',
          libraryId: 'lib_1',
          status: 'active',
          finalAmount: 199,
          approvedAt: threeDaysAgo.add(const Duration(hours: 10)),
        );

        final result = await repository.getRevenueStats();
        final stats = result.getOrElse(() => throw StateError('left'));

        final nonZero =
            stats.dailyRevenueData.where((p) => p.revenue > 0).toList();
        expect(nonZero.length, 1);
        expect(nonZero.first.date, threeDaysAgo);
        expect(nonZero.first.revenue, 199);
      },
    );

    test(
      'should_exclude_bypassed_subscriptions_from_daily_buckets',
      () async {
        final yesterday = todayStart.subtract(const Duration(days: 1));
        await seedSubscription(
          id: 'sub_bypass',
          libraryId: 'lib_1',
          status: 'active',
          finalAmount: 199,
          approvedAt: yesterday.add(const Duration(hours: 9)),
          isAdminBypassed: true,
        );

        final result = await repository.getRevenueStats();
        final stats = result.getOrElse(() => throw StateError('left'));

        expect(stats.dailyRevenueData.every((p) => p.revenue == 0.0), isTrue);
      },
    );

    test(
      'should_sum_multiple_payments_within_same_day',
      () async {
        await seedSubscription(
          id: 'sub_morning',
          libraryId: 'lib_1',
          status: 'active',
          finalAmount: 199,
          approvedAt: todayStart.add(const Duration(hours: 9)),
        );
        await seedSubscription(
          id: 'sub_afternoon',
          libraryId: 'lib_2',
          status: 'active',
          finalAmount: 499,
          approvedAt: todayStart.add(const Duration(hours: 15)),
        );

        final result = await repository.getRevenueStats();
        final stats = result.getOrElse(() => throw StateError('left'));

        final todayBucket =
            stats.dailyRevenueData.firstWhere((p) => p.date == todayStart);
        expect(todayBucket.revenue, 698);
      },
    );

    test(
      'should_ignore_payments_outside_seven_day_window',
      () async {
        final tenDaysAgo = todayStart.subtract(const Duration(days: 10));
        await seedSubscription(
          id: 'sub_old',
          libraryId: 'lib_1',
          status: 'active',
          finalAmount: 999,
          approvedAt: tenDaysAgo.add(const Duration(hours: 12)),
        );

        final result = await repository.getRevenueStats();
        final stats = result.getOrElse(() => throw StateError('left'));

        expect(stats.dailyRevenueData.every((p) => p.revenue == 0.0), isTrue);
      },
    );
  });

  group('getRevenueStats \u2014 mrr (Monthly Recurring Revenue)', () {
    test('should_be_zero_when_no_active_subscriptions_exist', () async {
      final result = await repository.getRevenueStats();
      final stats = result.getOrElse(() => throw StateError('left'));
      expect(stats.mrr, 0);
    });

    test(
      'should_count_full_amount_when_active_sub_is_one_month_plan',
      () async {
        await seedSubscription(
          id: 'sub_monthly',
          libraryId: 'lib_1',
          status: 'active',
          finalAmount: 199,
          approvedAt: todayStart,
          endDate: now.add(const Duration(days: 30)),
          durationInMonths: 1,
        );

        final result = await repository.getRevenueStats();
        final stats = result.getOrElse(() => throw StateError('left'));
        expect(stats.mrr, 199);
      },
    );

    test(
      'should_normalise_quarterly_plan_to_monthly_in_mrr',
      () async {
        await seedSubscription(
          id: 'sub_q',
          libraryId: 'lib_1',
          status: 'active',
          finalAmount: 597,
          approvedAt: todayStart,
          endDate: now.add(const Duration(days: 90)),
          durationInMonths: 3,
        );

        final result = await repository.getRevenueStats();
        final stats = result.getOrElse(() => throw StateError('left'));
        expect(stats.mrr, 199);
      },
    );

    test(
      'should_normalise_yearly_plan_to_monthly_in_mrr',
      () async {
        await seedSubscription(
          id: 'sub_y',
          libraryId: 'lib_1',
          status: 'active',
          finalAmount: 1200,
          approvedAt: todayStart,
          endDate: now.add(const Duration(days: 365)),
          durationInMonths: 12,
        );

        final result = await repository.getRevenueStats();
        final stats = result.getOrElse(() => throw StateError('left'));
        expect(stats.mrr, 100);
      },
    );

    test(
      'should_exclude_admin_bypassed_subscriptions_from_mrr',
      () async {
        await seedSubscription(
          id: 'sub_bypass',
          libraryId: 'lib_1',
          status: 'active',
          finalAmount: 199,
          approvedAt: todayStart,
          endDate: now.add(const Duration(days: 365)),
          durationInMonths: 12,
          isAdminBypassed: true,
        );

        final result = await repository.getRevenueStats();
        final stats = result.getOrElse(() => throw StateError('left'));
        expect(stats.mrr, 0);
      },
    );

    test(
      'should_exclude_expired_subscriptions_from_mrr',
      () async {
        await seedSubscription(
          id: 'sub_expired',
          libraryId: 'lib_1',
          status: 'active',
          finalAmount: 199,
          approvedAt: todayStart.subtract(const Duration(days: 60)),
          endDate: todayStart.subtract(const Duration(days: 1)),
          durationInMonths: 1,
        );

        final result = await repository.getRevenueStats();
        final stats = result.getOrElse(() => throw StateError('left'));
        expect(stats.mrr, 0);
      },
    );

    test(
      'should_sum_mrr_across_mixed_active_subs_excluding_bypassed',
      () async {
        await seedSubscription(
          id: 'a',
          libraryId: 'lib_a',
          status: 'active',
          finalAmount: 199,
          approvedAt: todayStart,
          endDate: now.add(const Duration(days: 30)),
          durationInMonths: 1,
        );
        await seedSubscription(
          id: 'b',
          libraryId: 'lib_b',
          status: 'active',
          finalAmount: 1200,
          approvedAt: todayStart,
          endDate: now.add(const Duration(days: 365)),
          durationInMonths: 12,
        );
        await seedSubscription(
          id: 'c',
          libraryId: 'lib_c',
          status: 'active',
          finalAmount: 999,
          approvedAt: todayStart,
          endDate: now.add(const Duration(days: 365)),
          durationInMonths: 12,
          isAdminBypassed: true,
        );

        final result = await repository.getRevenueStats();
        final stats = result.getOrElse(() => throw StateError('left'));
        expect(stats.mrr, 299);
      },
    );

    test(
      'should_treat_missing_or_zero_durationInMonths_as_one_to_avoid_div_by_zero',
      () async {
        await firestore.collection('subscriptions').doc('legacy').set({
          'libraryId': 'lib_1',
          'status': 'active',
          'finalAmount': 199,
          'approvedAt': Timestamp.fromDate(todayStart),
          'createdAt': Timestamp.fromDate(todayStart),
          'endDate':
              Timestamp.fromDate(now.add(const Duration(days: 30))),
          'planId': 'plan_legacy',
          'planName': 'Legacy',
          'seatCount': 10,
        });

        final result = await repository.getRevenueStats();
        final stats = result.getOrElse(() => throw StateError('left'));
        expect(stats.mrr, 199);
      },
    );
  });

  group('getRevenueStats \u2014 listPriceMrr (renewal run-rate)', () {
    test(
      'should_use_baseMonthlyPrice_ignoring_coupon_discount_in_finalAmount',
      () async {
        await seedSubscription(
          id: 'sub_couponed',
          libraryId: 'lib_1',
          status: 'active',
          finalAmount: 75,
          approvedAt: todayStart,
          endDate: now.add(const Duration(days: 30)),
          durationInMonths: 1,
          baseMonthlyPrice: 149,
          seatCount: 30,
        );

        final result = await repository.getRevenueStats();
        final stats = result.getOrElse(() => throw StateError('left'));
        expect(stats.mrr, 75);
        expect(stats.listPriceMrr, 149);
      },
    );

    test(
      'should_use_baseMonthlyPrice_ignoring_yearly_duration_discount',
      () async {
        // Yearly: \u20B9149\u00D712 = \u20B91788, minus 5% duration discount = \u20B91698.60.
        await seedSubscription(
          id: 'sub_yearly',
          libraryId: 'lib_1',
          status: 'active',
          finalAmount: 1698.60,
          approvedAt: todayStart,
          endDate: now.add(const Duration(days: 365)),
          durationInMonths: 12,
          baseMonthlyPrice: 149,
          seatCount: 30,
        );

        final result = await repository.getRevenueStats();
        final stats = result.getOrElse(() => throw StateError('left'));
        expect(stats.mrr, closeTo(141.55, 0.01));
        expect(stats.listPriceMrr, 149);
      },
    );

    test(
      'should_fallback_to_seat_tier_lookup_when_baseMonthlyPrice_missing',
      () async {
        // seatCount 80 \u2192 tier_249.
        await seedSubscription(
          id: 'sub_legacy',
          libraryId: 'lib_1',
          status: 'active',
          finalAmount: 200,
          approvedAt: todayStart,
          endDate: now.add(const Duration(days: 30)),
          durationInMonths: 1,
          seatCount: 80,
        );

        final result = await repository.getRevenueStats();
        final stats = result.getOrElse(() => throw StateError('left'));
        expect(stats.listPriceMrr, 249);
      },
    );

    test(
      'should_exclude_bypassed_subscriptions_from_listPriceMrr',
      () async {
        await seedSubscription(
          id: 'sub_bypass',
          libraryId: 'lib_1',
          status: 'active',
          finalAmount: 199,
          approvedAt: todayStart,
          endDate: now.add(const Duration(days: 365)),
          durationInMonths: 12,
          isAdminBypassed: true,
          baseMonthlyPrice: 149,
        );

        final result = await repository.getRevenueStats();
        final stats = result.getOrElse(() => throw StateError('left'));
        expect(stats.listPriceMrr, 0);
      },
    );

    test(
      'should_exclude_expired_subscriptions_from_listPriceMrr',
      () async {
        await seedSubscription(
          id: 'sub_expired',
          libraryId: 'lib_1',
          status: 'active',
          finalAmount: 149,
          approvedAt: todayStart.subtract(const Duration(days: 60)),
          endDate: todayStart.subtract(const Duration(days: 1)),
          durationInMonths: 1,
          baseMonthlyPrice: 149,
        );

        final result = await repository.getRevenueStats();
        final stats = result.getOrElse(() => throw StateError('left'));
        expect(stats.listPriceMrr, 0);
      },
    );

    test(
      'should_sum_listPriceMrr_across_mixed_active_subs',
      () async {
        await seedSubscription(
          id: 'a',
          libraryId: 'lib_a',
          status: 'active',
          finalAmount: 75,
          approvedAt: todayStart,
          endDate: now.add(const Duration(days: 30)),
          durationInMonths: 1,
          baseMonthlyPrice: 149,
        );
        await seedSubscription(
          id: 'b',
          libraryId: 'lib_b',
          status: 'active',
          finalAmount: 2839.20,
          approvedAt: todayStart,
          endDate: now.add(const Duration(days: 365)),
          durationInMonths: 12,
          baseMonthlyPrice: 249,
        );
        await seedSubscription(
          id: 'c',
          libraryId: 'lib_c',
          status: 'active',
          finalAmount: 1000,
          approvedAt: todayStart,
          endDate: now.add(const Duration(days: 90)),
          durationInMonths: 3,
          seatCount: 200,
        );
        await seedSubscription(
          id: 'd',
          libraryId: 'lib_d',
          status: 'active',
          finalAmount: 199,
          approvedAt: todayStart,
          endDate: now.add(const Duration(days: 30)),
          durationInMonths: 1,
          isAdminBypassed: true,
          baseMonthlyPrice: 149,
        );

        final result = await repository.getRevenueStats();
        final stats = result.getOrElse(() => throw StateError('left'));
        // \u20B9149 + \u20B9249 + \u20B9399 (tier for 200 seats) + \u20B90 (bypass).
        expect(stats.listPriceMrr, 797);
      },
    );

    test(
      'should_treat_zero_or_negative_baseMonthlyPrice_as_missing_and_fallback',
      () async {
        await seedSubscription(
          id: 'sub_zero_base',
          libraryId: 'lib_1',
          status: 'active',
          finalAmount: 149,
          approvedAt: todayStart,
          endDate: now.add(const Duration(days: 30)),
          durationInMonths: 1,
          baseMonthlyPrice: 0,
          seatCount: 30,
        );

        final result = await repository.getRevenueStats();
        final stats = result.getOrElse(() => throw StateError('left'));
        expect(stats.listPriceMrr, 149);
      },
    );
  });

  group(
      'getRevenueStats \u2014 regression: existing buckets unchanged',
      () {
    test(
      'should_still_count_paid_today_revenue_in_today_bucket',
      () async {
        await seedSubscription(
          id: 'sub_today',
          libraryId: 'lib_1',
          status: 'active',
          finalAmount: 199,
          approvedAt: todayStart.add(const Duration(hours: 12)),
        );

        final result = await repository.getRevenueStats();
        final stats = result.getOrElse(() => throw StateError('left'));
        expect(stats.todayRevenue, 199);
        expect(stats.lifetimeRevenue, 199);
        expect(stats.activeSubscriptions, 1);
        final todayBucket =
            stats.dailyRevenueData.firstWhere((p) => p.date == dayOf(todayStart));
        expect(todayBucket.revenue, 199);
        expect(stats.mrr, 199);
      },
    );
  });
}
