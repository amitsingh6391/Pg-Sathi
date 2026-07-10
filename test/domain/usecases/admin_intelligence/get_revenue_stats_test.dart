import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:pg_manager/domain/core/core.dart';
import 'package:pg_manager/domain/entities/revenue_stats.dart';
import 'package:pg_manager/domain/repositories/admin_intelligence_repository.dart';
import 'package:pg_manager/domain/usecases/admin_intelligence/get_revenue_stats.dart';
import 'package:pg_manager/data/failures/data_failures.dart';

class MockAdminIntelligenceRepository extends Mock
    implements AdminIntelligenceRepository {}

void main() {
  late GetRevenueStats useCase;
  late MockAdminIntelligenceRepository mockRepository;

  setUp(() {
    mockRepository = MockAdminIntelligenceRepository();
    useCase = GetRevenueStats(repository: mockRepository);
  });

  group('GetRevenueStats', () {
    final testStats = RevenueStats(
      todayRevenue: 5000,
      weekRevenue: 25000,
      monthRevenue: 100000,
      lifetimeRevenue: 500000,
      planWiseBreakdown: const [
        PlanRevenueBreakdown(
          planId: 'plan1',
          planName: 'Basic',
          revenue: 300000,
          subscriptionCount: 30,
        ),
        PlanRevenueBreakdown(
          planId: 'plan2',
          planName: 'Premium',
          revenue: 200000,
          subscriptionCount: 10,
        ),
      ],
      seatSlabBreakdown: const [
        SeatSlabBreakdown(
          slabLabel: '1-20',
          minSeats: 1,
          maxSeats: 20,
          revenue: 100000,
          libraryCount: 15,
        ),
        SeatSlabBreakdown(
          slabLabel: '21-50',
          minSeats: 21,
          maxSeats: 50,
          revenue: 200000,
          libraryCount: 10,
        ),
      ],
      freeTrialLibraries: 5,
      paidLibraries: 40,
      activeSubscriptions: 35,
      churnedLibraries: 5,
      thisMonthSubscriptions: 8,
      lastMonthSubscriptions: 6,
      monthlySubscriptionData: const [],
      upcomingRenewals: const UpcomingRenewals.empty(),
      failedRenewals: const [],
      revenueAtRisk: 15000,
      generatedAt: DateTime.now(),
    );

    test('should_return_revenue_stats_when_repository_succeeds', () async {
      // Arrange
      when(
        () => mockRepository.getRevenueStats(),
      ).thenAnswer((_) async => Right(testStats));

      // Act
      final result = await useCase(NoParams());

      // Assert
      expect(result, isA<Right<Failure, RevenueStats>>());
      result.fold((failure) => fail('Should not return failure'), (stats) {
        expect(stats.lifetimeRevenue, 500000);
        expect(stats.todayRevenue, 5000);
        expect(stats.paidLibraries, 40);
        expect(stats.freeTrialLibraries, 5);
        expect(stats.totalLibraries, 45);
        expect(stats.planWiseBreakdown.length, 2);
      });
      verify(() => mockRepository.getRevenueStats()).called(1);
    });

    test('should_return_failure_when_repository_fails', () async {
      // Arrange
      when(() => mockRepository.getRevenueStats()).thenAnswer(
        (_) async => const Left(ServerFailure(message: 'Database error')),
      );

      // Act
      final result = await useCase(NoParams());

      // Assert
      expect(result, isA<Left<Failure, RevenueStats>>());
      result.fold(
        (failure) => expect(failure.message, 'Database error'),
        (stats) => fail('Should not return stats'),
      );
      verify(() => mockRepository.getRevenueStats()).called(1);
    });

    test('conversion_rate_should_be_calculated_correctly', () {
      // Arrange
      final stats = testStats;

      // Assert
      expect(stats.conversionRate.round(), 89); // 40/45 * 100 ≈ 88.89
    });

    test('total_libraries_should_sum_trial_and_paid', () {
      // Arrange
      final stats = testStats;

      // Assert
      expect(
        stats.totalLibraries,
        stats.freeTrialLibraries + stats.paidLibraries,
      );
    });
  });
}
