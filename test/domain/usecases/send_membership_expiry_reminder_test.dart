import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/membership.dart';
import 'package:pg_manager/domain/failures/membership_failures.dart';
import 'package:pg_manager/domain/repositories/membership_repository.dart';
import 'package:pg_manager/domain/repositories/notification_repository.dart';
import 'package:pg_manager/domain/usecases/send_membership_expiry_reminder.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'send_membership_expiry_reminder_test.mocks.dart';

@GenerateMocks([MembershipRepository, NotificationRepository])
void main() {
  late SendMembershipExpiryReminder useCase;
  late MockMembershipRepository mockMembershipRepository;
  late MockNotificationRepository mockNotificationRepository;

  setUp(() {
    mockMembershipRepository = MockMembershipRepository();
    mockNotificationRepository = MockNotificationRepository();
    useCase = SendMembershipExpiryReminder(
      membershipRepository: mockMembershipRepository,
      notificationRepository: mockNotificationRepository,
      daysThreshold: 3,
    );
  });

  final now = DateTime(2024, 1, 15);
  final expiringDate = DateTime(2024, 1, 17); // 2 days from now
  final libraryId = 'library-1';

  final expiringMembership = Membership(
    id: 'membership-1',
    userId: 'user-1',
    libraryId: libraryId,
    plan: MembershipPlan.monthly,
    startDate: DateTime(2023, 12, 1),
    endDate: expiringDate,
    phoneNumber: '+919876543210',
    status: MembershipStatus.active,
  );

  group('SendMembershipExpiryReminder', () {
    test('should_return_failure_when_studentIds_is_empty', () async {
      // Act
      final result = await useCase(
        SendMembershipExpiryReminderParams(
          libraryId: libraryId,
          studentIds: [],
        ),
      );

      // Assert
      expect(result.isLeft(), true);
      result.fold((failure) {
        expect(failure, isA<InvalidMembershipDataFailure>());
        expect(failure.message, contains('cannot be empty'));
      }, (_) => fail('Should return failure'));
      verifyNever(
        mockMembershipRepository.getExpiringMemberships(
          libraryId: anyNamed('libraryId'),
          currentDate: anyNamed('currentDate'),
          daysThreshold: anyNamed('daysThreshold'),
        ),
      );
    });

    test('should_return_success_when_no_expiring_memberships', () async {
      // Arrange
      when(
        mockMembershipRepository.getExpiringMemberships(
          libraryId: anyNamed('libraryId'),
          currentDate: anyNamed('currentDate'),
          daysThreshold: anyNamed('daysThreshold'),
        ),
      ).thenAnswer((_) async => const Right([]));

      // Act
      final result = await useCase(
        SendMembershipExpiryReminderParams(
          libraryId: libraryId,
          studentIds: ['user-1'],
        ),
      );

      // Assert
      expect(result.isRight(), true);
      verify(
        mockMembershipRepository.getExpiringMemberships(
          libraryId: libraryId,
          currentDate: anyNamed('currentDate'),
          daysThreshold: 3,
        ),
      ).called(1);
      verifyNever(
        mockNotificationRepository.sendNotificationsToUsers(
          userIds: anyNamed('userIds'),
          title: anyNamed('title'),
          body: anyNamed('body'),
        ),
      );
    });

    test('should_send_notifications_for_valid_expiring_memberships', () async {
      // Arrange
      when(
        mockMembershipRepository.getExpiringMemberships(
          libraryId: anyNamed('libraryId'),
          currentDate: anyNamed('currentDate'),
          daysThreshold: anyNamed('daysThreshold'),
        ),
      ).thenAnswer((_) async => Right([expiringMembership]));

      when(
        mockNotificationRepository.sendNotificationsToUsers(
          userIds: anyNamed('userIds'),
          title: anyNamed('title'),
          body: anyNamed('body'),
          data: anyNamed('data'),
        ),
      ).thenAnswer((_) async => const Right(null));

      // Act
      final result = await useCase(
        SendMembershipExpiryReminderParams(
          libraryId: libraryId,
          studentIds: ['user-1'],
          currentDate: now,
        ),
      );

      // Assert
      expect(result.isRight(), true);
      verify(
        mockMembershipRepository.getExpiringMemberships(
          libraryId: libraryId,
          currentDate: now,
          daysThreshold: 3,
        ),
      ).called(1);
      verify(
        mockNotificationRepository.sendNotificationsToUsers(
          userIds: ['user-1'],
          title: anyNamed('title'),
          body: anyNamed('body'),
          data: anyNamed('data'),
        ),
      ).called(1);
    });

    test('should_filter_to_only_requested_student_ids', () async {
      // Arrange
      final membership2 = Membership(
        id: 'membership-2',
        userId: 'user-2',
        libraryId: libraryId,
        plan: MembershipPlan.monthly,
        startDate: DateTime(2023, 12, 1),
        endDate: expiringDate,
        status: MembershipStatus.active,
        phoneNumber: '+919876543211',
      );

      when(
        mockMembershipRepository.getExpiringMemberships(
          libraryId: anyNamed('libraryId'),
          currentDate: anyNamed('currentDate'),
          daysThreshold: anyNamed('daysThreshold'),
        ),
      ).thenAnswer((_) async => Right([expiringMembership, membership2]));

      when(
        mockNotificationRepository.sendNotificationsToUsers(
          userIds: anyNamed('userIds'),
          title: anyNamed('title'),
          body: anyNamed('body'),
          data: anyNamed('data'),
        ),
      ).thenAnswer((_) async => const Right(null));

      // Act
      final result = await useCase(
        SendMembershipExpiryReminderParams(
          libraryId: libraryId,
          studentIds: ['user-1'], // Only request for user-1
          currentDate: now,
        ),
      );

      // Assert
      expect(result.isRight(), true);
      verify(
        mockNotificationRepository.sendNotificationsToUsers(
          userIds: ['user-1'], // Should only send to user-1
          title: anyNamed('title'),
          body: anyNamed('body'),
          data: anyNamed('data'),
        ),
      ).called(1);
    });

    test('should_filter_out_non_active_memberships', () async {
      // Arrange
      final expiredMembership = expiringMembership.copyWith(
        status: MembershipStatus.expired,
      );

      when(
        mockMembershipRepository.getExpiringMemberships(
          libraryId: anyNamed('libraryId'),
          currentDate: anyNamed('currentDate'),
          daysThreshold: anyNamed('daysThreshold'),
        ),
      ).thenAnswer((_) async => Right([expiredMembership]));

      // Act
      final result = await useCase(
        SendMembershipExpiryReminderParams(
          libraryId: libraryId,
          studentIds: ['user-1'],
          currentDate: now,
        ),
      );

      // Assert
      expect(result.isRight(), true);
      // Should not send notification for expired membership
      verifyNever(
        mockNotificationRepository.sendNotificationsToUsers(
          userIds: anyNamed('userIds'),
          title: anyNamed('title'),
          body: anyNamed('body'),
        ),
      );
    });

    test('should_use_custom_title_and_body_when_provided', () async {
      // Arrange
      when(
        mockMembershipRepository.getExpiringMemberships(
          libraryId: anyNamed('libraryId'),
          currentDate: anyNamed('currentDate'),
          daysThreshold: anyNamed('daysThreshold'),
        ),
      ).thenAnswer((_) async => Right([expiringMembership]));

      when(
        mockNotificationRepository.sendNotificationsToUsers(
          userIds: anyNamed('userIds'),
          title: anyNamed('title'),
          body: anyNamed('body'),
          data: anyNamed('data'),
        ),
      ).thenAnswer((_) async => const Right(null));

      const customTitle = 'Custom Title';
      const customBody = 'Custom Body';

      // Act
      await useCase(
        SendMembershipExpiryReminderParams(
          libraryId: libraryId,
          studentIds: ['user-1'],
          title: customTitle,
          body: customBody,
        ),
      );

      // Assert
      verify(
        mockNotificationRepository.sendNotificationsToUsers(
          userIds: ['user-1'],
          title: customTitle,
          body: customBody,
          data: anyNamed('data'),
        ),
      ).called(1);
    });

    test('should_use_custom_daysThreshold_when_provided', () async {
      // Arrange
      when(
        mockMembershipRepository.getExpiringMemberships(
          libraryId: anyNamed('libraryId'),
          currentDate: anyNamed('currentDate'),
          daysThreshold: anyNamed('daysThreshold'),
        ),
      ).thenAnswer((_) async => const Right([]));

      // Act
      await useCase(
        SendMembershipExpiryReminderParams(
          libraryId: libraryId,
          studentIds: ['user-1'],
          daysThreshold: 5,
        ),
      );

      // Assert
      verify(
        mockMembershipRepository.getExpiringMemberships(
          libraryId: libraryId,
          currentDate: anyNamed('currentDate'),
          daysThreshold: 5, // Should use custom threshold
        ),
      ).called(1);
    });

    test('should_return_success_even_if_notification_fails', () async {
      // Arrange
      when(
        mockMembershipRepository.getExpiringMemberships(
          libraryId: anyNamed('libraryId'),
          currentDate: anyNamed('currentDate'),
          daysThreshold: anyNamed('daysThreshold'),
        ),
      ).thenAnswer((_) async => Right([expiringMembership]));

      when(
        mockNotificationRepository.sendNotificationsToUsers(
          userIds: anyNamed('userIds'),
          title: anyNamed('title'),
          body: anyNamed('body'),
          data: anyNamed('data'),
        ),
      ).thenAnswer(
        (_) async => const Left(
          InvalidMembershipDataFailure(message: 'Notification failed'),
        ),
      );

      // Act
      final result = await useCase(
        SendMembershipExpiryReminderParams(
          libraryId: libraryId,
          studentIds: ['user-1'],
        ),
      );

      // Assert
      // Should still return success (fire-and-forget pattern)
      expect(result.isRight(), true);
    });
  });

  group('SendMembershipExpiryReminderParams', () {
    test('should_have_correct_props', () {
      const params = SendMembershipExpiryReminderParams(
        libraryId: 'library-1',
        studentIds: ['user-1', 'user-2'],
        daysThreshold: 3,
        title: 'Title',
        body: 'Body',
      );

      expect(params.props, [
        'library-1',
        ['user-1', 'user-2'],
        null, // currentDate
        3,
        'Title',
        'Body',
      ]);
    });

    test('should_be_equal_with_same_values', () {
      const params1 = SendMembershipExpiryReminderParams(
        libraryId: 'library-1',
        studentIds: ['user-1'],
      );
      const params2 = SendMembershipExpiryReminderParams(
        libraryId: 'library-1',
        studentIds: ['user-1'],
      );

      expect(params1, params2);
    });
  });
}
