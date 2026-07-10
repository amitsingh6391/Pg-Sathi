import 'package:dartz/dartz.dart';

import '../core/failure.dart';
import '../entities/device_session.dart';

/// Repository interface for device session management.
abstract class DeviceSessionRepository {
  /// Get all active device sessions for a user.
  Future<Either<Failure, List<DeviceSession>>> getUserDeviceSessions(
    String userId,
  );

  /// Logout/terminate a specific device session.
  Future<Either<Failure, void>> logoutDeviceSession({
    required String userId,
    required String sessionId,
  });

  /// Logout from all devices except the current one.
  Future<Either<Failure, void>> logoutAllOtherDevices({
    required String userId,
    required String currentDeviceId,
  });

  /// Create or update current device session.
  Future<Either<Failure, void>> updateDeviceSession({
    required String userId,
    required String deviceId,
    required String deviceName,
    required String platform,
    String? browser,
    String? osVersion,
    String? fcmToken,
  });

  /// Check if the current device session is revoked.
  Future<Either<Failure, bool>> isDeviceSessionRevoked({
    required String userId,
    required String deviceId,
  });
}
