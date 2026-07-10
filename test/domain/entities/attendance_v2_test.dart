import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/attendance.dart';
import 'package:pg_manager/domain/entities/attendance_session.dart';
import 'package:pg_manager/domain/entities/slot.dart';

void main() {
  group('Attendance V2 - Multi-Session Support', () {
    final now = DateTime.now();
    final todayDate =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    group('Backward Compatibility', () {
      test('should_work_with_legacy_single_session_attendance', () {
        final attendance = Attendance(
          id: 'att_1',
          userId: 'user_1',
          libraryId: 'lib_1',
          seatId: 'seat_1',
          slot: Slot.morning,
          date: todayDate,
          status: AttendanceStatus.checkedIn,
          checkInTime: now.subtract(const Duration(hours: 2)),
          createdAt: now,
          sessions: const [],
        );

        expect(attendance.isMultiSession, isFalse);
        expect(attendance.isCheckedIn, isTrue);
        expect(attendance.canCheckOut, isTrue);
        expect(attendance.canCheckIn, isFalse);
      });

      test('should_checkout_legacy_attendance_correctly', () {
        final attendance = Attendance(
          id: 'att_1',
          userId: 'user_1',
          libraryId: 'lib_1',
          seatId: 'seat_1',
          slot: Slot.morning,
          date: todayDate,
          status: AttendanceStatus.checkedIn,
          checkInTime: now.subtract(const Duration(hours: 2)),
          createdAt: now,
          sessions: const [],
        );

        final checkedOut = attendance.checkOut(distanceFromLibrary: 45.0);

        expect(checkedOut.isCheckedOut, isTrue);
        expect(checkedOut.checkOutTime, isNotNull);
        expect(checkedOut.checkOutDistance, 45.0);
      });
    });

    group('V2 Multi-Session Check-In', () {
      test('should_create_v2_attendance_with_first_session', () {
        final attendance = Attendance.checkInV2(
          id: 'att_1',
          userId: 'user_1',
          libraryId: 'lib_1',
          seatId: 'seat_1',
          slot: Slot.morning,
          date: todayDate,
          sessionId: 'session_1',
          distanceFromLibrary: 50.0,
        );

        expect(attendance.isMultiSession, isTrue);
        expect(attendance.sessions.length, 1);
        expect(attendance.sessions.first.sessionId, 'session_1');
        expect(attendance.sessions.first.isActive, isTrue);
        expect(attendance.hasActiveSession, isTrue);
        expect(attendance.status, AttendanceStatus.checkedIn);
      });

      test('should_not_allow_check_in_when_session_is_active', () {
        final attendance = Attendance.checkInV2(
          id: 'att_1',
          userId: 'user_1',
          libraryId: 'lib_1',
          seatId: 'seat_1',
          slot: Slot.morning,
          date: todayDate,
          sessionId: 'session_1',
          distanceFromLibrary: 50.0,
        );

        expect(attendance.canCheckIn, isFalse);
        expect(
          () => attendance.addSession(
            sessionId: 'session_2',
            distanceFromLibrary: 50.0,
          ),
          throwsStateError,
        );
      });
    });

    group('V2 Multi-Session Check-Out', () {
      test('should_complete_active_session_on_checkout', () {
        final checkInTime = now.subtract(const Duration(hours: 2));
        final session = AttendanceSession(
          sessionId: 'session_1',
          checkInAt: checkInTime,
          checkInDistance: 50.0,
        );

        final attendance = Attendance(
          id: 'att_1',
          userId: 'user_1',
          libraryId: 'lib_1',
          seatId: 'seat_1',
          slot: Slot.morning,
          date: todayDate,
          status: AttendanceStatus.checkedIn,
          createdAt: now,
          sessions: [session],
        );

        final checkedOut = attendance.completeActiveSession(
          distanceFromLibrary: 45.0,
        );

        expect(checkedOut.hasActiveSession, isFalse);
        expect(checkedOut.completedSessionCount, 1);
        expect(checkedOut.sessions.first.isComplete, isTrue);
        expect(checkedOut.status, AttendanceStatus.checkedOut);
      });

      test('should_allow_check_in_again_after_checkout', () {
        final completedSession = AttendanceSession(
          sessionId: 'session_1',
          checkInAt: now.subtract(const Duration(hours: 3)),
          checkOutAt: now.subtract(const Duration(hours: 1)),
          checkInDistance: 50.0,
          checkOutDistance: 45.0,
        );

        final attendance = Attendance(
          id: 'att_1',
          userId: 'user_1',
          libraryId: 'lib_1',
          seatId: 'seat_1',
          slot: Slot.morning,
          date: todayDate,
          status: AttendanceStatus.checkedOut,
          createdAt: now,
          sessions: [completedSession],
        );

        expect(attendance.canCheckIn, isTrue);
        expect(attendance.hasActiveSession, isFalse);
      });
    });

    group('V2 Add Session', () {
      test('should_add_new_session_after_previous_checkout', () {
        final completedSession = AttendanceSession(
          sessionId: 'session_1',
          checkInAt: now.subtract(const Duration(hours: 3)),
          checkOutAt: now.subtract(const Duration(hours: 1)),
          checkInDistance: 50.0,
          checkOutDistance: 45.0,
        );

        final attendance = Attendance(
          id: 'att_1',
          userId: 'user_1',
          libraryId: 'lib_1',
          seatId: 'seat_1',
          slot: Slot.morning,
          date: todayDate,
          status: AttendanceStatus.checkedOut,
          createdAt: now,
          sessions: [completedSession],
        );

        final withNewSession = attendance.addSession(
          sessionId: 'session_2',
          distanceFromLibrary: 48.0,
        );

        expect(withNewSession.sessions.length, 2);
        expect(withNewSession.hasActiveSession, isTrue);
        expect(withNewSession.activeSession?.sessionId, 'session_2');
        expect(withNewSession.status, AttendanceStatus.checkedIn);
      });

      test('should_track_multiple_sessions_correctly', () {
        final session1 = AttendanceSession(
          sessionId: 'session_1',
          checkInAt: now.subtract(const Duration(hours: 5)),
          checkOutAt: now.subtract(const Duration(hours: 4)),
          checkInDistance: 50.0,
          checkOutDistance: 45.0,
        );
        final session2 = AttendanceSession(
          sessionId: 'session_2',
          checkInAt: now.subtract(const Duration(hours: 2)),
          checkOutAt: now.subtract(const Duration(hours: 1)),
          checkInDistance: 48.0,
          checkOutDistance: 42.0,
        );

        final attendance = Attendance(
          id: 'att_1',
          userId: 'user_1',
          libraryId: 'lib_1',
          seatId: 'seat_1',
          slot: Slot.morning,
          date: todayDate,
          status: AttendanceStatus.checkedOut,
          createdAt: now,
          sessions: [session1, session2],
        );

        expect(attendance.sessionCount, 2);
        expect(attendance.completedSessionCount, 2);
        expect(attendance.hasActiveSession, isFalse);
        expect(attendance.totalCompletedMinutes, 120); // 60 + 60 minutes
      });
    });

    group('V2 Duration Calculations', () {
      test('should_calculate_total_completed_minutes', () {
        final session1 = AttendanceSession(
          sessionId: 'session_1',
          checkInAt: now.subtract(const Duration(hours: 5)),
          checkOutAt: now.subtract(const Duration(hours: 4, minutes: 30)),
          checkInDistance: 50.0,
          checkOutDistance: 45.0,
        );
        final session2 = AttendanceSession(
          sessionId: 'session_2',
          checkInAt: now.subtract(const Duration(hours: 2)),
          checkOutAt: now.subtract(const Duration(hours: 1)),
          checkInDistance: 48.0,
          checkOutDistance: 42.0,
        );

        final attendance = Attendance(
          id: 'att_1',
          userId: 'user_1',
          libraryId: 'lib_1',
          seatId: 'seat_1',
          slot: Slot.morning,
          date: todayDate,
          status: AttendanceStatus.checkedOut,
          createdAt: now,
          sessions: [session1, session2],
        );

        expect(attendance.totalCompletedMinutes, 90); // 30 + 60 minutes
      });

      test('should_format_total_time_correctly', () {
        final session1 = AttendanceSession(
          sessionId: 'session_1',
          checkInAt: now.subtract(const Duration(hours: 5)),
          checkOutAt: now.subtract(const Duration(hours: 3)),
          checkInDistance: 50.0,
          checkOutDistance: 45.0,
        );
        final session2 = AttendanceSession(
          sessionId: 'session_2',
          checkInAt: now.subtract(const Duration(hours: 2)),
          checkOutAt: now.subtract(const Duration(minutes: 30)),
          checkInDistance: 48.0,
          checkOutDistance: 42.0,
        );

        final attendance = Attendance(
          id: 'att_1',
          userId: 'user_1',
          libraryId: 'lib_1',
          seatId: 'seat_1',
          slot: Slot.morning,
          date: todayDate,
          status: AttendanceStatus.checkedOut,
          createdAt: now,
          sessions: [session1, session2],
        );

        expect(attendance.formattedTotalTime, '3h 30m'); // 2h + 1h30m
      });

      test('should_return_first_check_in_time', () {
        final session1 = AttendanceSession(
          sessionId: 'session_1',
          checkInAt: now.subtract(const Duration(hours: 5)),
          checkOutAt: now.subtract(const Duration(hours: 4)),
          checkInDistance: 50.0,
          checkOutDistance: 45.0,
        );
        final session2 = AttendanceSession(
          sessionId: 'session_2',
          checkInAt: now.subtract(const Duration(hours: 2)),
          checkOutAt: now.subtract(const Duration(hours: 1)),
          checkInDistance: 48.0,
          checkOutDistance: 42.0,
        );

        final attendance = Attendance(
          id: 'att_1',
          userId: 'user_1',
          libraryId: 'lib_1',
          seatId: 'seat_1',
          slot: Slot.morning,
          date: todayDate,
          status: AttendanceStatus.checkedOut,
          createdAt: now,
          sessions: [session1, session2],
        );

        expect(attendance.firstCheckInTime, session1.checkInAt);
      });

      test('should_return_last_check_out_time', () {
        final session1 = AttendanceSession(
          sessionId: 'session_1',
          checkInAt: now.subtract(const Duration(hours: 5)),
          checkOutAt: now.subtract(const Duration(hours: 4)),
          checkInDistance: 50.0,
          checkOutDistance: 45.0,
        );
        final session2 = AttendanceSession(
          sessionId: 'session_2',
          checkInAt: now.subtract(const Duration(hours: 2)),
          checkOutAt: now.subtract(const Duration(hours: 1)),
          checkInDistance: 48.0,
          checkOutDistance: 42.0,
        );

        final attendance = Attendance(
          id: 'att_1',
          userId: 'user_1',
          libraryId: 'lib_1',
          seatId: 'seat_1',
          slot: Slot.morning,
          date: todayDate,
          status: AttendanceStatus.checkedOut,
          createdAt: now,
          sessions: [session1, session2],
        );

        expect(attendance.lastCheckOutTime, session2.checkOutAt);
      });
    });

    group('V2 Backward Compatible checkOut method', () {
      test('should_use_completeActiveSession_for_v2_records', () {
        final session = AttendanceSession(
          sessionId: 'session_1',
          checkInAt: now.subtract(const Duration(hours: 2)),
          checkInDistance: 50.0,
        );

        final attendance = Attendance(
          id: 'att_1',
          userId: 'user_1',
          libraryId: 'lib_1',
          seatId: 'seat_1',
          slot: Slot.morning,
          date: todayDate,
          status: AttendanceStatus.checkedIn,
          createdAt: now,
          sessions: [session],
        );

        // Using the legacy checkOut method should work for V2
        final checkedOut = attendance.checkOut(distanceFromLibrary: 45.0);

        expect(checkedOut.hasActiveSession, isFalse);
        expect(checkedOut.sessions.first.isComplete, isTrue);
      });
    });
  });
}
