import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/data/repositories/presence_repository_impl.dart';
import 'package:pg_manager/domain/entities/presence.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late PresenceRepositoryImpl repository;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repository = PresenceRepositoryImpl(firestore: fakeFirestore);
  });

  final now = DateTime(2024, 6, 15, 9, 30);
  final today = DateTime(2024, 6, 15);

  final testPresence = Presence(
    id: 'presence-1',
    userId: 'user-1',
    libraryId: 'lib-1',
    date: today,
    checkInTime: now,
    status: PresenceStatus.checkedIn,
    seatId: 'seat-1',
  );

  group('PresenceRepositoryImpl', () {
    group('checkIn', () {
      test('should_record_check_in_successfully', () async {
        // Act
        final result = await repository.checkIn(testPresence);

        // Assert
        expect(result.isRight(), true);
        result.fold((l) => fail('Should not return failure'), (r) {
          expect(r.id, testPresence.id);
          expect(r.userId, testPresence.userId);
          expect(r.status, PresenceStatus.checkedIn);
        });
      });
    });

    group('checkOut', () {
      test('should_record_check_out_successfully', () async {
        // Arrange
        await repository.checkIn(testPresence);
        final checkOutTime = now.add(const Duration(hours: 4));

        // Act
        final result = await repository.checkOut(
          presenceId: testPresence.id,
          checkOutTime: checkOutTime,
        );

        // Assert
        expect(result.isRight(), true);
        result.fold((l) => fail('Should not return failure'), (r) {
          expect(r.status, PresenceStatus.checkedOut);
          expect(r.checkOutTime, isNotNull);
        });
      });
    });

    group('getPresenceById', () {
      test('should_return_presence_when_exists', () async {
        // Arrange
        await repository.checkIn(testPresence);

        // Act
        final result = await repository.getPresenceById(testPresence.id);

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (l) => fail('Should not return failure'),
          (r) => expect(r.id, testPresence.id),
        );
      });

      test('should_return_failure_when_presence_not_found', () async {
        // Act
        final result = await repository.getPresenceById('non-existent');

        // Assert
        expect(result.isLeft(), true);
      });
    });

    group('getTodayPresenceByUserAndLibrary', () {
      test('should_return_today_presence', () async {
        // Arrange
        await repository.checkIn(testPresence);

        // Act
        final result = await repository.getTodayPresenceByUserAndLibrary(
          userId: testPresence.userId,
          libraryId: testPresence.libraryId,
          date: today,
        );

        // Assert
        expect(result.isRight(), true);
        result.fold((l) => fail('Should not return failure'), (r) {
          expect(r, isNotNull);
          expect(r!.userId, testPresence.userId);
        });
      });

      test('should_return_null_when_no_presence_today', () async {
        // Act
        final result = await repository.getTodayPresenceByUserAndLibrary(
          userId: 'user-1',
          libraryId: 'lib-1',
          date: today,
        );

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (l) => fail('Should not return failure'),
          (r) => expect(r, isNull),
        );
      });
    });

    group('getPresenceHistoryByUserId', () {
      test('should_return_presence_history_in_date_range', () async {
        // Arrange
        await repository.checkIn(testPresence);
        await repository.checkIn(
          testPresence.copyWith(
            id: 'presence-2',
            date: today.subtract(const Duration(days: 1)),
            checkInTime: now.subtract(const Duration(days: 1)),
          ),
        );

        // Act
        final result = await repository.getPresenceHistoryByUserId(
          userId: 'user-1',
          startDate: today.subtract(const Duration(days: 5)),
          endDate: today.add(const Duration(days: 1)),
        );

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (l) => fail('Should not return failure'),
          (r) => expect(r.length, 2),
        );
      });
    });

    group('getPresenceByLibraryAndDate', () {
      test('should_return_all_presence_for_library_on_date', () async {
        // Arrange
        await repository.checkIn(testPresence);
        await repository.checkIn(
          testPresence.copyWith(id: 'presence-2', userId: 'user-2'),
        );

        // Act
        final result = await repository.getPresenceByLibraryAndDate(
          libraryId: 'lib-1',
          date: today,
        );

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (l) => fail('Should not return failure'),
          (r) => expect(r.length, 2),
        );
      });
    });

    group('hasActivePresence', () {
      test('should_return_true_when_user_is_checked_in', () async {
        // Arrange
        await repository.checkIn(testPresence);

        // Act
        final result = await repository.hasActivePresence(
          userId: testPresence.userId,
          libraryId: testPresence.libraryId,
          date: today,
        );

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (l) => fail('Should not return failure'),
          (r) => expect(r, true),
        );
      });

      test('should_return_false_when_user_has_checked_out', () async {
        // Arrange
        await repository.checkIn(testPresence);
        await repository.checkOut(
          presenceId: testPresence.id,
          checkOutTime: now.add(const Duration(hours: 1)),
        );

        // Act
        final result = await repository.hasActivePresence(
          userId: testPresence.userId,
          libraryId: testPresence.libraryId,
          date: today,
        );

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (l) => fail('Should not return failure'),
          (r) => expect(r, false),
        );
      });
    });
  });
}
