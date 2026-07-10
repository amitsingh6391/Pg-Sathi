import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/attendance_session.dart';

void main() {
  group('AttendanceSession', () {
    final now = DateTime.now();

    test('should create an active session with checkIn factory', () {
      final session = AttendanceSession.checkIn(
        sessionId: 'session_1',
        checkInTime: now,
        distanceFromLibrary: 50.0,
      );

      expect(session.sessionId, 'session_1');
      expect(session.checkInAt, now);
      expect(session.checkOutAt, isNull);
      expect(session.checkInDistance, 50.0);
      expect(session.checkOutDistance, isNull);
      expect(session.isActive, isTrue);
      expect(session.isComplete, isFalse);
    });

    test('should_return_null_durationMinutes_when_session_is_active', () {
      final session = AttendanceSession.checkIn(
        sessionId: 'session_1',
        checkInTime: now,
        distanceFromLibrary: 50.0,
      );

      expect(session.durationMinutes, isNull);
      expect(session.formattedCompletedDuration, isNull);
    });

    test('should_calculate_currentDurationMinutes_for_active_session', () {
      final checkInTime = DateTime.now().subtract(const Duration(minutes: 30));
      final session = AttendanceSession.checkIn(
        sessionId: 'session_1',
        checkInTime: checkInTime,
        distanceFromLibrary: 50.0,
      );

      // Should be approximately 30 minutes (allowing for test execution time)
      expect(session.currentDurationMinutes, greaterThanOrEqualTo(29));
      expect(session.currentDurationMinutes, lessThanOrEqualTo(31));
    });

    test('should_complete_session_with_checkout_time', () {
      final checkInTime = now.subtract(const Duration(hours: 2));
      final checkOutTime = now;

      final activeSession = AttendanceSession.checkIn(
        sessionId: 'session_1',
        checkInTime: checkInTime,
        distanceFromLibrary: 50.0,
      );

      final completedSession = activeSession.complete(
        checkOutTime: checkOutTime,
        distanceFromLibrary: 45.0,
      );

      expect(completedSession.isActive, isFalse);
      expect(completedSession.isComplete, isTrue);
      expect(completedSession.checkOutAt, checkOutTime);
      expect(completedSession.checkOutDistance, 45.0);
      expect(completedSession.durationMinutes, 120);
    });

    test('should_format_duration_correctly', () {
      final checkInTime = now.subtract(const Duration(hours: 2, minutes: 30));
      final checkOutTime = now;

      final session = AttendanceSession(
        sessionId: 'session_1',
        checkInAt: checkInTime,
        checkOutAt: checkOutTime,
        checkInDistance: 50.0,
        checkOutDistance: 45.0,
      );

      expect(session.formattedCompletedDuration, '2h 30m');
    });

    test('should_format_short_duration_without_hours', () {
      final checkInTime = now.subtract(const Duration(minutes: 45));
      final checkOutTime = now;

      final session = AttendanceSession(
        sessionId: 'session_1',
        checkInAt: checkInTime,
        checkOutAt: checkOutTime,
        checkInDistance: 50.0,
        checkOutDistance: 45.0,
      );

      expect(session.formattedCompletedDuration, '45m');
    });

    test('should_support_equality', () {
      final session1 = AttendanceSession(
        sessionId: 'session_1',
        checkInAt: now,
        checkOutAt: null,
        checkInDistance: 50.0,
      );

      final session2 = AttendanceSession(
        sessionId: 'session_1',
        checkInAt: now,
        checkOutAt: null,
        checkInDistance: 50.0,
      );

      expect(session1, equals(session2));
    });
  });
}
