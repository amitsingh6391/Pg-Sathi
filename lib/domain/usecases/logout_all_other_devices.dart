import 'package:dartz/dartz.dart';

import '../core/failure.dart';
import '../repositories/device_session_repository.dart';

/// Use case to logout from all devices except the current one.
class LogoutAllOtherDevices {
  const LogoutAllOtherDevices(this.repository);

  final DeviceSessionRepository repository;

  Future<Either<Failure, void>> call({
    required String userId,
    required String currentDeviceId,
  }) async {
    return await repository.logoutAllOtherDevices(
      userId: userId,
      currentDeviceId: currentDeviceId,
    );
  }
}
