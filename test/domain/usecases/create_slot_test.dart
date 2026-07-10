import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:pg_manager/domain/entities/custom_slot.dart';
import 'package:pg_manager/domain/failures/library_failures.dart';
import 'package:pg_manager/domain/repositories/slot_repository.dart';
import 'package:pg_manager/domain/usecases/create_slot.dart';

class MockSlotRepository extends Mock implements SlotRepository {}

void main() {
  late MockSlotRepository mockRepository;
  late CreateSlot createSlot;

  setUpAll(() {
    // Register fallback values for mocktail
    registerFallbackValue(
      const CustomSlot(
        id: 'fallback',
        libraryId: 'fallback',
        name: 'Fallback',
        startTime: 0,
        endTime: 1440,
        price: 0.0,
        capacity: 0,
      ),
    );
  });

  setUp(() {
    mockRepository = MockSlotRepository();
    createSlot = CreateSlot(slotRepository: mockRepository);
  });

  group('CreateSlot', () {
    test('should create slot successfully', () async {
      const slot = CustomSlot(
        id: 'slot1',
        libraryId: 'lib1',
        name: 'Morning',
        startTime: 360,
        endTime: 840,
        price: 500.0,
        capacity: 20,
      );

      when(
        () => mockRepository.createSlot(slot),
      ).thenAnswer((_) async => const Right(slot));

      final result = await createSlot(CreateSlotParams(slot: slot));

      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not fail'),
        (createdSlot) => expect(createdSlot, slot),
      );
      verify(() => mockRepository.createSlot(slot)).called(1);
    });

    test('should fail when slot times are invalid', () async {
      const invalidSlot = CustomSlot(
        id: 'slot1',
        libraryId: 'lib1',
        name: 'Invalid',
        startTime: 840,
        endTime: 360, // End before start
        price: 500.0,
        capacity: 20,
      );

      final result = await createSlot(CreateSlotParams(slot: invalidSlot));

      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure.message, contains('Invalid slot times')),
        (_) => fail('Should fail'),
      );
      verifyNever(() => mockRepository.createSlot(any()));
    });

    test('should allow overlapping slots (premium vs normal)', () async {
      const slot1 = CustomSlot(
        id: 'slot1',
        libraryId: 'lib1',
        name: 'Premium Morning',
        startTime: 360,
        endTime: 840,
        price: 1000.0,
        capacity: 10,
      );

      const slot2 = CustomSlot(
        id: 'slot2',
        libraryId: 'lib1',
        name: 'Normal Morning',
        startTime: 360, // Same time as slot1
        endTime: 840,
        price: 500.0,
        capacity: 20,
      );

      when(() => mockRepository.createSlot(any())).thenAnswer((
        invocation,
      ) async {
        final slot = invocation.positionalArguments[0] as CustomSlot;
        return Right(slot);
      });

      // Both slots should be created successfully even though they overlap
      final result1 = await createSlot(CreateSlotParams(slot: slot1));
      final result2 = await createSlot(CreateSlotParams(slot: slot2));

      expect(result1.isRight(), true);
      expect(result2.isRight(), true);
      verify(() => mockRepository.createSlot(slot1)).called(1);
      verify(() => mockRepository.createSlot(slot2)).called(1);
    });

    test('should propagate repository errors', () async {
      const slot = CustomSlot(
        id: 'slot1',
        libraryId: 'lib1',
        name: 'Morning',
        startTime: 360,
        endTime: 840,
        price: 500.0,
        capacity: 20,
      );

      when(() => mockRepository.createSlot(slot)).thenAnswer(
        (_) async =>
            const Left(InvalidLibraryDataFailure(message: 'Network error')),
      );

      final result = await createSlot(CreateSlotParams(slot: slot));

      expect(result.isLeft(), true);
      verify(() => mockRepository.createSlot(slot)).called(1);
    });
  });
}
