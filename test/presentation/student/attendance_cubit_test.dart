import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/attendance.dart';
import 'package:pg_manager/domain/entities/slot.dart';
import 'package:pg_manager/domain/failures/attendance_failures.dart';
import 'package:pg_manager/domain/usecases/check_in.dart';
import 'package:pg_manager/domain/usecases/check_out.dart';
import 'package:pg_manager/domain/usecases/get_today_attendance.dart';
import 'package:pg_manager/presentation/student/cubit/attendance_cubit.dart';
import 'package:mocktail/mocktail.dart';

class MockCheckIn extends Mock implements CheckIn {}

class MockCheckOut extends Mock implements CheckOut {}

class MockGetTodayAttendance extends Mock implements GetTodayAttendance {}

void main() {
  late AttendanceCubit cubit;
  late MockCheckIn mockCheckIn;
  late MockCheckOut mockCheckOut;
  late MockGetTodayAttendance mockGetTodayAttendance;

  setUpAll(() {
    registerFallbackValue(
      CheckInParams(
        attendanceId: 'test',
        userId: 'test',
        libraryId: 'test',
        slot: Slot.morning,
        checkInTime: DateTime.now(),
      ),
    );
    registerFallbackValue(
      CheckOutParams(
        userId: 'test',
        libraryId: 'test',
        slot: Slot.morning,
        checkOutTime: DateTime.now(),
      ),
    );
    registerFallbackValue(
      GetTodayAttendanceParams(
        userId: 'test',
        libraryId: 'test',
        slot: Slot.morning,
        date: DateTime.now(),
      ),
    );
  });

  setUp(() {
    mockCheckIn = MockCheckIn();
    mockCheckOut = MockCheckOut();
    mockGetTodayAttendance = MockGetTodayAttendance();

    cubit = AttendanceCubit(
      checkInUseCase: mockCheckIn,
      checkOutUseCase: mockCheckOut,
      getTodayAttendanceUseCase: mockGetTodayAttendance,
    );
  });

  tearDown(() {
    cubit.close();
  });

  final testAttendanceCheckedIn = Attendance(
    id: 'attendance-1',
    userId: 'user-1',
    libraryId: 'library-1',
    seatId: 'S01',
    slot: Slot.morning,
    date: '2024-01-15',
    status: AttendanceStatus.checkedIn,
    checkInTime: DateTime.now(),
    checkInDistance: 45.0,
  );

  final testAttendanceCheckedOut = testAttendanceCheckedIn.checkOut(
    distanceFromLibrary: 50.0,
  );

  group('AttendanceCubit', () {
    group('initial state', () {
      test('should have correct initial state', () {
        expect(cubit.state.status, AttendanceStatus.none);
        expect(cubit.state.attendance, isNull);
        expect(cubit.state.isLoading, isFalse);
        expect(cubit.state.hasError, isFalse);
        expect(cubit.state.canCheckIn, isTrue);
        expect(cubit.state.canCheckOut, isFalse);
      });
    });

    group('loadTodayAttendance', () {
      blocTest<AttendanceCubit, AttendanceState>(
        'emits loading then status=none when no attendance exists',
        build: () {
          when(
            () => mockGetTodayAttendance(any()),
          ).thenAnswer((_) async => const Right(null));
          return cubit;
        },
        act: (cubit) => cubit.loadTodayAttendance(
          userId: 'user-1',
          libraryId: 'library-1',
          slot: Slot.morning,
        ),
        expect: () => [
          predicate<AttendanceState>((s) => s.isLoading && !s.hasError),
          predicate<AttendanceState>(
            (s) =>
                !s.isLoading &&
                s.status == AttendanceStatus.none &&
                s.attendance == null,
          ),
        ],
      );

      blocTest<AttendanceCubit, AttendanceState>(
        'emits loading then checkedIn status when attendance exists',
        build: () {
          when(
            () => mockGetTodayAttendance(any()),
          ).thenAnswer((_) async => Right(testAttendanceCheckedIn));
          return cubit;
        },
        act: (cubit) => cubit.loadTodayAttendance(
          userId: 'user-1',
          libraryId: 'library-1',
          slot: Slot.morning,
        ),
        expect: () => [
          predicate<AttendanceState>((s) => s.isLoading),
          predicate<AttendanceState>(
            (s) =>
                !s.isLoading &&
                s.status == AttendanceStatus.checkedIn &&
                s.attendance != null,
          ),
        ],
      );

      blocTest<AttendanceCubit, AttendanceState>(
        'emits loading then checkedOut status when attendance is checked out',
        build: () {
          when(
            () => mockGetTodayAttendance(any()),
          ).thenAnswer((_) async => Right(testAttendanceCheckedOut));
          return cubit;
        },
        act: (cubit) => cubit.loadTodayAttendance(
          userId: 'user-1',
          libraryId: 'library-1',
          slot: Slot.morning,
        ),
        expect: () => [
          predicate<AttendanceState>((s) => s.isLoading),
          predicate<AttendanceState>(
            (s) =>
                !s.isLoading &&
                s.status == AttendanceStatus.checkedOut &&
                s.attendance != null,
          ),
        ],
      );
    });

    group('checkIn', () {
      blocTest<AttendanceCubit, AttendanceState>(
        'emits error when already checked in (has active session)',
        build: () => cubit,
        seed: () => AttendanceState(
          status: AttendanceStatus.checkedIn,
          attendance: testAttendanceCheckedIn,
        ),
        act: (cubit) => cubit.checkIn(
          userId: 'user-1',
          libraryId: 'library-1',
          slot: Slot.morning,
        ),
        expect: () => [
          predicate<AttendanceState>(
            (s) => s.hasError && s.errorMessage!.contains('already checked in'),
          ),
        ],
        verify: (_) {
          verifyNever(() => mockCheckIn(any()));
        },
      );

      // V2: After checkout, user CAN check in again - this tests that behavior
      blocTest<AttendanceCubit, AttendanceState>(
        'V2: allows check-in after previous checkout (multi-session)',
        build: () {
          when(
            () => mockCheckIn(any()),
          ).thenAnswer((_) async => Right(testAttendanceCheckedIn));
          return cubit;
        },
        seed: () => AttendanceState(
          status: AttendanceStatus.checkedOut,
          attendance: testAttendanceCheckedOut,
        ),
        act: (cubit) => cubit.checkIn(
          userId: 'user-1',
          libraryId: 'library-1',
          slot: Slot.morning,
        ),
        expect: () => [
          predicate<AttendanceState>((s) => s.isLoading),
          predicate<AttendanceState>(
            (s) =>
                !s.isLoading &&
                s.status == AttendanceStatus.checkedIn &&
                s.attendance != null,
          ),
        ],
      );

      blocTest<AttendanceCubit, AttendanceState>(
        'emits loading then checkedIn when check-in successful',
        build: () {
          when(
            () => mockCheckIn(any()),
          ).thenAnswer((_) async => Right(testAttendanceCheckedIn));
          return cubit;
        },
        seed: () => const AttendanceState(status: AttendanceStatus.none),
        act: (cubit) => cubit.checkIn(
          userId: 'user-1',
          libraryId: 'library-1',
          slot: Slot.morning,
        ),
        expect: () => [
          predicate<AttendanceState>((s) => s.isLoading),
          predicate<AttendanceState>(
            (s) =>
                !s.isLoading &&
                s.status == AttendanceStatus.checkedIn &&
                s.attendance != null,
          ),
        ],
      );

      blocTest<AttendanceCubit, AttendanceState>(
        'emits error when check-in fails',
        build: () {
          when(() => mockCheckIn(any())).thenAnswer(
            (_) async => Left(
              OutOfRangeFailure(distanceInMeters: 500, maxAllowedDistance: 100),
            ),
          );
          return cubit;
        },
        seed: () => const AttendanceState(status: AttendanceStatus.none),
        act: (cubit) => cubit.checkIn(
          userId: 'user-1',
          libraryId: 'library-1',
          slot: Slot.morning,
        ),
        expect: () => [
          predicate<AttendanceState>((s) => s.isLoading),
          predicate<AttendanceState>(
            (s) => !s.isLoading && s.hasError && s.errorMessage != null,
          ),
        ],
      );
    });

    group('checkOut', () {
      blocTest<AttendanceCubit, AttendanceState>(
        'emits error when not checked in',
        build: () => cubit,
        seed: () => const AttendanceState(status: AttendanceStatus.none),
        act: (cubit) => cubit.checkOut(
          userId: 'user-1',
          libraryId: 'library-1',
          slot: Slot.morning,
        ),
        expect: () => [
          predicate<AttendanceState>(
            (s) => s.hasError && s.errorMessage == 'You need to check in first',
          ),
        ],
        verify: (_) {
          verifyNever(() => mockCheckOut(any()));
        },
      );

      // V2: Cannot check out when no active session (already checked out)
      blocTest<AttendanceCubit, AttendanceState>(
        'emits error when no active session (already checked out)',
        build: () => cubit,
        seed: () => AttendanceState(
          status: AttendanceStatus.checkedOut,
          attendance: testAttendanceCheckedOut,
        ),
        act: (cubit) => cubit.checkOut(
          userId: 'user-1',
          libraryId: 'library-1',
          slot: Slot.morning,
        ),
        expect: () => [
          predicate<AttendanceState>(
            (s) => s.hasError && s.errorMessage!.contains('No active session'),
          ),
        ],
        verify: (_) {
          verifyNever(() => mockCheckOut(any()));
        },
      );

      blocTest<AttendanceCubit, AttendanceState>(
        'emits loading then checkedOut when checkout successful',
        build: () {
          when(
            () => mockCheckOut(any()),
          ).thenAnswer((_) async => Right(testAttendanceCheckedOut));
          return cubit;
        },
        seed: () => AttendanceState(
          status: AttendanceStatus.checkedIn,
          attendance: testAttendanceCheckedIn,
        ),
        act: (cubit) => cubit.checkOut(
          userId: 'user-1',
          libraryId: 'library-1',
          slot: Slot.morning,
        ),
        expect: () => [
          predicate<AttendanceState>((s) => s.isLoading),
          predicate<AttendanceState>(
            (s) =>
                !s.isLoading &&
                s.status == AttendanceStatus.checkedOut &&
                s.attendance != null,
          ),
        ],
      );

      blocTest<AttendanceCubit, AttendanceState>(
        'emits error when checkout fails',
        build: () {
          when(() => mockCheckOut(any())).thenAnswer(
            (_) async => Left(
              OutOfRangeFailure(distanceInMeters: 400, maxAllowedDistance: 100),
            ),
          );
          return cubit;
        },
        seed: () => AttendanceState(
          status: AttendanceStatus.checkedIn,
          attendance: testAttendanceCheckedIn,
        ),
        act: (cubit) => cubit.checkOut(
          userId: 'user-1',
          libraryId: 'library-1',
          slot: Slot.morning,
        ),
        expect: () => [
          predicate<AttendanceState>((s) => s.isLoading),
          predicate<AttendanceState>(
            (s) => !s.isLoading && s.hasError && s.errorMessage != null,
          ),
        ],
      );
    });

    group('clearError', () {
      blocTest<AttendanceCubit, AttendanceState>(
        'clears error message',
        build: () => cubit,
        seed: () => const AttendanceState(
          status: AttendanceStatus.none,
          errorMessage: 'Some error',
        ),
        act: (cubit) => cubit.clearError(),
        expect: () => [predicate<AttendanceState>((s) => !s.hasError)],
      );
    });
  });
}
