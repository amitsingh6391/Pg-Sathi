import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/attendance.dart';
import 'package:pg_manager/domain/entities/slot.dart';
import 'package:pg_manager/domain/repositories/attendance_repository.dart';
import 'package:pg_manager/domain/usecases/get_attendance_stats.dart';
import 'package:mocktail/mocktail.dart';

class MockAttendanceRepository extends Mock implements AttendanceRepository {}

void main() {
  late GetAttendanceStats useCase;
  late MockAttendanceRepository mockRepository;

  setUp(() {
    mockRepository = MockAttendanceRepository();
    useCase = GetAttendanceStats(attendanceRepository: mockRepository);
  });

  // Generate test attendances for the last 7 days
  List<Attendance> generateTestAttendances() {
    final now = DateTime.now();
    final attendances = <Attendance>[];

    for (var i = 0; i < 5; i++) {
      final date = now.subtract(Duration(days: i));
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      attendances.add(
        Attendance(
          id: 'att-$i',
          userId: 'user-1',
          libraryId: 'lib-1',
          seatId: 'S01',
          slot: Slot.morning,
          date: dateStr,
          status: AttendanceStatus.checkedOut,
          checkInTime: DateTime(date.year, date.month, date.day, 6, 0),
          checkOutTime: DateTime(
            date.year,
            date.month,
            date.day,
            12,
            0,
          ), // 6 hours
        ),
      );
    }

    return attendances;
  }

  final testParams = GetAttendanceStatsParams(
    userId: 'user-1',
    libraryId: 'lib-1',
  );

  group('GetAttendanceStats', () {
    test('should calculate stats correctly', () async {
      // Arrange
      final attendances = generateTestAttendances();
      when(
        () => mockRepository.getAttendanceForPeriod(
          userId: any(named: 'userId'),
          libraryId: any(named: 'libraryId'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenAnswer((_) async => Right(attendances));

      // Act
      final result = await useCase(testParams);

      // Assert
      expect(result.isRight(), true);
      result.fold((_) => fail('Expected success'), (stats) {
        expect(stats.userId, 'user-1');
        expect(stats.libraryId, 'lib-1');
        expect(stats.presentDays, 5);
        expect(stats.totalMinutes, 5 * 6 * 60); // 5 days * 6 hours * 60 min
        expect(stats.averageMinutesPerDay, 360.0); // 6 hours
        expect(stats.dailyStats.isNotEmpty, true);
        expect(stats.weeklyStats.isNotEmpty, true);
      });
    });

    test('should return empty stats when no attendance', () async {
      // Arrange
      when(
        () => mockRepository.getAttendanceForPeriod(
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
      result.fold((_) => fail('Expected success'), (stats) {
        expect(stats.presentDays, 0);
        expect(stats.totalMinutes, 0);
        expect(stats.averageMinutesPerDay, 0);
      });
    });

    test('should calculate daily stats for last 7 days', () async {
      // Arrange
      final attendances = generateTestAttendances();
      when(
        () => mockRepository.getAttendanceForPeriod(
          userId: any(named: 'userId'),
          libraryId: any(named: 'libraryId'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenAnswer((_) async => Right(attendances));

      // Act
      final result = await useCase(testParams);

      // Assert
      expect(result.isRight(), true);
      result.fold((_) => fail('Expected success'), (stats) {
        expect(stats.dailyStats.length, 7);
        // Check that some days have duration and some don't
        final presentDays = stats.dailyStats.where((d) => d.isPresent).length;
        expect(presentDays, greaterThan(0));
      });
    });

    test('should calculate weekly stats for last 4 weeks', () async {
      // Arrange
      final attendances = generateTestAttendances();
      when(
        () => mockRepository.getAttendanceForPeriod(
          userId: any(named: 'userId'),
          libraryId: any(named: 'libraryId'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenAnswer((_) async => Right(attendances));

      // Act
      final result = await useCase(testParams);

      // Assert
      expect(result.isRight(), true);
      result.fold((_) => fail('Expected success'), (stats) {
        expect(stats.weeklyStats.length, 4);
        // The last item should be "This Week"
        expect(stats.weeklyStats.last.weekLabel, 'This Week');
      });
    });

    test('should calculate streaks correctly', () async {
      // Arrange - 3 consecutive days
      final now = DateTime.now();
      final attendances = [
        Attendance(
          id: 'att-1',
          userId: 'user-1',
          libraryId: 'lib-1',
          seatId: 'S01',
          slot: Slot.morning,
          date:
              '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
          status: AttendanceStatus.checkedOut,
          checkInTime: DateTime(now.year, now.month, now.day, 6, 0),
          checkOutTime: DateTime(now.year, now.month, now.day, 12, 0),
        ),
        Attendance(
          id: 'att-2',
          userId: 'user-1',
          libraryId: 'lib-1',
          seatId: 'S01',
          slot: Slot.morning,
          date:
              '${now.subtract(const Duration(days: 1)).year}-${now.subtract(const Duration(days: 1)).month.toString().padLeft(2, '0')}-${now.subtract(const Duration(days: 1)).day.toString().padLeft(2, '0')}',
          status: AttendanceStatus.checkedOut,
          checkInTime: DateTime(now.year, now.month, now.day - 1, 6, 0),
          checkOutTime: DateTime(now.year, now.month, now.day - 1, 12, 0),
        ),
        Attendance(
          id: 'att-3',
          userId: 'user-1',
          libraryId: 'lib-1',
          seatId: 'S01',
          slot: Slot.morning,
          date:
              '${now.subtract(const Duration(days: 2)).year}-${now.subtract(const Duration(days: 2)).month.toString().padLeft(2, '0')}-${now.subtract(const Duration(days: 2)).day.toString().padLeft(2, '0')}',
          status: AttendanceStatus.checkedOut,
          checkInTime: DateTime(now.year, now.month, now.day - 2, 6, 0),
          checkOutTime: DateTime(now.year, now.month, now.day - 2, 12, 0),
        ),
      ];

      when(
        () => mockRepository.getAttendanceForPeriod(
          userId: any(named: 'userId'),
          libraryId: any(named: 'libraryId'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenAnswer((_) async => Right(attendances));

      // Act
      final result = await useCase(testParams);

      // Assert
      expect(result.isRight(), true);
      result.fold((_) => fail('Expected success'), (stats) {
        expect(stats.currentStreak, 3);
        expect(stats.longestStreak, 3);
      });
    });
  });
}
