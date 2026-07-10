import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:pg_manager/domain/core/failure.dart';
import 'package:pg_manager/domain/core/usecase.dart';
import 'package:pg_manager/domain/entities/admin_dashboard_data.dart';
import 'package:pg_manager/domain/entities/admin_dashboard_stats.dart';
import 'package:pg_manager/domain/entities/library_summary.dart';
import 'package:pg_manager/domain/repositories/admin_analytics_repository.dart';
import 'package:pg_manager/domain/usecases/get_admin_dashboard_data.dart';

class MockAdminAnalyticsRepository extends Mock
    implements AdminAnalyticsRepository {}

class ServerFailure extends Failure {
  const ServerFailure({super.message});
}

void main() {
  late GetAdminDashboardData useCase;
  late MockAdminAnalyticsRepository mockRepository;

  setUp(() {
    mockRepository = MockAdminAnalyticsRepository();
    useCase = GetAdminDashboardData(repository: mockRepository);
  });

  group('GetAdminDashboardData', () {
    final tStats = AdminDashboardStats(
      totalLibraries: 50,
      librariesToday: 2,
      librariesLast7Days: 10,
      librariesLast30Days: 25,
      totalActiveStudents: 500,
      totalActiveOwners: 48,
      generatedAt: DateTime(2024, 6, 1),
    );

    final tSummaries = [
      LibrarySummary(
        libraryId: 'lib-1',
        libraryName: 'City Library',
        ownerId: 'owner-1',
        ownerName: 'John Doe',
        ownerPhone: '9876543210',
        totalSeats: 50,
        activeMemberships: 40,
        occupancyPercent: 80.0,
        createdAt: DateTime(2024, 1, 1),
        area: 'Downtown',
        subscriptionStatus: 'active',
      ),
      LibrarySummary(
        libraryId: 'lib-2',
        libraryName: 'Study Hub',
        ownerId: 'owner-2',
        ownerName: 'Jane Smith',
        ownerPhone: '9876543211',
        totalSeats: 30,
        activeMemberships: 15,
        occupancyPercent: 50.0,
        createdAt: DateTime(2024, 2, 1),
        area: 'Suburb',
        subscriptionStatus: 'pending',
      ),
    ];

    final tData = AdminDashboardData(
      stats: tStats,
      librarySummaries: tSummaries,
    );

    test('should_return_combined_dashboard_data_when_repository_succeeds',
        () async {
      when(
        () => mockRepository.getDashboardData(),
      ).thenAnswer((_) async => Right(tData));

      final result = await useCase(const NoParams());

      expect(result, Right(tData));
      verify(() => mockRepository.getDashboardData()).called(1);
      verifyNoMoreInteractions(mockRepository);
    });

    test('should_return_failure_when_repository_fails', () async {
      const tFailure = ServerFailure(message: 'Failed to get dashboard data');
      when(
        () => mockRepository.getDashboardData(),
      ).thenAnswer((_) async => const Left(tFailure));

      final result = await useCase(const NoParams());

      expect(result, const Left(tFailure));
      verify(() => mockRepository.getDashboardData()).called(1);
    });

    test('should_return_empty_summaries_when_no_libraries', () async {
      final emptyData = AdminDashboardData(
        stats: tStats,
        librarySummaries: const [],
      );
      when(
        () => mockRepository.getDashboardData(),
      ).thenAnswer((_) async => Right(emptyData));

      final result = await useCase(const NoParams());

      result.fold(
        (l) => fail('Should return right'),
        (r) => expect(r.librarySummaries, isEmpty),
      );
    });
  });

  group('AdminDashboardStats - growth calculation', () {
    test('should_calculate_library_growth_percent_correctly', () {
      final stats = AdminDashboardStats(
        totalLibraries: 50,
        librariesToday: 0,
        librariesLast7Days: 10,
        librariesLast30Days: 25,
        totalActiveStudents: 0,
        totalActiveOwners: 0,
        generatedAt: DateTime.now(),
      );

      expect(stats.libraryGrowthPercent, 100.0);
    });

    test('should_return_zero_growth_when_no_libraries', () {
      const stats = AdminDashboardStats.empty();
      expect(stats.libraryGrowthPercent, 0.0);
    });
  });

  group('LibrarySummary', () {
    test('should_format_whatsapp_phone_number_correctly', () {
      final summary = LibrarySummary(
        libraryId: 'lib-1',
        libraryName: 'Test Library',
        ownerId: 'owner-1',
        ownerName: 'Test Owner',
        ownerPhone: '9876543210',
        totalSeats: 10,
        activeMemberships: 5,
        occupancyPercent: 50.0,
        createdAt: DateTime.now(),
      );

      expect(summary.whatsappPhoneNumber, '919876543210');
      expect(summary.whatsappUrl, 'https://wa.me/919876543210');
    });

    test('should_format_occupancy_correctly', () {
      final summary = LibrarySummary(
        libraryId: 'lib-1',
        libraryName: 'Test Library',
        ownerId: 'owner-1',
        ownerName: 'Test Owner',
        ownerPhone: '9876543210',
        totalSeats: 10,
        activeMemberships: 8,
        occupancyPercent: 80.5,
        createdAt: DateTime.now(),
      );

      expect(summary.formattedOccupancy, '81%');
    });

    test('should_preserve_phone_number_with_country_code', () {
      final summary = LibrarySummary(
        libraryId: 'lib-1',
        libraryName: 'Test Library',
        ownerId: 'owner-1',
        ownerName: 'Test Owner',
        ownerPhone: '919876543210',
        totalSeats: 10,
        activeMemberships: 5,
        occupancyPercent: 50.0,
        createdAt: DateTime.now(),
      );

      expect(summary.whatsappPhoneNumber, '919876543210');
    });
  });
}
