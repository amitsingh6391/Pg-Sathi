import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Service for handling crash reporting and error logging.
/// Wraps Firebase Crashlytics functionality.
/// Note: Crashlytics is only available on iOS and Android platforms.
class CrashlyticsService {
  CrashlyticsService({this.crashlytics});

  final FirebaseCrashlytics? crashlytics;

  /// Whether Crashlytics is supported on the current platform.
  bool get _isSupported {
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;
  }

  Future<void> initialize() async {
    if (!_isSupported || crashlytics == null) {
      // Crashlytics is not supported on web platform or not available
      return;
    }

    try {
      // Enable Crashlytics only in release mode
      if (kReleaseMode) {
        await crashlytics!.setCrashlyticsCollectionEnabled(true);
      } else {
        // Disable in debug mode to avoid cluttering logs
        await crashlytics!.setCrashlyticsCollectionEnabled(false);
      }

      // Pass all uncaught errors to Crashlytics
      FlutterError.onError = (errorDetails) {
        if (_isSupported && crashlytics != null) {
          crashlytics!.recordFlutterFatalError(errorDetails);
        }
      };

      // Pass all uncaught asynchronous errors to Crashlytics
      PlatformDispatcher.instance.onError = (error, stack) {
        if (_isSupported && crashlytics != null) {
          crashlytics!.recordError(error, stack, fatal: true);
        }
        return true;
      };
    } catch (e) {
      // Silently fail if Crashlytics initialization fails
      // This can happen on unsupported platforms or misconfigured environments
      if (kDebugMode) {
        debugPrint('Crashlytics initialization failed: $e');
      }
    }
  }

  /// Records a non-fatal error.
  /// On unsupported platforms, this is a no-op.
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
    Map<String, dynamic>? additionalData,
  }) async {
    if (!_isSupported || crashlytics == null) {
      return;
    }

    try {
      await crashlytics!.recordError(
        error,
        stackTrace,
        reason: reason,
        fatal: fatal,
      );
      // Log additional data as custom keys
      if (additionalData != null) {
        for (final entry in additionalData.entries) {
          await setCustomKey(entry.key, entry.value);
        }
      }
    } catch (e) {
      // Silently fail if recording fails
      if (kDebugMode) {
        debugPrint('Crashlytics recordError failed: $e');
      }
    }
  }

  /// Logs a custom message.
  /// On unsupported platforms, this is a no-op.
  void log(String message) {
    if (!_isSupported || crashlytics == null) {
      return;
    }

    try {
      crashlytics!.log(message);
    } catch (e) {
      // Silently fail if logging fails
      if (kDebugMode) {
        debugPrint('Crashlytics log failed: $e');
      }
    }
  }

  /// Sets a custom key-value pair for crash reports.
  /// On unsupported platforms, this is a no-op.
  Future<void> setCustomKey(String key, dynamic value) async {
    if (!_isSupported || crashlytics == null) {
      return;
    }

    try {
      await crashlytics!.setCustomKey(key, value);
    } catch (e) {
      // Silently fail if setting custom key fails
      if (kDebugMode) {
        debugPrint('Crashlytics setCustomKey failed: $e');
      }
    }
  }

  /// Sets user identifier for crash reports.
  /// On unsupported platforms, this is a no-op.
  Future<void> setUserId(String userId) async {
    if (!_isSupported || crashlytics == null) {
      return;
    }

    try {
      await crashlytics!.setUserIdentifier(userId);
    } catch (e) {
      // Silently fail if setting user ID fails
      if (kDebugMode) {
        debugPrint('Crashlytics setUserId failed: $e');
      }
    }
  }

  /// Clears user identifier (e.g., on logout).
  /// On unsupported platforms, this is a no-op.
  Future<void> clearUserIdentifier() async {
    if (!_isSupported || crashlytics == null) {
      return;
    }

    try {
      await crashlytics!.setUserIdentifier('');
    } catch (e) {
      // Silently fail if clearing user ID fails
      if (kDebugMode) {
        debugPrint('Crashlytics clearUserIdentifier failed: $e');
      }
    }
  }
}
