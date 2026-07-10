import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/attendance.dart';
import 'package:pg_manager/domain/entities/slot.dart';
import 'package:pg_manager/domain/repositories/attendance_repository.dart';
import 'package:pg_manager/domain/usecases/mark_owner_attendance.dart';
import 'package:mocktail/mocktail.dart';

class MockAttendanceRepository extends Mock implements AttendanceRepository {}

void main() {
  late MarkOwnerAttendance useCase;
  late MockAttendanceRepository mockRepository;

  setUpAll(() {
    // Register fallback values for all types used with `any()`
    registerFallbackValue(Slot.morning);
    registerFallbackValue(
      Attendance(
        id: '',
        userId: '',
        libraryId: '',
        seatId: '',
        slot: Slot.morning,
        date: '',
        status: AttendanceStatus.none,
      ),
    );
    registerFallbackValue(AttendanceAction.checkIn);
  });

  setUp(() {
    mockRepository = MockAttendanceRepository();
    useCase = MarkOwnerAttendance(attendanceRepository: mockRepository);
  });

  group('MarkOwnerAttendance', () {
    const libraryId = 'library123';
    const studentId = 'student123';
    const seatId = 'S01';
    const slot = Slot.morning;

    group('date validation', () {
      test('should_return_failure_when_date_is_in_future', () async {
        // Arrange
        final futureDate = DateTime.now().add(const Duration(days: 1));
        final params = MarkOwnerAttendanceParams(
          libraryId: libraryId,
          studentId: studentId,
          seatId: seatId,
          slot: slot,
          date: futureDate,
          action: AttendanceAction.checkIn,
        );

        // Act
        final result = await useCase(params);

        // Assert
        expect(result.isLeft(), true);
        result.fold(
          (failure) => expect(
            failure.message,
            'Cannot mark attendance for future dates',
          ),
          (_) => fail('Expected failure'),
        );
        // Should not call repository for future dates
        verifyNever(
          () => mockRepository.getTodayAttendance(
            userId: any(named: 'userId'),
            libraryId: any(named: 'libraryId'),
            slot: any(named: 'slot'),
            date: any(named: 'date'),
          ),
        );
      });

      test('should_return_failure_when_date_is_older_than_7_days', () async {
        // Arrange
        final oldDate = DateTime.now().subtract(const Duration(days: 10));
        final params = MarkOwnerAttendanceParams(
          libraryId: libraryId,
          studentId: studentId,
          seatId: seatId,
          slot: slot,
          date: oldDate,
          action: AttendanceAction.checkIn,
        );

        // Act
        final result = await useCase(params);

        // Assert
        expect(result.isLeft(), true);
        result.fold(
          (failure) => expect(
            failure.message,
            'Cannot edit attendance older than ${MarkOwnerAttendance.maxEditDaysInPast} days',
          ),
          (_) => fail('Expected failure'),
        );
      });

      test('should_accept_date_within_7_days', () async {
        // Arrange
        final validDate = DateTime.now().subtract(const Duration(days: 3));
        final params = MarkOwnerAttendanceParams(
          libraryId: libraryId,
          studentId: studentId,
          seatId: seatId,
          slot: slot,
          date: validDate,
          action: AttendanceAction.checkIn,
        );

        when(
          () => mockRepository.getTodayAttendance(
            userId: any(named: 'userId'),
            libraryId: any(named: 'libraryId'),
            slot: any(named: 'slot'),
            date: any(named: 'date'),
          ),
        ).thenAnswer((_) async => const Right(null));

        when(
          () => mockRepository.checkIn(any()),
        ).thenAnswer((inv) async => Right(inv.positionalArguments[0]));

        // Act
        final result = await useCase(params);

        // Assert
        expect(result.isRight(), true);
      });
    });

    group('check in', () {
      test(
        'should_create_new_attendance_when_checking_in_with_no_existing_record',
        () async {
          // Arrange
          final today = DateTime.now();
          final params = MarkOwnerAttendanceParams(
            libraryId: libraryId,
            studentId: studentId,
            seatId: seatId,
            slot: slot,
            date: today,
            action: AttendanceAction.checkIn,
          );

          when(
            () => mockRepository.getTodayAttendance(
              userId: any(named: 'userId'),
              libraryId: any(named: 'libraryId'),
              slot: any(named: 'slot'),
              date: any(named: 'date'),
            ),
          ).thenAnswer((_) async => const Right(null));

          when(() => mockRepository.checkIn(any())).thenAnswer((
            invocation,
          ) async {
            final attendance = invocation.positionalArguments[0] as Attendance;
            return Right(attendance);
          });

          // Act
          final result = await useCase(params);

          // Assert
          expect(result.isRight(), true);
          result.fold((_) => fail('Expected success'), (attendance) {
            expect(attendance.userId, studentId);
            expect(attendance.libraryId, libraryId);
            expect(attendance.status, AttendanceStatus.checkedIn);
          });
          verify(() => mockRepository.checkIn(any())).called(1);
        },
      );

      test(
        'should_add_new_session_when_checking_in_with_completed_session',
        () async {
          // Arrange
          final today = DateTime.now();
          final params = MarkOwnerAttendanceParams(
            libraryId: libraryId,
            studentId: studentId,
            seatId: seatId,
            slot: slot,
            date: today,
            action: AttendanceAction.checkIn,
          );

          final existingAttendance = Attendance(
            id: 'existing123',
            userId: studentId,
            libraryId: libraryId,
            seatId: seatId,
            slot: slot,
            date: '2024-01-01',
            status: AttendanceStatus.checkedOut,
          );

          when(
            () => mockRepository.getTodayAttendance(
              userId: any(named: 'userId'),
              libraryId: any(named: 'libraryId'),
              slot: any(named: 'slot'),
              date: any(named: 'date'),
            ),
          ).thenAnswer((_) async => Right(existingAttendance));

          when(
            () => mockRepository.addSession(
              attendanceId: any(named: 'attendanceId'),
              sessionId: any(named: 'sessionId'),
              distanceFromLibrary: any(named: 'distanceFromLibrary'),
            ),
          ).thenAnswer(
            (_) async => Right(
              existingAttendance.copyWith(status: AttendanceStatus.checkedIn),
            ),
          );

          // Act
          final result = await useCase(params);

          // Assert
          expect(result.isRight(), true);
          verify(
            () => mockRepository.addSession(
              attendanceId: any(named: 'attendanceId'),
              sessionId: any(named: 'sessionId'),
              distanceFromLibrary: any(named: 'distanceFromLibrary'),
            ),
          ).called(1);
        },
      );
    });

    group('check out', () {
      test(
        'should_complete_session_when_checking_out_with_active_session',
        () async {
          // Arrange
          final today = DateTime.now();
          final params = MarkOwnerAttendanceParams(
            libraryId: libraryId,
            studentId: studentId,
            seatId: seatId,
            slot: slot,
            date: today,
            action: AttendanceAction.checkOut,
          );

          final existingAttendance = Attendance(
            id: 'existing123',
            userId: studentId,
            libraryId: libraryId,
            seatId: seatId,
            slot: slot,
            date: '2024-01-01',
            status: AttendanceStatus.checkedIn,
            checkInTime: DateTime.now().subtract(const Duration(hours: 2)),
          );

          when(
            () => mockRepository.getTodayAttendance(
              userId: any(named: 'userId'),
              libraryId: any(named: 'libraryId'),
              slot: any(named: 'slot'),
              date: any(named: 'date'),
            ),
          ).thenAnswer((_) async => Right(existingAttendance));

          when(
            () => mockRepository.checkOut(
              attendanceId: any(named: 'attendanceId'),
              distanceFromLibrary: any(named: 'distanceFromLibrary'),
            ),
          ).thenAnswer(
            (_) async => Right(
              existingAttendance.copyWith(status: AttendanceStatus.checkedOut),
            ),
          );

          // Act
          final result = await useCase(params);

          // Assert
          expect(result.isRight(), true);
          verify(
            () => mockRepository.checkOut(
              attendanceId: any(named: 'attendanceId'),
              distanceFromLibrary: any(named: 'distanceFromLibrary'),
            ),
          ).called(1);
        },
      );

      test(
        'should_return_failure_when_checking_out_with_no_attendance',
        () async {
          // Arrange
          final today = DateTime.now();
          final params = MarkOwnerAttendanceParams(
            libraryId: libraryId,
            studentId: studentId,
            seatId: seatId,
            slot: slot,
            date: today,
            action: AttendanceAction.checkOut,
          );

          when(
            () => mockRepository.getTodayAttendance(
              userId: any(named: 'userId'),
              libraryId: any(named: 'libraryId'),
              slot: any(named: 'slot'),
              date: any(named: 'date'),
            ),
          ).thenAnswer((_) async => const Right(null));

          // Act
          final result = await useCase(params);

          // Assert
          expect(result.isLeft(), true);
          result.fold(
            (failure) =>
                expect(failure.message, 'Student has not checked in yet'),
            (_) => fail('Expected failure'),
          );
        },
      );
    });

    group('mark absent', () {
      test(
        'should_delete_attendance_when_marking_absent_with_existing_record',
        () async {
          // Arrange
          final today = DateTime.now();
          final params = MarkOwnerAttendanceParams(
            libraryId: libraryId,
            studentId: studentId,
            seatId: seatId,
            slot: slot,
            date: today,
            action: AttendanceAction.markAbsent,
          );

          final existingAttendance = Attendance(
            id: 'existing123',
            userId: studentId,
            libraryId: libraryId,
            seatId: seatId,
            slot: slot,
            date: '2024-01-01',
            status: AttendanceStatus.checkedOut,
          );

          when(
            () => mockRepository.getTodayAttendance(
              userId: any(named: 'userId'),
              libraryId: any(named: 'libraryId'),
              slot: any(named: 'slot'),
              date: any(named: 'date'),
            ),
          ).thenAnswer((_) async => Right(existingAttendance));

          when(
            () => mockRepository.deleteAttendance(
              attendanceId: any(named: 'attendanceId'),
            ),
          ).thenAnswer((_) async => const Right(null));

          // Act
          final result = await useCase(params);

          // Assert
          expect(result.isRight(), true);
          result.fold(
            (_) => fail('Expected success'),
            (attendance) => expect(attendance.status, AttendanceStatus.none),
          );
          verify(
            () => mockRepository.deleteAttendance(attendanceId: 'existing123'),
          ).called(1);
        },
      );

      test(
        'should_return_none_status_attendance_when_no_existing_record_to_delete',
        () async {
          // Arrange
          final today = DateTime.now();
          final params = MarkOwnerAttendanceParams(
            libraryId: libraryId,
            studentId: studentId,
            seatId: seatId,
            slot: slot,
            date: today,
            action: AttendanceAction.markAbsent,
          );

          when(
            () => mockRepository.getTodayAttendance(
              userId: any(named: 'userId'),
              libraryId: any(named: 'libraryId'),
              slot: any(named: 'slot'),
              date: any(named: 'date'),
            ),
          ).thenAnswer((_) async => const Right(null));

          // Act
          final result = await useCase(params);

          // Assert
          expect(result.isRight(), true);
          result.fold((_) => fail('Expected success'), (attendance) {
            expect(attendance.status, AttendanceStatus.none);
            expect(attendance.userId, studentId);
          });
          verifyNever(
            () => mockRepository.deleteAttendance(
              attendanceId: any(named: 'attendanceId'),
            ),
          );
        },
      );
    });

    group('edge cases', () {
      test('should_handle_boundary_date_of_exactly_7_days', () async {
        // Arrange
        final boundaryDate = DateTime.now().subtract(const Duration(days: 7));
        final params = MarkOwnerAttendanceParams(
          libraryId: libraryId,
          studentId: studentId,
          seatId: seatId,
          slot: slot,
          date: boundaryDate,
          action: AttendanceAction.checkIn,
        );

        when(
          () => mockRepository.getTodayAttendance(
            userId: any(named: 'userId'),
            libraryId: any(named: 'libraryId'),
            slot: any(named: 'slot'),
            date: any(named: 'date'),
          ),
        ).thenAnswer((_) async => const Right(null));

        when(
          () => mockRepository.checkIn(any()),
        ).thenAnswer((inv) async => Right(inv.positionalArguments[0]));

        // Act
        final result = await useCase(params);

        // Assert
        expect(result.isRight(), true);
      });

      test('should_handle_today_date', () async {
        // Arrange
        final today = DateTime.now();
        final params = MarkOwnerAttendanceParams(
          libraryId: libraryId,
          studentId: studentId,
          seatId: seatId,
          slot: slot,
          date: today,
          action: AttendanceAction.checkIn,
        );

        when(
          () => mockRepository.getTodayAttendance(
            userId: any(named: 'userId'),
            libraryId: any(named: 'libraryId'),
            slot: any(named: 'slot'),
            date: any(named: 'date'),
          ),
        ).thenAnswer((_) async => const Right(null));

        when(
          () => mockRepository.checkIn(any()),
        ).thenAnswer((inv) async => Right(inv.positionalArguments[0]));

        // Act
        final result = await useCase(params);

        // Assert
        expect(result.isRight(), true);
      });
    });
  });
}
