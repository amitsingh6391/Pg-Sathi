import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/data/repositories/seat_repository_impl.dart';

void main() {
  late SeatRepositoryImpl repository;
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repository = SeatRepositoryImpl(firestore: fakeFirestore);
  });

  group('SeatRepositoryImpl', () {
    group('createSeats', () {
      test('should create seats with sequential numbering', () async {
        final result = await repository.createSeats(
          libraryId: 'lib-1',
          count: 3,
        );

        expect(result.isRight(), true);
        result.fold((l) => fail('Should not return failure'), (r) {
          expect(r.length, 3);
          expect(r[0].seatNumber, 'S01');
          expect(r[1].seatNumber, 'S02');
          expect(r[2].seatNumber, 'S03');
          expect(r.every((s) => s.libraryId == 'lib-1'), true);
          expect(r.every((s) => s.isActive), true);
        });
      });
    });

    group('getSeatById', () {
      test('should return seat when exists', () async {
        // Create seat first
        await repository.createSeats(libraryId: 'lib-1', count: 1);

        // Get seats to find the ID
        final seatsResult = await repository.getSeatsByLibraryId('lib-1');
        final seatId = seatsResult.fold(
          (l) => throw Exception('Failed to get seats'),
          (r) => r.first.id,
        );

        final result = await repository.getSeatById(seatId);

        expect(result.isRight(), true);
        result.fold((l) => fail('Should not return failure'), (r) {
          expect(r.id, seatId);
          expect(r.libraryId, 'lib-1');
        });
      });

      test('should return failure when seat not found', () async {
        final result = await repository.getSeatById('non-existent');

        expect(result.isLeft(), true);
      });
    });

    group('getSeatsByLibraryId', () {
      test('should return all seats for a library', () async {
        await repository.createSeats(libraryId: 'lib-1', count: 5);
        await repository.createSeats(libraryId: 'lib-2', count: 3);

        final result = await repository.getSeatsByLibraryId('lib-1');

        expect(result.isRight(), true);
        result.fold((l) => fail('Should not return failure'), (r) {
          expect(r.length, 5);
          expect(r.every((s) => s.libraryId == 'lib-1'), true);
        });
      });

      test('should return empty list when no seats', () async {
        final result = await repository.getSeatsByLibraryId('lib-1');

        expect(result.isRight(), true);
        result.fold(
          (l) => fail('Should not return failure'),
          (r) => expect(r, isEmpty),
        );
      });
    });

    group('getActiveSeatsByLibraryId', () {
      test('should return only active seats', () async {
        // Create seats
        await repository.createSeats(libraryId: 'lib-1', count: 3);

        // Deactivate one seat
        final seatsResult = await repository.getSeatsByLibraryId('lib-1');
        final firstSeat = seatsResult.fold(
          (l) => throw Exception('Failed to get seats'),
          (r) => r.first,
        );

        await repository.updateSeat(firstSeat.deactivate());

        // Get active seats
        final result = await repository.getActiveSeatsByLibraryId('lib-1');

        expect(result.isRight(), true);
        result.fold((l) => fail('Should not return failure'), (r) {
          expect(r.length, 2);
          expect(r.every((s) => s.isActive), true);
        });
      });
    });

    group('updateSeat', () {
      test('should update seat properties', () async {
        await repository.createSeats(libraryId: 'lib-1', count: 1);

        final seatsResult = await repository.getSeatsByLibraryId('lib-1');
        final seat = seatsResult.fold(
          (l) => throw Exception('Failed to get seats'),
          (r) => r.first,
        );

        final updated = seat.deactivate();
        final result = await repository.updateSeat(updated);

        expect(result.isRight(), true);
        result.fold(
          (l) => fail('Should not return failure'),
          (r) => expect(r.isActive, false),
        );
      });
    });

    group('deleteSeatsForLibrary', () {
      test('should delete all seats when keepCount is null', () async {
        await repository.createSeats(libraryId: 'lib-1', count: 5);

        final result = await repository.deleteSeatsForLibrary('lib-1');

        expect(result.isRight(), true);

        final remaining = await repository.getSeatsByLibraryId('lib-1');
        remaining.fold(
          (l) => fail('Should not return failure'),
          (r) => expect(r, isEmpty),
        );
      });

      test('should keep first N seats when keepCount is provided', () async {
        await repository.createSeats(libraryId: 'lib-1', count: 5);

        final result = await repository.deleteSeatsForLibrary(
          'lib-1',
          keepCount: 2,
        );

        expect(result.isRight(), true);

        final remaining = await repository.getSeatsByLibraryId('lib-1');
        remaining.fold(
          (l) => fail('Should not return failure'),
          (r) => expect(r.length, 2),
        );
      });
    });
  });
}
