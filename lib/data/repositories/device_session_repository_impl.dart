import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';

import '../../domain/core/failure.dart';
import '../../domain/entities/device_session.dart';
import '../../domain/repositories/device_session_repository.dart';
import '../failures/data_failures.dart';

/// Implementation of device session repository using Firestore.
class DeviceSessionRepositoryImpl implements DeviceSessionRepository {
  const DeviceSessionRepositoryImpl(this.firestore);

  final FirebaseFirestore firestore;

  @override
  Future<Either<Failure, List<DeviceSession>>> getUserDeviceSessions(
    String userId,
  ) async {
    try {
      final snapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('device_sessions')
          .where('isRevoked', isEqualTo: false)
          .orderBy('lastActiveTime', descending: true)
          .limit(20)
          .get();

      final sessions = snapshot.docs
          .map((doc) => DeviceSession.fromJson(doc.id, doc.data()))
          .toList();

      return Right(sessions);
    } catch (e) {
      return Left(
        ServerFailure(message: 'Failed to fetch device sessions: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, void>> logoutDeviceSession({
    required String userId,
    required String sessionId,
  }) async {
    try {
      // Mark session as revoked instead of deleting
      await firestore
          .collection('users')
          .doc(userId)
          .collection('device_sessions')
          .doc(sessionId)
          .update({'isRevoked': true});

      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to logout device: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> logoutAllOtherDevices({
    required String userId,
    required String currentDeviceId,
  }) async {
    try {
      final batch = firestore.batch();
      final snapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('device_sessions')
          .where('deviceId', isNotEqualTo: currentDeviceId)
          .get();

      for (final doc in snapshot.docs) {
        // Mark as revoked instead of deleting
        batch.update(doc.reference, {'isRevoked': true});
      }

      await batch.commit();
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to logout all devices: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> updateDeviceSession({
    required String userId,
    required String deviceId,
    required String deviceName,
    required String platform,
    String? browser,
    String? osVersion,
    String? fcmToken,
  }) async {
    try {
      final now = DateTime.now();
      final sessionsRef = firestore
          .collection('users')
          .doc(userId)
          .collection('device_sessions');

      // Check if session already exists for this device
      final existingSession = await sessionsRef
          .where('deviceId', isEqualTo: deviceId)
          .limit(1)
          .get();

      if (existingSession.docs.isNotEmpty) {
        // Update existing session and reset revoked status
        await existingSession.docs.first.reference.update({
          'lastActiveTime': now.toIso8601String(),
          'isRevoked': false, // Reset revoked status on login
          if (fcmToken != null) 'fcmToken': fcmToken,
        });
      } else {
        // Create new session
        final session = DeviceSession(
          id: sessionsRef.doc().id,
          userId: userId,
          deviceId: deviceId,
          deviceName: deviceName,
          platform: platform,
          loginTime: now,
          lastActiveTime: now,
          browser: browser,
          osVersion: osVersion,
          fcmToken: fcmToken,
        );

        await sessionsRef.doc(session.id).set(session.toJson());
      }

      return const Right(null);
    } catch (e) {
      return Left(
        ServerFailure(message: 'Failed to update device session: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, bool>> isDeviceSessionRevoked({
    required String userId,
    required String deviceId,
  }) async {
    try {
      final snapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('device_sessions')
          .where('deviceId', isEqualTo: deviceId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        // No session found, not revoked
        return const Right(false);
      }

      final doc = snapshot.docs.first;
      final isRevoked = doc.data()['isRevoked'] as bool? ?? false;
      return Right(isRevoked);
    } catch (e) {
      return Left(
        ServerFailure(message: 'Failed to check session status: $e'),
      );
    }
  }
}
