import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../core/core.dart';
import '../entities/membership.dart';
import '../failures/membership_failures.dart';
import '../repositories/membership_repository.dart';
import '../repositories/notification_repository.dart';

/// Use case for sending membership expiry reminder notifications.
/// Validates memberships and sends push notifications.
class SendMembershipExpiryReminder
    implements UseCase<void, SendMembershipExpiryReminderParams> {
  const SendMembershipExpiryReminder({
    required this.membershipRepository,
    required this.notificationRepository,
    this.daysThreshold = 7,
  });

  final MembershipRepository membershipRepository;
  final NotificationRepository notificationRepository;
  final int daysThreshold;

  @override
  Future<Either<Failure, void>> call(
    SendMembershipExpiryReminderParams params,
  ) async {
    // Validate studentIds not empty
    if (params.studentIds.isEmpty) {
      return const Left(
        InvalidMembershipDataFailure(message: 'Student IDs cannot be empty'),
      );
    }

    // Get current date
    final now = params.currentDate ?? DateTime.now();

    // Get expiring memberships for the library
    final expiringResult = await membershipRepository.getExpiringMemberships(
      libraryId: params.libraryId,
      currentDate: now,
      daysThreshold: params.daysThreshold ?? daysThreshold,
    );

    return expiringResult.fold((failure) => Left(failure), (
      expiringMemberships,
    ) async {
      // Filter to only requested student IDs
      final validMemberships = expiringMemberships
          .where((m) => params.studentIds.contains(m.userId))
          .where((m) => m.status == MembershipStatus.active)
          .toList();

      if (validMemberships.isEmpty) {
        // No valid expiring memberships found - still return success
        // (not an error, just nothing to send)
        return const Right(null);
      }

      // Extract unique user IDs (filter out nulls for unregistered memberships)
      final userIds = validMemberships
          .where((m) => m.userId != null)
          .map((m) => m.userId!)
          .toSet()
          .toList();

      // Send notifications (fire-and-forget, don't block on errors)
      final title = params.title ?? 'Membership Expiring Soon';
      final body =
          params.body ??
          'Your library membership expires in ${params.daysThreshold ?? daysThreshold} days. Please renew to continue enjoying our services.';

      // Fire-and-forget: don't await or check result
      notificationRepository.sendNotificationsToUsers(
        userIds: userIds,
        title: title,
        body: body,
        data: {
          'type': 'membership_expiry_reminder',
          'libraryId': params.libraryId,
          'daysThreshold': params.daysThreshold ?? daysThreshold,
        },
      );

      // Return success immediately (fire-and-forget pattern)
      return const Right(null);
    });
  }
}

/// Parameters for SendMembershipExpiryReminder use case.
class SendMembershipExpiryReminderParams extends Equatable {
  const SendMembershipExpiryReminderParams({
    required this.libraryId,
    required this.studentIds,
    this.currentDate,
    this.daysThreshold,
    this.title,
    this.body,
  });

  final String libraryId;
  final List<String> studentIds;
  final DateTime? currentDate;
  final int? daysThreshold;
  final String? title;
  final String? body;

  @override
  List<Object?> get props => [
    libraryId,
    studentIds,
    currentDate,
    daysThreshold,
    title,
    body,
  ];
}
