import 'package:dartz/dartz.dart';

import '../core/failure.dart';
import '../entities/device_session.dart';
import '../repositories/device_session_repository.dart';

/// Use case to get all active device sessions for a user.
class GetUserDeviceSessions {
  const GetUserDeviceSessions(this.repository);

  final DeviceSessionRepository repository;

  Future<Either<Failure, List<DeviceSession>>> call(String userId) async {
    return await repository.getUserDeviceSessions(userId);
  }
}
