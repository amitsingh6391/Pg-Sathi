import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:pg_manager/domain/core/failure.dart';
import 'package:pg_manager/domain/repositories/admin_analytics_repository.dart';
import 'package:pg_manager/domain/repositories/notification_repository.dart';
import 'package:pg_manager/domain/usecases/send_admin_broadcast_notification.dart';

class MockAdminAnalyticsRepository extends Mock
    implements AdminAnalyticsRepository {}

class MockNotificationRepository extends Mock
    implements NotificationRepository {}

void main() {
  late SendAdminBroadcastNotification useCase;
  late MockAdminAnalyticsRepository mockAnalyticsRepository;
  late MockNotificationRepository mockNotificationRepository;

  setUp(() {
    mockAnalyticsRepository = MockAdminAnalyticsRepository();
    mockNotificationRepository = MockNotificationRepository();
    useCase = SendAdminBroadcastNotification(
      analyticsRepository: mockAnalyticsRepository,
      notificationRepository: mockNotificationRepository,
    );
  });

  setUpAll(() {
    registerFallbackValue(<String>[]);
    registerFallbackValue(<String, dynamic>{});
  });

  group('SendAdminBroadcastNotification', () {
    const tTitle = 'Test Notification';
    const tBody = 'This is a test notification body';
    const tOwnerIds = ['owner-1', 'owner-2', 'owner-3'];
    const tStudentIds = ['student-1', 'student-2'];

    test('should_send_to_all_owners_when_audience_is_allOwners', () async {
      // Arrange
      when(
        () => mockAnalyticsRepository.getAllOwnerIds(),
      ).thenAnswer((_) async => const Right(tOwnerIds));
      when(
        () => mockNotificationRepository.sendNotificationsToUsers(
          userIds: any(named: 'userIds'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => const Right(null));

      // Act
      final result = await useCase(
        const SendAdminBroadcastParams(
          title: tTitle,
          body: tBody,
          audience: BroadcastAudience.allOwners,
        ),
      );

      // Assert
      expect(result, const Right(3)); // 3 owners
      verify(() => mockAnalyticsRepository.getAllOwnerIds()).called(1);
      verify(
        () => mockNotificationRepository.sendNotificationsToUsers(
          userIds: tOwnerIds,
          title: tTitle,
          body: tBody,
          data: null,
        ),
      ).called(1);
    });

    test('should_send_to_all_students_when_audience_is_allStudents', () async {
      // Arrange
      when(
        () => mockAnalyticsRepository.getAllStudentIds(),
      ).thenAnswer((_) async => const Right(tStudentIds));
      when(
        () => mockNotificationRepository.sendNotificationsToUsers(
          userIds: any(named: 'userIds'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => const Right(null));

      // Act
      final result = await useCase(
        const SendAdminBroadcastParams(
          title: tTitle,
          body: tBody,
          audience: BroadcastAudience.allStudents,
        ),
      );

      // Assert
      expect(result, const Right(2)); // 2 students
      verify(() => mockAnalyticsRepository.getAllStudentIds()).called(1);
      verify(
        () => mockNotificationRepository.sendNotificationsToUsers(
          userIds: tStudentIds,
          title: tTitle,
          body: tBody,
          data: null,
        ),
      ).called(1);
    });

    test(
      'should_send_to_selected_libraries_when_audience_is_selectedLibraries',
      () async {
        // Arrange
        const libraryIds = ['lib-1', 'lib-2'];
        const ownerIdsForLibraries = ['owner-1', 'owner-2'];

        when(
          () => mockAnalyticsRepository.getOwnerIdsForLibraries(libraryIds),
        ).thenAnswer((_) async => const Right(ownerIdsForLibraries));
        when(
          () => mockNotificationRepository.sendNotificationsToUsers(
            userIds: any(named: 'userIds'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            data: any(named: 'data'),
          ),
        ).thenAnswer((_) async => const Right(null));

        // Act
        final result = await useCase(
          const SendAdminBroadcastParams(
            title: tTitle,
            body: tBody,
            audience: BroadcastAudience.selectedLibraries,
            libraryIds: libraryIds,
          ),
        );

        // Assert
        expect(result, const Right(2));
        verify(
          () => mockAnalyticsRepository.getOwnerIdsForLibraries(libraryIds),
        ).called(1);
      },
    );

    test(
      'should_return_failure_when_library_ids_missing_for_selected_libraries',
      () async {
        // Act
        final result = await useCase(
          const SendAdminBroadcastParams(
            title: tTitle,
            body: tBody,
            audience: BroadcastAudience.selectedLibraries,
            libraryIds: [], // Empty
          ),
        );

        // Assert
        expect(result.isLeft(), true);
        result.fold(
          (failure) =>
              expect(failure.message, 'Library IDs required for this audience'),
          (_) => fail('Should return failure'),
        );
      },
    );

    test('should_return_zero_when_no_users_found', () async {
      // Arrange
      when(
        () => mockAnalyticsRepository.getAllOwnerIds(),
      ).thenAnswer((_) async => const Right([]));

      // Act
      final result = await useCase(
        const SendAdminBroadcastParams(
          title: tTitle,
          body: tBody,
          audience: BroadcastAudience.allOwners,
        ),
      );

      // Assert
      expect(result, const Right(0));
      verifyNever(
        () => mockNotificationRepository.sendNotificationsToUsers(
          userIds: any(named: 'userIds'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          data: any(named: 'data'),
        ),
      );
    });

    test('should_return_failure_when_getting_user_ids_fails', () async {
      // Arrange
      const tFailure = ServerFailure(message: 'Database error');
      when(
        () => mockAnalyticsRepository.getAllOwnerIds(),
      ).thenAnswer((_) async => const Left(tFailure));

      // Act
      final result = await useCase(
        const SendAdminBroadcastParams(
          title: tTitle,
          body: tBody,
          audience: BroadcastAudience.allOwners,
        ),
      );

      // Assert
      expect(result.isLeft(), true);
    });

    test('should_return_failure_when_sending_notifications_fails', () async {
      // Arrange
      const tFailure = ServerFailure(message: 'Notification failed');
      when(
        () => mockAnalyticsRepository.getAllOwnerIds(),
      ).thenAnswer((_) async => const Right(tOwnerIds));
      when(
        () => mockNotificationRepository.sendNotificationsToUsers(
          userIds: any(named: 'userIds'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => const Left(tFailure));

      // Act
      final result = await useCase(
        const SendAdminBroadcastParams(
          title: tTitle,
          body: tBody,
          audience: BroadcastAudience.allOwners,
        ),
      );

      // Assert
      expect(result.isLeft(), true);
    });
  });

  group('SendAdminBroadcastParams', () {
    test('should_support_equality', () {
      const params1 = SendAdminBroadcastParams(
        title: 'Title',
        body: 'Body',
        audience: BroadcastAudience.allOwners,
      );
      const params2 = SendAdminBroadcastParams(
        title: 'Title',
        body: 'Body',
        audience: BroadcastAudience.allOwners,
      );

      expect(params1, equals(params2));
    });
  });

  group('BroadcastAudience', () {
    test('should_have_all_expected_values', () {
      expect(BroadcastAudience.values, hasLength(8));
      expect(BroadcastAudience.values, contains(BroadcastAudience.allOwners));
      expect(BroadcastAudience.values, contains(BroadcastAudience.ownersWithLibrary));
      expect(BroadcastAudience.values, contains(BroadcastAudience.ownersWithoutLibrary));
      expect(BroadcastAudience.values, contains(BroadcastAudience.allStudents));
      expect(BroadcastAudience.values, contains(BroadcastAudience.studentsWithActiveMembership));
      expect(BroadcastAudience.values, contains(BroadcastAudience.activeStudents));
      expect(BroadcastAudience.values, contains(BroadcastAudience.selectedLibraries));
      expect(BroadcastAudience.values, contains(BroadcastAudience.selectedLibraryStudents));
    });
  });
}

class ServerFailure extends Failure {
  const ServerFailure({super.message});
}
