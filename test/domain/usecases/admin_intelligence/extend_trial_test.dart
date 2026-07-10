import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:pg_manager/domain/core/core.dart';
import 'package:pg_manager/domain/entities/admin_action.dart';
import 'package:pg_manager/domain/repositories/admin_intelligence_repository.dart';
import 'package:pg_manager/domain/usecases/admin_intelligence/extend_trial.dart';
import 'package:pg_manager/data/failures/data_failures.dart';

class MockAdminIntelligenceRepository extends Mock
    implements AdminIntelligenceRepository {}

void main() {
  late ExtendTrial useCase;
  late MockAdminIntelligenceRepository mockRepository;

  setUp(() {
    mockRepository = MockAdminIntelligenceRepository();
    useCase = ExtendTrial(repository: mockRepository);
  });

  setUpAll(() {
    registerFallbackValue(
      const ExtendTrialRequest(
        libraryId: 'lib1',
        extensionDays: 3,
        reason: 'Test reason',
        adminId: 'admin1',
      ),
    );
  });

  group('ExtendTrial', () {
    const validRequest = ExtendTrialRequest(
      libraryId: 'lib1',
      extensionDays: 5,
      reason: 'Customer requested extension',
      adminId: 'admin1',
    );

    const invalidRequest = ExtendTrialRequest(
      libraryId: 'lib1',
      extensionDays: 10, // Exceeds 7 days limit
      reason: 'Too long',
      adminId: 'admin1',
    );

    test('should_extend_trial_when_days_is_valid', () async {
      // Arrange
      when(
        () => mockRepository.extendTrial(any()),
      ).thenAnswer((_) async => const Right(null));

      // Act
      final result = await useCase(validRequest);

      // Assert
      expect(result, isA<Right<Failure, void>>());
      verify(() => mockRepository.extendTrial(validRequest)).called(1);
    });

    test('should_return_validation_failure_when_days_exceeds_7', () async {
      // Act
      final result = await useCase(invalidRequest);

      // Assert
      expect(result, isA<Left<Failure, void>>());
      result.fold((failure) {
        expect(failure, isA<ValidationFailure>());
        expect(failure.message, 'Extension cannot exceed 7 days');
      }, (_) => fail('Should not succeed'));
      verifyNever(() => mockRepository.extendTrial(any()));
    });

    test('should_return_failure_when_repository_fails', () async {
      // Arrange
      when(() => mockRepository.extendTrial(any())).thenAnswer(
        (_) async => const Left(ServerFailure(message: 'Database error')),
      );

      // Act
      final result = await useCase(validRequest);

      // Assert
      expect(result, isA<Left<Failure, void>>());
      result.fold(
        (failure) => expect(failure.message, 'Database error'),
        (_) => fail('Should not succeed'),
      );
      verify(() => mockRepository.extendTrial(validRequest)).called(1);
    });

    test('should_allow_exactly_7_days_extension', () async {
      // Arrange
      const borderRequest = ExtendTrialRequest(
        libraryId: 'lib1',
        extensionDays: 7,
        reason: 'Max allowed',
        adminId: 'admin1',
      );
      when(
        () => mockRepository.extendTrial(any()),
      ).thenAnswer((_) async => const Right(null));

      // Act
      final result = await useCase(borderRequest);

      // Assert
      expect(result, isA<Right<Failure, void>>());
      verify(() => mockRepository.extendTrial(borderRequest)).called(1);
    });

    test('should_allow_1_day_extension', () async {
      // Arrange
      const minRequest = ExtendTrialRequest(
        libraryId: 'lib1',
        extensionDays: 1,
        reason: 'Minimal extension',
        adminId: 'admin1',
      );
      when(
        () => mockRepository.extendTrial(any()),
      ).thenAnswer((_) async => const Right(null));

      // Act
      final result = await useCase(minRequest);

      // Assert
      expect(result, isA<Right<Failure, void>>());
      verify(() => mockRepository.extendTrial(minRequest)).called(1);
    });
  });
}
