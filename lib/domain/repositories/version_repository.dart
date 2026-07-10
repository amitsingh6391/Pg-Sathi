import 'package:dartz/dartz.dart';

import '../core/failure.dart';

/// Repository interface for checking app version and update requirements.
abstract class VersionRepository {
  /// Fetches the minimum required version from remote config.
  /// Returns the minimum required version string (e.g., "1.0.0").
  Future<Either<Failure, String>> getMinimumRequiredVersion();

  /// Fetches whether force update is enabled.
  Future<Either<Failure, bool>> isForceUpdateEnabled();

  /// Fetches custom update message (optional).
  Future<Either<Failure, String?>> getUpdateMessage();

  /// Fetches update URL (Play Store/App Store link).
  Future<Either<Failure, String?>> getUpdateUrl();
}
