import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/user.dart';
import 'package:pg_manager/domain/entities/user_session.dart';

void main() {
  group('UserSession', () {
    late DateTime testStartTime;
    late DateTime testEndTime;
    late UserSession activeSession;
    late UserSession completedSession;

    setUp(() {
      testStartTime = DateTime(2026, 1, 15, 10, 30);
      testEndTime = DateTime(2026, 1, 15, 12, 45);

      activeSession = UserSession(
        id: 'session_1',
        userId: 'user_1',
        startTime: testStartTime,
        role: UserRole.student,
        lastActiveTime: testStartTime.add(const Duration(minutes: 30)),
      );

      completedSession = UserSession(
        id: 'session_2',
        userId: 'user_2',
        startTime: testStartTime,
        endTime: testEndTime,
        role: UserRole.owner,
      );
    });

    group('isActive', () {
      test('should_return_true_when_endTime_is_null', () {
        expect(activeSession.isActive, true);
      });

      test('should_return_false_when_endTime_is_set', () {
        expect(completedSession.isActive, false);
      });
    });

    group('durationMinutes', () {
      test('should_return_null_when_session_is_active', () {
        expect(activeSession.durationMinutes, null);
      });

      test('should_return_correct_duration_when_session_is_complete', () {
        // 2 hours 15 minutes = 135 minutes
        expect(completedSession.durationMinutes, 135);
      });
    });

    group('currentDurationMinutes', () {
      test('should_use_lastActiveTime_when_available', () {
        final session = UserSession(
          id: 'session_1',
          userId: 'user_1',
          startTime: testStartTime,
          lastActiveTime: testStartTime.add(const Duration(minutes: 45)),
          role: UserRole.student,
        );

        expect(session.currentDurationMinutes, 45);
      });

      test('should_use_endTime_when_session_is_complete', () {
        expect(completedSession.currentDurationMinutes, 135);
      });
    });

    group('startHour', () {
      test('should_return_correct_hour_of_day', () {
        expect(activeSession.startHour, 10);
      });
    });

    group('sessionDate', () {
      test('should_return_date_normalized_to_midnight', () {
        final expected = DateTime(2026, 1, 15);
        expect(activeSession.sessionDate, expected);
      });
    });

    group('toJson and fromJson', () {
      test('should_serialize_and_deserialize_correctly', () {
        final json = activeSession.toJson();
        final restored = UserSession.fromJson('session_1', json);

        expect(restored.id, activeSession.id);
        expect(restored.userId, activeSession.userId);
        expect(restored.startTime, activeSession.startTime);
        expect(restored.lastActiveTime, activeSession.lastActiveTime);
        expect(restored.role, activeSession.role);
      });

      test('should_handle_optional_fields_correctly', () {
        final session = UserSession(
          id: 'session_3',
          userId: 'user_3',
          startTime: testStartTime,
          role: UserRole.admin,
          deviceId: 'device_123',
        );

        final json = session.toJson();
        final restored = UserSession.fromJson('session_3', json);

        expect(restored.deviceId, 'device_123');
        expect(restored.endTime, null);
        expect(restored.lastActiveTime, null);
      });
    });

    group('copyWith', () {
      test('should_create_copy_with_updated_fields', () {
        final updated = activeSession.copyWith(
          endTime: testEndTime,
          lastActiveTime: testEndTime,
        );

        expect(updated.id, activeSession.id);
        expect(updated.userId, activeSession.userId);
        expect(updated.startTime, activeSession.startTime);
        expect(updated.endTime, testEndTime);
        expect(updated.lastActiveTime, testEndTime);
        expect(updated.isActive, false);
      });

      test('should_preserve_original_fields_when_not_updated', () {
        final updated = activeSession.copyWith(endTime: testEndTime);

        expect(updated.userId, activeSession.userId);
        expect(updated.startTime, activeSession.startTime);
        expect(updated.role, activeSession.role);
      });
    });

    group('Equatable', () {
      test('should_be_equal_when_all_properties_match', () {
        final session1 = UserSession(
          id: 'session_1',
          userId: 'user_1',
          startTime: testStartTime,
          role: UserRole.student,
        );

        final session2 = UserSession(
          id: 'session_1',
          userId: 'user_1',
          startTime: testStartTime,
          role: UserRole.student,
        );

        expect(session1, session2);
      });

      test('should_not_be_equal_when_properties_differ', () {
        final session1 = UserSession(
          id: 'session_1',
          userId: 'user_1',
          startTime: testStartTime,
          role: UserRole.student,
        );

        final session2 = UserSession(
          id: 'session_2',
          userId: 'user_1',
          startTime: testStartTime,
          role: UserRole.student,
        );

        expect(session1, isNot(session2));
      });
    });
  });
}
