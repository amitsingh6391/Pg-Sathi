import 'package:dartz/dartz.dart';

import '../core/failure.dart';
import '../entities/fcm_token.dart';

/// Repository interface for sending push notifications.
/// Framework-agnostic abstraction.
abstract class NotificationRepository {
  /// Saves or updates FCM token for a user.
  Future<Either<Failure, void>> saveFcmToken({
    required String userId,
    required String token,
    String? platform,
  });

  /// Gets FCM token for a single user.
  Future<Either<Failure, FcmToken?>> getFcmToken(String userId);

  /// Gets FCM tokens for multiple users in batch.
  Future<Either<Failure, Map<String, FcmToken>>> getFcmTokens(
    List<String> userIds,
  );

  /// Sends a push notification to a single FCM token.
  /// Returns success even if token is invalid (fire-and-forget).
  Future<Either<Failure, void>> sendNotificationToToken({
    required String token,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  });

  /// Sends push notifications to multiple FCM tokens in batch.
  /// Returns success even if some tokens are invalid.
  Future<Either<Failure, void>> sendNotificationsToTokens({
    required List<String> tokens,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  });

  /// Sends a push notification to a single user by their user ID.
  /// Fetches token and sends notification.
  Future<Either<Failure, void>> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  });

  /// Sends push notifications to multiple users in batch.
  /// Fetches tokens and sends notifications.
  Future<Either<Failure, void>> sendNotificationsToUsers({
    required List<String> userIds,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  });
}
