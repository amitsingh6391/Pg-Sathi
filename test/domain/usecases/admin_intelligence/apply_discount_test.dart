import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:pg_manager/domain/core/core.dart';
import 'package:pg_manager/domain/entities/admin_action.dart';
import 'package:pg_manager/domain/repositories/admin_intelligence_repository.dart';
import 'package:pg_manager/domain/usecases/admin_intelligence/apply_discount.dart';
import 'package:pg_manager/data/failures/data_failures.dart';

class MockAdminIntelligenceRepository extends Mock
    implements AdminIntelligenceRepository {}

void main() {
  late ApplyDiscount useCase;
  late MockAdminIntelligenceRepository mockRepository;

  setUp(() {
    mockRepository = MockAdminIntelligenceRepository();
    useCase = ApplyDiscount(repository: mockRepository);
  });

  setUpAll(() {
    registerFallbackValue(
      ApplyDiscountRequest(
        libraryId: 'lib1',
        discountPercent: 10,
        validUntil: DateTime.now().add(const Duration(days: 30)),
        reason: 'Test',
        adminId: 'admin1',
      ),
    );
  });

  group('ApplyDiscount', () {
    final validRequest = ApplyDiscountRequest(
      libraryId: 'lib1',
      discountPercent: 20,
      validUntil: DateTime.now().add(const Duration(days: 30)),
      reason: 'Retention offer',
      adminId: 'admin1',
    );

    test('should_apply_discount_when_percentage_is_valid', () async {
      // Arrange
      when(
        () => mockRepository.applyDiscount(any()),
      ).thenAnswer((_) async => const Right(null));

      // Act
      final result = await useCase(validRequest);

      // Assert
      expect(result, isA<Right<Failure, void>>());
      verify(() => mockRepository.applyDiscount(validRequest)).called(1);
    });

    test(
      'should_return_validation_failure_when_discount_exceeds_100',
      () async {
        // Arrange
        final invalidRequest = ApplyDiscountRequest(
          libraryId: 'lib1',
          discountPercent: 150,
          validUntil: DateTime.now().add(const Duration(days: 30)),
          reason: 'Too high',
          adminId: 'admin1',
        );

        // Act
        final result = await useCase(invalidRequest);

        // Assert
        expect(result, isA<Left<Failure, void>>());
        result.fold((failure) {
          expect(failure, isA<ValidationFailure>());
          expect(failure.message, 'Discount must be between 0-100%');
        }, (_) => fail('Should not succeed'));
        verifyNever(() => mockRepository.applyDiscount(any()));
      },
    );

    test(
      'should_return_validation_failure_when_discount_is_negative',
      () async {
        // Arrange
        final invalidRequest = ApplyDiscountRequest(
          libraryId: 'lib1',
          discountPercent: -10,
          validUntil: DateTime.now().add(const Duration(days: 30)),
          reason: 'Negative',
          adminId: 'admin1',
        );

        // Act
        final result = await useCase(invalidRequest);

        // Assert
        expect(result, isA<Left<Failure, void>>());
        result.fold((failure) {
          expect(failure, isA<ValidationFailure>());
          expect(failure.message, 'Discount must be between 0-100%');
        }, (_) => fail('Should not succeed'));
        verifyNever(() => mockRepository.applyDiscount(any()));
      },
    );

    test('should_allow_0_percent_discount', () async {
      // Arrange
      final zeroRequest = ApplyDiscountRequest(
        libraryId: 'lib1',
        discountPercent: 0,
        validUntil: DateTime.now().add(const Duration(days: 30)),
        reason: 'Remove discount',
        adminId: 'admin1',
      );
      when(
        () => mockRepository.applyDiscount(any()),
      ).thenAnswer((_) async => const Right(null));

      // Act
      final result = await useCase(zeroRequest);

      // Assert
      expect(result, isA<Right<Failure, void>>());
      verify(() => mockRepository.applyDiscount(zeroRequest)).called(1);
    });

    test('should_allow_100_percent_discount', () async {
      // Arrange
      final fullRequest = ApplyDiscountRequest(
        libraryId: 'lib1',
        discountPercent: 100,
        validUntil: DateTime.now().add(const Duration(days: 30)),
        reason: 'Full discount',
        adminId: 'admin1',
      );
      when(
        () => mockRepository.applyDiscount(any()),
      ).thenAnswer((_) async => const Right(null));

      // Act
      final result = await useCase(fullRequest);

      // Assert
      expect(result, isA<Right<Failure, void>>());
      verify(() => mockRepository.applyDiscount(fullRequest)).called(1);
    });

    test('should_return_failure_when_repository_fails', () async {
      // Arrange
      when(() => mockRepository.applyDiscount(any())).thenAnswer(
        (_) async => const Left(ServerFailure(message: 'Failed to apply')),
      );

      // Act
      final result = await useCase(validRequest);

      // Assert
      expect(result, isA<Left<Failure, void>>());
      result.fold(
        (failure) => expect(failure.message, 'Failed to apply'),
        (_) => fail('Should not succeed'),
      );
    });
  });
}
