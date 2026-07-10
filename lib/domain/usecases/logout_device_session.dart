import 'package:dartz/dartz.dart';

import '../core/failure.dart';
import '../repositories/device_session_repository.dart';

/// Use case to logout/terminate a specific device session.
class LogoutDeviceSession {
  const LogoutDeviceSession(this.repository);

  final DeviceSessionRepository repository;

  Future<Either<Failure, void>> call({
    required String userId,
    required String sessionId,
  }) async {
    return await repository.logoutDeviceSession(
      userId: userId,
      sessionId: sessionId,
    );
  }
}
