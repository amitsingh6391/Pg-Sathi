import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:pg_manager/domain/core/core.dart';
import 'package:pg_manager/domain/entities/churn_data.dart';
import 'package:pg_manager/domain/repositories/admin_intelligence_repository.dart';
import 'package:pg_manager/domain/usecases/admin_intelligence/get_churn_data.dart';
import 'package:pg_manager/data/failures/data_failures.dart';

class MockAdminIntelligenceRepository extends Mock
    implements AdminIntelligenceRepository {}

void main() {
  late GetChurnData useCase;
  late MockAdminIntelligenceRepository mockRepository;

  setUp(() {
    mockRepository = MockAdminIntelligenceRepository();
    useCase = GetChurnData(repository: mockRepository);
  });

  group('GetChurnData', () {
    final testChurnData = ChurnData(
      inactiveLibraries: InactiveLibraries(
        inactive7Days: [
          AtRiskLibrary(
            libraryId: 'lib1',
            libraryName: 'Test Library 1',
            ownerId: 'owner1',
            ownerName: 'Owner 1',
            ownerPhone: '9876543210',
            retentionScore: RetentionScore.medium,
            riskReasons: [RiskReason.inactive7Days],
            lastActivityDate: DateTime.now().subtract(const Duration(days: 8)),
            subscriptionEndDate: DateTime.now().add(const Duration(days: 20)),
            monthlyRevenue: 5000,
            daysInactive: 8,
          ),
        ],
        inactive14Days: [],
        inactive30Days: [],
      ),
      trialExpiredUnpaid: [
        AtRiskLibrary(
          libraryId: 'lib2',
          libraryName: 'Test Library 2',
          ownerId: 'owner2',
          ownerName: 'Owner 2',
          ownerPhone: '9876543211',
          retentionScore: RetentionScore.low,
          riskReasons: [RiskReason.trialExpired],
          lastActivityDate: DateTime.now().subtract(const Duration(days: 5)),
          subscriptionEndDate: null,
          monthlyRevenue: 0,
          trialEndDate: DateTime.now().subtract(const Duration(days: 3)),
        ),
      ],
      lowUsageLibraries: [],
      generatedAt: DateTime.now(),
    );

    test('should_return_churn_data_when_repository_succeeds', () async {
      // Arrange
      when(
        () => mockRepository.getChurnData(),
      ).thenAnswer((_) async => Right(testChurnData));

      // Act
      final result = await useCase(NoParams());

      // Assert
      expect(result, isA<Right<Failure, ChurnData>>());
      result.fold((failure) => fail('Should not return failure'), (data) {
        expect(data.inactiveLibraries.inactive7Days.length, 1);
        expect(data.trialExpiredUnpaid.length, 1);
        expect(data.totalAtRisk, 2);
      });
      verify(() => mockRepository.getChurnData()).called(1);
    });

    test('should_return_failure_when_repository_fails', () async {
      // Arrange
      when(() => mockRepository.getChurnData()).thenAnswer(
        (_) async =>
            const Left(ServerFailure(message: 'Failed to fetch churn data')),
      );

      // Act
      final result = await useCase(NoParams());

      // Assert
      expect(result, isA<Left<Failure, ChurnData>>());
      result.fold(
        (failure) => expect(failure.message, 'Failed to fetch churn data'),
        (data) => fail('Should not return data'),
      );
      verify(() => mockRepository.getChurnData()).called(1);
    });

    test('retention_score_should_have_correct_labels', () {
      expect(RetentionScore.high.label, 'High');
      expect(RetentionScore.medium.label, 'Medium');
      expect(RetentionScore.low.label, 'Low');
    });

    test('risk_reason_should_have_correct_labels', () {
      expect(RiskReason.inactive7Days.label, 'Inactive 7+ days');
      expect(RiskReason.trialExpired.label, 'Trial expired');
      expect(RiskReason.lowUsage.label, 'Low usage');
      expect(RiskReason.paymentFailed.label, 'Payment failed');
    });

    test('whatsapp_url_should_be_formatted_correctly', () {
      // Arrange
      final library = testChurnData.inactiveLibraries.inactive7Days.first;

      // Assert
      expect(library.whatsappUrl, contains('wa.me'));
      expect(library.whatsappUrl, contains('9876543210'));
    });
  });
}
