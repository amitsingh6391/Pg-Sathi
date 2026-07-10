import 'package:dartz/dartz.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

import '../../domain/core/failure.dart';
import '../../domain/repositories/version_repository.dart';
import '../utils/firebase_error_handler.dart';

/// Firebase Remote Config implementation of VersionRepository.
class VersionRepositoryImpl implements VersionRepository {
  VersionRepositoryImpl({required this.remoteConfig}) {
    _initializeRemoteConfig();
  }

  final FirebaseRemoteConfig remoteConfig;
  bool _isInitialized = false;

  /// Initializes and fetches Remote Config values.
  Future<void> _initializeRemoteConfig() async {
    if (_isInitialized) return;

    try {
      // Fetch and activate remote config
      await remoteConfig.fetchAndActivate();
      _isInitialized = true;
    } catch (e) {
      // Continue with defaults if fetch fails
      _isInitialized = true;
    }
  }

  /// Ensures Remote Config is initialized before reading values.
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await _initializeRemoteConfig();
    }
  }

  @override
  Future<Either<Failure, String>> getMinimumRequiredVersion() async {
    await _ensureInitialized();

    return FirebaseErrorHandler.guard(() async {
      final minVersion = remoteConfig.getString('minimum_required_version');

      // Return the value (even if empty, as it might be intentionally set)
      return minVersion.isEmpty ? '0.0.0' : minVersion;
    });
  }

  @override
  Future<Either<Failure, bool>> isForceUpdateEnabled() async {
    await _ensureInitialized();

    return FirebaseErrorHandler.guard(() async {
      final enabled = remoteConfig.getBool('force_update_enabled');
      return enabled;
    });
  }

  @override
  Future<Either<Failure, String?>> getUpdateMessage() async {
    await _ensureInitialized();

    return FirebaseErrorHandler.guard(() async {
      final message = remoteConfig.getString('update_message');
      return message.isEmpty ? null : message;
    });
  }

  @override
  Future<Either<Failure, String?>> getUpdateUrl() async {
    await _ensureInitialized();

    return FirebaseErrorHandler.guard(() async {
      final url = remoteConfig.getString('update_url');
      return url.isEmpty ? null : url;
    });
  }
}
