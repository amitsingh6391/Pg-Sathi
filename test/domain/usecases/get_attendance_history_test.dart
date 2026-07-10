import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/attendance.dart';
import 'package:pg_manager/domain/entities/slot.dart';
import 'package:pg_manager/domain/repositories/attendance_repository.dart';
import 'package:pg_manager/domain/usecases/get_attendance_history.dart';
import 'package:mocktail/mocktail.dart';

class MockAttendanceRepository extends Mock implements AttendanceRepository {}

void main() {
  late GetAttendanceHistory useCase;
  late MockAttendanceRepository mockRepository;

  setUp(() {
    mockRepository = MockAttendanceRepository();
    useCase = GetAttendanceHistory(attendanceRepository: mockRepository);
  });

  final testAttendances = [
    Attendance(
      id: 'att-1',
      userId: 'user-1',
      libraryId: 'lib-1',
      seatId: 'S01',
      slot: Slot.morning,
      date: '2024-12-15',
      status: AttendanceStatus.checkedOut,
      checkInTime: DateTime(2024, 12, 15, 6, 0),
      checkOutTime: DateTime(2024, 12, 15, 14, 0),
    ),
    Attendance(
      id: 'att-2',
      userId: 'user-1',
      libraryId: 'lib-1',
      seatId: 'S01',
      slot: Slot.morning,
      date: '2024-12-14',
      status: AttendanceStatus.checkedOut,
      checkInTime: DateTime(2024, 12, 14, 6, 30),
      checkOutTime: DateTime(2024, 12, 14, 13, 45),
    ),
  ];

  final testParams = GetAttendanceHistoryParams(
    userId: 'user-1',
    libraryId: 'lib-1',
    startDate: DateTime(2024, 12, 1),
    endDate: DateTime(2024, 12, 31),
  );

  group('GetAttendanceHistory', () {
    test('should return attendance history from repository', () async {
      // Arrange
      when(
        () => mockRepository.getAttendanceHistory(
          userId: any(named: 'userId'),
          libraryId: any(named: 'libraryId'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenAnswer((_) async => Right(testAttendances));

      // Act
      final result = await useCase(testParams);

      // Assert
      expect(result.isRight(), true);
      result.fold((_) => fail('Expected success'), (attendances) {
        expect(attendances.length, 2);
        expect(attendances[0].id, 'att-1');
        expect(attendances[1].id, 'att-2');
      });
    });

    test('should return empty list when no history', () async {
      // Arrange
      when(
        () => mockRepository.getAttendanceHistory(
          userId: any(named: 'userId'),
          libraryId: any(named: 'libraryId'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenAnswer((_) async => const Right([]));

      // Act
      final result = await useCase(testParams);

      // Assert
      expect(result.isRight(), true);
      result.fold((_) => fail('Expected success'), (attendances) {
        expect(attendances.isEmpty, true);
      });
    });

    test('factory lastDays should calculate correct dates', () {
      // Act
      final params = GetAttendanceHistoryParams.lastDays(
        userId: 'user-1',
        libraryId: 'lib-1',
        days: 7,
      );

      // Assert
      expect(params.userId, 'user-1');
      expect(params.libraryId, 'lib-1');
      expect(params.endDate.difference(params.startDate).inDays, 7);
    });

    test('factory currentMonth should start from first of month', () {
      // Act
      final params = GetAttendanceHistoryParams.currentMonth(
        userId: 'user-1',
        libraryId: 'lib-1',
      );

      // Assert
      expect(params.startDate.day, 1);
      expect(params.startDate.month, DateTime.now().month);
    });
  });
}
