import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../core/core.dart';
import '../repositories/admin_analytics_repository.dart';
import '../repositories/notification_repository.dart';

/// Use case for sending broadcast notifications from admin.
/// Can target all owners, all students, or specific libraries.
class SendAdminBroadcastNotification
    implements UseCase<int, SendAdminBroadcastParams> {
  const SendAdminBroadcastNotification({
    required this.analyticsRepository,
    required this.notificationRepository,
  });

  final AdminAnalyticsRepository analyticsRepository;
  final NotificationRepository notificationRepository;

  @override
  Future<Either<Failure, int>> call(SendAdminBroadcastParams params) async {
    // Get target user IDs based on audience
    List<String> userIds = [];

    switch (params.audience) {
      case BroadcastAudience.allOwners:
        final result = await analyticsRepository.getAllOwnerIds();
        if (result.isLeft()) {
          return Left(result.fold((l) => l, (_) => const GenericFailure()));
        }
        userIds = result.getOrElse(() => []);

      case BroadcastAudience.ownersWithLibrary:
        final result = await analyticsRepository.getOwnerIdsWithLibrary();
        if (result.isLeft()) {
          return Left(result.fold((l) => l, (_) => const GenericFailure()));
        }
        userIds = result.getOrElse(() => []);

      case BroadcastAudience.ownersWithoutLibrary:
        final result = await analyticsRepository.getOwnerIdsWithoutLibrary();
        if (result.isLeft()) {
          return Left(result.fold((l) => l, (_) => const GenericFailure()));
        }
        userIds = result.getOrElse(() => []);

      case BroadcastAudience.allStudents:
        final result = await analyticsRepository.getAllStudentIds();
        if (result.isLeft()) {
          return Left(result.fold((l) => l, (_) => const GenericFailure()));
        }
        userIds = result.getOrElse(() => []);

      case BroadcastAudience.studentsWithActiveMembership:
        final result = await analyticsRepository.getStudentIdsWithActiveMembership();
        if (result.isLeft()) {
          return Left(result.fold((l) => l, (_) => const GenericFailure()));
        }
        userIds = result.getOrElse(() => []);

      case BroadcastAudience.activeStudents:
        final result = await analyticsRepository.getActiveStudentIds();
        if (result.isLeft()) {
          return Left(result.fold((l) => l, (_) => const GenericFailure()));
        }
        userIds = result.getOrElse(() => []);

      case BroadcastAudience.selectedLibraries:
        if (params.libraryIds == null || params.libraryIds!.isEmpty) {
          return const Left(
            GenericFailure(message: 'Library IDs required for this audience'),
          );
        }
        final result = await analyticsRepository.getOwnerIdsForLibraries(
          params.libraryIds!,
        );
        if (result.isLeft()) {
          return Left(result.fold((l) => l, (_) => const GenericFailure()));
        }
        userIds = result.getOrElse(() => []);

      case BroadcastAudience.selectedLibraryStudents:
        if (params.libraryIds == null || params.libraryIds!.isEmpty) {
          return const Left(
            GenericFailure(message: 'Library IDs required for this audience'),
          );
        }
        final result = await analyticsRepository.getStudentIdsForLibraries(
          params.libraryIds!,
        );
        if (result.isLeft()) {
          return Left(result.fold((l) => l, (_) => const GenericFailure()));
        }
        userIds = result.getOrElse(() => []);
    }

    if (userIds.isEmpty) {
      return const Right(0);
    }

    // Send notifications
    final result = await notificationRepository.sendNotificationsToUsers(
      userIds: userIds,
      title: params.title,
      body: params.body,
      data: params.data,
    );

    return result.fold(
      (failure) => Left(failure),
      (_) => Right(userIds.length),
    );
  }
}

/// Parameters for broadcast notification.
class SendAdminBroadcastParams extends Equatable {
  const SendAdminBroadcastParams({
    required this.title,
    required this.body,
    required this.audience,
    this.libraryIds,
    this.data,
  });

  /// Notification title.
  final String title;

  /// Notification body.
  final String body;

  /// Target audience.
  final BroadcastAudience audience;

  /// Library IDs (required if audience is selectedLibraries).
  final List<String>? libraryIds;

  /// Additional data payload.
  final Map<String, dynamic>? data;

  @override
  List<Object?> get props => [title, body, audience, libraryIds, data];
}

/// Broadcast audience options.
enum BroadcastAudience {
  /// Send to all library owners.
  allOwners,

  /// Send to owners who already created a library.
  ownersWithLibrary,

  /// Send to owners who have not set up a library yet.
  ownersWithoutLibrary,

  /// Send to all students.
  allStudents,

  /// Send only to students with an active membership / linked library.
  studentsWithActiveMembership,

  /// Send only to students recently active in the app (attendance-based).
  activeStudents,

  /// Send to owners of selected libraries.
  selectedLibraries,

  /// Send to students of selected libraries.
  selectedLibraryStudents,
}

/// Generic failure for use case errors.
class GenericFailure extends Failure {
  const GenericFailure({super.message});
}
