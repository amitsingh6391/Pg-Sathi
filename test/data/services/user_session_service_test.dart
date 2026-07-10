import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/data/failures/data_failures.dart';
import 'package:pg_manager/data/services/user_session_service.dart';
import 'package:pg_manager/domain/entities/user.dart';
import 'package:pg_manager/domain/entities/user_session.dart';
import 'package:pg_manager/domain/repositories/user_session_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockUserSessionRepository extends Mock
    implements UserSessionRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  late MockUserSessionRepository mockRepository;
  late UserSessionService service;

  setUpAll(() {
    registerFallbackValue(UserRole.student);
  });

  setUp(() {
    mockRepository = MockUserSessionRepository();
    service = UserSessionService(mockRepository);
  });

  tearDown(() {
    service.dispose();
  });

  group('UserSessionService', () {
    final testSession = UserSession(
      id: 'session_1',
      userId: 'user_1',
      startTime: DateTime.now(),
      role: UserRole.student,
    );

    group('startSession', () {
      test('should_start_new_session_successfully', () async {
        when(
          () => mockRepository.startSession(
            userId: any(named: 'userId'),
            role: any(named: 'role'),
            deviceId: any(named: 'deviceId'),
          ),
        ).thenAnswer((_) async => Right(testSession));

        await service.startSession(
          userId: 'user_1',
          role: UserRole.student,
          deviceId: 'device_123',
        );

        verify(
          () => mockRepository.startSession(
            userId: 'user_1',
            role: UserRole.student,
            deviceId: 'device_123',
          ),
        ).called(1);
      });

      test('should_end_existing_session_before_starting_new_one', () async {
        // First session
        when(
          () => mockRepository.startSession(
            userId: any(named: 'userId'),
            role: any(named: 'role'),
            deviceId: any(named: 'deviceId'),
          ),
        ).thenAnswer((_) async => Right(testSession));

        when(() => mockRepository.endSession(any()))
            .thenAnswer((_) async => const Right(null));

        // Start first session
        await service.startSession(
          userId: 'user_1',
          role: UserRole.student,
        );

        // Start second session (should end first)
        await service.startSession(
          userId: 'user_1',
          role: UserRole.student,
        );

        verify(() => mockRepository.endSession('session_1')).called(1);
      });

      test('should_handle_failure_gracefully', () async {
        when(
          () => mockRepository.startSession(
            userId: any(named: 'userId'),
            role: any(named: 'role'),
            deviceId: any(named: 'deviceId'),
          ),
        ).thenAnswer(
          (_) async => Left(ServerFailure(message: 'Failed')),
        );

        // Should not throw
        await service.startSession(
          userId: 'user_1',
          role: UserRole.student,
        );
      });
    });

    group('endSession', () {
      test('should_end_active_session', () async {
        when(
          () => mockRepository.startSession(
            userId: any(named: 'userId'),
            role: any(named: 'role'),
            deviceId: any(named: 'deviceId'),
          ),
        ).thenAnswer((_) async => Right(testSession));

        when(() => mockRepository.endSession(any()))
            .thenAnswer((_) async => const Right(null));

        // Start session
        await service.startSession(
          userId: 'user_1',
          role: UserRole.student,
        );

        // End session
        await service.endSession();

        verify(() => mockRepository.endSession('session_1')).called(1);
      });

      test('should_do_nothing_when_no_active_session', () async {
        await service.endSession();

        verifyNever(() => mockRepository.endSession(any()));
      });
    });

    group('updateLastActive', () {
      test('should_update_last_active_time', () async {
        when(
          () => mockRepository.startSession(
            userId: any(named: 'userId'),
            role: any(named: 'role'),
            deviceId: any(named: 'deviceId'),
          ),
        ).thenAnswer((_) async => Right(testSession));

        when(() => mockRepository.updateLastActive(any()))
            .thenAnswer((_) async => const Right(null));

        // Start session
        await service.startSession(
          userId: 'user_1',
          role: UserRole.student,
        );

        // Update last active
        await service.updateLastActive();

        verify(() => mockRepository.updateLastActive('session_1')).called(1);
      });

      test('should_do_nothing_when_no_active_session', () async {
        await service.updateLastActive();

        verifyNever(() => mockRepository.updateLastActive(any()));
      });
    });
  });
}
