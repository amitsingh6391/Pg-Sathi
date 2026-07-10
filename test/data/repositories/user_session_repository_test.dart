import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/data/repositories/user_session_repository_impl.dart';
import 'package:pg_manager/domain/entities/user.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late UserSessionRepositoryImpl repository;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repository = UserSessionRepositoryImpl(fakeFirestore);
  });

  group('UserSessionRepository', () {
    group('startSession', () {
      test('should_create_new_session_successfully', () async {
        final result = await repository.startSession(
          userId: 'user_1',
          role: UserRole.student,
          deviceId: 'device_123',
        );

        expect(result.isRight(), true);

        result.fold(
          (failure) => fail('Should not fail'),
          (session) {
            expect(session.userId, 'user_1');
            expect(session.role, UserRole.student);
            expect(session.deviceId, 'device_123');
            expect(session.isActive, true);
          },
        );
      });

      test('should_save_session_to_firestore', () async {
        final result = await repository.startSession(
          userId: 'user_1',
          role: UserRole.student,
        );

        result.fold(
          (failure) => fail('Should not fail'),
          (session) async {
            final doc = await fakeFirestore
                .collection('user_sessions')
                .doc(session.id)
                .get();

            expect(doc.exists, true);
            expect(doc.data()!['userId'], 'user_1');
            expect(doc.data()!['role'], 'student');
          },
        );
      });
    });

    group('endSession', () {
      test('should_update_session_with_endTime', () async {
        final startResult = await repository.startSession(
          userId: 'user_1',
          role: UserRole.student,
        );

        final sessionId = startResult.getOrElse(() => throw Exception());

        final endResult = await repository.endSession(sessionId.id);

        expect(endResult.isRight(), true);

        final doc = await fakeFirestore
            .collection('user_sessions')
            .doc(sessionId.id)
            .get();

        expect(doc.data()!['endTime'], isNotNull);
      });
    });

    group('updateLastActive', () {
      test('should_update_lastActiveTime', () async {
        final startResult = await repository.startSession(
          userId: 'user_1',
          role: UserRole.student,
        );

        final sessionId = startResult.getOrElse(() => throw Exception());

        // Wait a bit to ensure time difference
        await Future.delayed(const Duration(milliseconds: 100));

        final updateResult = await repository.updateLastActive(sessionId.id);

        expect(updateResult.isRight(), true);

        final doc = await fakeFirestore
            .collection('user_sessions')
            .doc(sessionId.id)
            .get();

        final lastActiveTime =
            (doc.data()!['lastActiveTime'] as Timestamp).toDate();
        expect(
          lastActiveTime.isAfter(sessionId.startTime),
          true,
        );
      });
    });

    group('getUserSessions', () {
      test('should_return_user_sessions_in_date_range', () async {
        // Create session within range
        await repository.startSession(
          userId: 'user_1',
          role: UserRole.student,
        );

        // Wait a bit
        await Future.delayed(const Duration(milliseconds: 50));

        final result = await repository.getUserSessions(
          userId: 'user_1',
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2026, 12, 31),
        );

        expect(result.isRight(), true);

        result.fold(
          (failure) => fail('Should not fail'),
          (sessions) {
            expect(sessions.length, 1);
            expect(sessions.first.userId, 'user_1');
          },
        );
      });

      test('should_return_empty_list_when_no_sessions_found', () async {
        final result = await repository.getUserSessions(
          userId: 'nonexistent_user',
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2026, 1, 31),
        );

        expect(result.isRight(), true);

        result.fold(
          (failure) => fail('Should not fail'),
          (sessions) {
            expect(sessions.isEmpty, true);
          },
        );
      });
    });

    group('getStudentSessions', () {
      test('should_return_only_student_sessions', () async {
        // Create student session
        await repository.startSession(
          userId: 'student_1',
          role: UserRole.student,
        );

        // Create owner session
        await repository.startSession(
          userId: 'owner_1',
          role: UserRole.owner,
        );

        await Future.delayed(const Duration(milliseconds: 50));

        final result = await repository.getStudentSessions(
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2026, 12, 31),
        );

        expect(result.isRight(), true);

        result.fold(
          (failure) => fail('Should not fail'),
          (sessions) {
            expect(sessions.length, 1);
            expect(sessions.first.userId, 'student_1');
            expect(sessions.first.role, UserRole.student);
          },
        );
      });
    });

    group('getOwnerSessions', () {
      test('should_return_only_owner_sessions', () async {
        // Create student session
        await repository.startSession(
          userId: 'student_1',
          role: UserRole.student,
        );

        // Create owner session
        await repository.startSession(
          userId: 'owner_1',
          role: UserRole.owner,
        );

        await Future.delayed(const Duration(milliseconds: 50));

        final result = await repository.getOwnerSessions(
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2026, 12, 31),
        );

        expect(result.isRight(), true);

        result.fold(
          (failure) => fail('Should not fail'),
          (sessions) {
            expect(sessions.length, 1);
            expect(sessions.first.userId, 'owner_1');
            expect(sessions.first.role, UserRole.owner);
          },
        );
      });
    });

    group('getActiveSession', () {
      test('should_return_active_session_when_exists', () async {
        final startResult = await repository.startSession(
          userId: 'user_1',
          role: UserRole.student,
        );

        final sessionId = startResult.getOrElse(() => throw Exception());

        await Future.delayed(const Duration(milliseconds: 50));

        final result = await repository.getActiveSession('user_1');

        expect(result.isRight(), true);

        result.fold(
          (failure) => fail('Should not fail'),
          (session) {
            expect(session, isNotNull);
            expect(session!.id, sessionId.id);
            expect(session.isActive, true);
          },
        );
      });

      test('should_return_null_when_no_active_session', () async {
        final result = await repository.getActiveSession('nonexistent_user');

        expect(result.isRight(), true);

        result.fold(
          (failure) => fail('Should not fail'),
          (session) {
            expect(session, null);
          },
        );
      });

      test('should_return_null_when_session_is_ended', () async {
        final startResult = await repository.startSession(
          userId: 'user_1',
          role: UserRole.student,
        );

        final sessionId = startResult.getOrElse(() => throw Exception());

        await repository.endSession(sessionId.id);

        await Future.delayed(const Duration(milliseconds: 50));

        final result = await repository.getActiveSession('user_1');

        expect(result.isRight(), true);

        result.fold(
          (failure) => fail('Should not fail'),
          (session) {
            expect(session, null);
          },
        );
      });
    });
  });
}
