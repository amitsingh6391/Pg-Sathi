import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../domain/core/failure.dart';
import '../../domain/entities/fcm_token.dart';
import '../../domain/repositories/notification_repository.dart';
import '../models/fcm_token_dto.dart';
import '../utils/firebase_error_handler.dart';

/// Firebase implementation of NotificationRepository.
/// Manages FCM tokens and sends notification requests to Cloud Functions.
class NotificationRepositoryImpl implements NotificationRepository {
  NotificationRepositoryImpl({
    required this.firestore,
    required this.messaging,
  });

  final FirebaseFirestore firestore;
  final FirebaseMessaging messaging;

  CollectionReference<Map<String, dynamic>> get _tokensCollection =>
      firestore.collection(FcmTokenDto.collectionName);

  @override
  Future<Either<Failure, void>> saveFcmToken({
    required String userId,
    required String token,
    String? platform,
  }) async {
    return FirebaseErrorHandler.guard(() async {
      // Use set with merge to avoid overwriting if token already exists
      await _tokensCollection.doc(userId).set({
        'token': token,
        if (platform != null) 'platform': platform,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  @override
  Future<Either<Failure, FcmToken?>> getFcmToken(String userId) async {
    return FirebaseErrorHandler.guard(() async {
      final doc = await _tokensCollection.doc(userId).get();
      if (!doc.exists) {
        return null;
      }
      final dto = FcmTokenDto.fromFirestore(doc);
      return FcmTokenMapper.toEntity(dto);
    });
  }

  @override
  Future<Either<Failure, Map<String, FcmToken>>> getFcmTokens(
    List<String> userIds,
  ) async {
    return FirebaseErrorHandler.guard(() async {
      if (userIds.isEmpty) {
        return <String, FcmToken>{};
      }

      // Firestore has a limit of 10 items per 'in' query
      // Fetch all batches in parallel for speed
      const batchSize = 10;
      final Map<String, FcmToken> tokensMap = {};
      
      final futures = <Future<void>>[];

      for (var i = 0; i < userIds.length; i += batchSize) {
        final batch = userIds.skip(i).take(batchSize).toList();
        
        futures.add(
          _tokensCollection
              .where(FieldPath.documentId, whereIn: batch)
              .get()
              .then((query) {
            for (final doc in query.docs) {
              final dto = FcmTokenDto.fromFirestore(doc);
              tokensMap[doc.id] = FcmTokenMapper.toEntity(dto);
            }
          })
        );
      }
      
      // Wait for all queries to complete in parallel
      await Future.wait(futures);

      return tokensMap;
    });
  }

  @override
  Future<Either<Failure, void>> sendNotificationToToken({
    required String token,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    return sendNotificationsToTokens(
      tokens: [token],
      title: title,
      body: body,
      data: data,
    );
  }

  @override
  Future<Either<Failure, void>> sendNotificationsToTokens({
    required List<String> tokens,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    // Fire-and-forget pattern: store requests for Cloud Function to process
    return FirebaseErrorHandler.guard(() async {
      if (tokens.isEmpty) {
        return;
      }

      // Filter out empty tokens
      final validTokens = tokens.where((t) => t.isNotEmpty).toList();
      if (validTokens.isEmpty) {
        return;
      }
      
      // Firestore batch limit is 500 operations
      // Split into batches and commit in parallel for faster performance
      const batchSize = 500;
      final requestsRef = firestore.collection('notification_requests');
      final batches = <WriteBatch>[];

      for (var i = 0; i < validTokens.length; i += batchSize) {
        final batch = firestore.batch();
        final tokenBatch = validTokens.skip(i).take(batchSize).toList();

        for (final token in tokenBatch) {
          final requestDoc = requestsRef.doc();
          batch.set(requestDoc, {
            'token': token,
            'title': title,
            'body': body,
            'data': data ?? {},
            'createdAt': FieldValue.serverTimestamp(),
            'status': 'pending',
            'type': data?['type'] ?? 'general',
          });
        }

        batches.add(batch);
      }

      // Commit all batches in parallel for maximum speed
      await Future.wait(batches.map((batch) => batch.commit()));
    });
  }

  @override
  Future<Either<Failure, void>> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    // Get token first
    final tokenResult = await getFcmToken(userId);

    return tokenResult.fold((failure) => Left(failure), (token) async {
      if (token == null) {
        // No token - still return success (fire-and-forget)
        return const Right(null);
      }
      return sendNotificationToToken(
        token: token.token,
        title: title,
        body: body,
        data: data,
      );
    });
  }

  @override
  Future<Either<Failure, void>> sendNotificationsToUsers({
    required List<String> userIds,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    // Get tokens first
    final tokensResult = await getFcmTokens(userIds);

    return tokensResult.fold((failure) {
      return Left(failure);
    }, (tokensMap) async {
      if (tokensMap.isEmpty) {
        // No tokens - still return success (fire-and-forget)
        return const Right(null);
      }

      final tokens = tokensMap.values.map((t) => t.token).toList();
      
      return sendNotificationsToTokens(
        tokens: tokens,
        title: title,
        body: body,
        data: data,
      );
    });
  }
}
