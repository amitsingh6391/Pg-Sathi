import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/library.dart';
import 'package:pg_manager/domain/entities/seat.dart';
import 'package:pg_manager/domain/failures/library_failures.dart';
import 'package:pg_manager/domain/repositories/library_repository.dart';
import 'package:pg_manager/domain/repositories/seat_repository.dart';
import 'package:pg_manager/domain/usecases/create_library.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'create_library_test.mocks.dart';

@GenerateMocks([LibraryRepository, SeatRepository])
void main() {
  late CreateLibrary useCase;
  late MockLibraryRepository mockLibraryRepo;
  late MockSeatRepository mockSeatRepo;

  setUp(() {
    mockLibraryRepo = MockLibraryRepository();
    mockSeatRepo = MockSeatRepository();
    useCase = CreateLibrary(
      libraryRepository: mockLibraryRepo,
      seatRepository: mockSeatRepo,
    );
  });

  const ownerId = 'owner-123';
  const libraryId = 'library-123';
  const name = 'Test Library';
  const fullAddress = 'Test Full Address';
  const area = 'Test Area';
  const capacity = 50;

  final testLibrary = Library(
    id: libraryId,
    ownerId: ownerId,
    name: name,
    fullAddress: fullAddress,
    area: area,
    capacity: capacity,
  );

  group('CreateLibrary', () {
    group('validation', () {
      test('should_return_failure_when_name_is_empty', () async {
        final invalidLibrary = testLibrary.copyWith(name: '');
        final result = await useCase(
          CreateLibraryParams(library: invalidLibrary),
        );

        expect(result.isLeft(), true);
        result.fold(
          (l) => expect(l, isA<InvalidLibraryDataFailure>()),
          (r) => fail('Should return failure'),
        );
        verifyNever(mockLibraryRepo.ownerHasLibrary(any));
      });

      test('should_return_failure_when_name_is_too_short', () async {
        final invalidLibrary = testLibrary.copyWith(name: 'AB');
        final result = await useCase(
          CreateLibraryParams(library: invalidLibrary),
        );

        expect(result.isLeft(), true);
        result.fold(
          (l) => expect(l.message, contains('at least 3 characters')),
          (r) => fail('Should return failure'),
        );
      });

      test('should_return_failure_when_area_is_empty', () async {
        final invalidLibrary = Library(
          id: libraryId,
          ownerId: ownerId,
          name: name,
          fullAddress: fullAddress,
          area: '',
          capacity: capacity,
        );
        final result = await useCase(
          CreateLibraryParams(library: invalidLibrary),
        );

        expect(result.isLeft(), true);
        result.fold(
          (l) => expect(l.message, contains('Area is required')),
          (r) => fail('Should return failure'),
        );
      });

      test('should_return_failure_when_capacity_is_zero', () async {
        final invalidLibrary = testLibrary.copyWith(capacity: 0);
        final result = await useCase(
          CreateLibraryParams(library: invalidLibrary),
        );

        expect(result.isLeft(), true);
        result.fold(
          (l) => expect(l.message, contains('greater than 0')),
          (r) => fail('Should return failure'),
        );
      });
    });

    group('business rules', () {
      test('should_return_failure_when_owner_already_has_library', () async {
        when(
          mockLibraryRepo.ownerHasLibrary(any),
        ).thenAnswer((_) async => const Right(true));

        final result = await useCase(CreateLibraryParams(library: testLibrary));

        expect(result.isLeft(), true);
        result.fold(
          (l) => expect(l, isA<LibraryAlreadyExistsFailure>()),
          (r) => fail('Should return failure'),
        );
        verifyNever(mockLibraryRepo.createLibrary(any));
      });

      test(
        'should_create_library_and_seats_when_owner_has_no_library',
        () async {
          when(
            mockLibraryRepo.ownerHasLibrary(any),
          ).thenAnswer((_) async => const Right(false));
          when(
            mockLibraryRepo.createLibrary(any),
          ).thenAnswer((_) async => Right(testLibrary));
          when(
            mockSeatRepo.createSeats(
              libraryId: anyNamed('libraryId'),
              count: anyNamed('count'),
            ),
          ).thenAnswer((_) async => const Right(<Seat>[]));

          final result = await useCase(
            CreateLibraryParams(library: testLibrary),
          );

          expect(result.isRight(), true);
          result.fold(
            (l) => fail('Should not return failure'),
            (r) => expect(r.name, name),
          );
          verify(mockLibraryRepo.createLibrary(any)).called(1);
          verify(
            mockSeatRepo.createSeats(libraryId: libraryId, count: capacity),
          ).called(1);
        },
      );
    });
  });

  group('CreateLibraryParams', () {
    test('should_have_correct_props', () {
      final params = CreateLibraryParams(library: testLibrary);
      expect(params.props, [testLibrary]);
    });
  });
}
