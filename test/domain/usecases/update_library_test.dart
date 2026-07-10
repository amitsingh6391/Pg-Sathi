import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/library.dart';
import 'package:pg_manager/domain/entities/seat.dart';
import 'package:pg_manager/domain/failures/library_failures.dart';
import 'package:pg_manager/domain/repositories/library_repository.dart';
import 'package:pg_manager/domain/repositories/seat_repository.dart';
import 'package:pg_manager/domain/usecases/update_library.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'update_library_test.mocks.dart';

@GenerateMocks([LibraryRepository, SeatRepository])
void main() {
  late UpdateLibrary useCase;
  late MockLibraryRepository mockLibraryRepo;
  late MockSeatRepository mockSeatRepo;

  setUp(() {
    mockLibraryRepo = MockLibraryRepository();
    mockSeatRepo = MockSeatRepository();
    useCase = UpdateLibrary(
      libraryRepository: mockLibraryRepo,
      seatRepository: mockSeatRepo,
    );
  });

  const ownerId = 'owner-123';

  final testLibrary = Library(
    id: 'library-123',
    ownerId: ownerId,
    name: 'Test Library',
    fullAddress: 'Test Full Address',
    area: 'Test Area',
    capacity: 50,
  );

  group('UpdateLibrary', () {
    group('validation', () {
      test('should_return_failure_when_name_is_empty', () async {
        final invalidLibrary = testLibrary.copyWith(name: '');
        final result = await useCase(
          UpdateLibraryParams(library: invalidLibrary),
        );

        expect(result.isLeft(), true);
        result.fold(
          (l) => expect(l, isA<InvalidLibraryDataFailure>()),
          (r) => fail('Should return failure'),
        );
      });
    });

    group('business rules', () {
      test('should_return_failure_when_library_not_found', () async {
        when(
          mockLibraryRepo.getLibraryByOwnerId(any),
        ).thenAnswer((_) async => const Right(null));

        final result = await useCase(
          UpdateLibraryParams(
            library: testLibrary.copyWith(name: 'Updated Name'),
          ),
        );

        expect(result.isLeft(), true);
        result.fold(
          (l) => expect(l, isA<LibraryNotFoundFailure>()),
          (r) => fail('Should return failure'),
        );
      });

      test('should_update_library_successfully', () async {
        when(
          mockLibraryRepo.getLibraryByOwnerId(any),
        ).thenAnswer((_) async => Right(testLibrary));
        when(
          mockLibraryRepo.updateLibrary(any),
        ).thenAnswer((inv) async => Right(inv.positionalArguments[0]));

        final updatedLibrary = testLibrary.copyWith(name: 'Updated Name');
        final result = await useCase(
          UpdateLibraryParams(library: updatedLibrary),
        );

        expect(result.isRight(), true);
        result.fold(
          (l) => fail('Should not return failure'),
          (r) => expect(r.name, 'Updated Name'),
        );
      });

      test('should_sync_seats_when_capacity_increases', () async {
        when(
          mockLibraryRepo.getLibraryByOwnerId(any),
        ).thenAnswer((_) async => Right(testLibrary));
        when(
          mockLibraryRepo.updateLibrary(any),
        ).thenAnswer((inv) async => Right(inv.positionalArguments[0]));
        when(mockSeatRepo.getSeatsByLibraryId(any)).thenAnswer(
          (_) async => Right(
            List.generate(
              50,
              (i) => Seat(
                id: 'seat-$i',
                libraryId: testLibrary.id,
                seatNumber: 'S${i + 1}',
              ),
            ),
          ),
        );
        when(
          mockSeatRepo.createSeats(
            libraryId: anyNamed('libraryId'),
            count: anyNamed('count'),
          ),
        ).thenAnswer((_) async => const Right(<Seat>[]));

        final updatedLibrary = testLibrary.copyWith(capacity: 60);
        final result = await useCase(
          UpdateLibraryParams(library: updatedLibrary),
        );

        expect(result.isRight(), true);
        verify(
          mockSeatRepo.createSeats(
            libraryId: testLibrary.id,
            count: 10, // 60 - 50 = 10 new seats
          ),
        ).called(1);
      });
    });
  });
}
