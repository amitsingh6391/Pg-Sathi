import 'package:dartz/dartz.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../domain/core/failure.dart';
import '../failures/data_failures.dart';

/// Service to get device-specific information.
class DeviceInfoService {
  DeviceInfoService({
    DeviceInfoPlugin? deviceInfo,
    SharedPreferences? sharedPreferences,
  }) : _deviceInfo = deviceInfo ?? DeviceInfoPlugin(),
       _sharedPreferences = sharedPreferences,
       _uuid = const Uuid();

  final DeviceInfoPlugin _deviceInfo;
  final SharedPreferences? _sharedPreferences;
  final Uuid _uuid;

  static const String _webDeviceIdKey = 'web_device_id';

  /// Gets a unique device identifier.
  Future<Either<Failure, String>> getDeviceId() async {
    try {
      if (kIsWeb) {
        return await _getWebDeviceId();
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await _deviceInfo.androidInfo;
        // Use Android ID as device identifier
        return Right(androidInfo.id);
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        // Use identifierForVendor as device identifier
        return Right(iosInfo.identifierForVendor ?? 'unknown-ios-device');
      } else {
        return const Left(UnknownFailure(message: 'Unsupported platform'));
      }
    } catch (e) {
      return Left(UnknownFailure(message: 'Failed to get device ID: $e'));
    }
  }

  /// Gets or creates a persistent device ID for web platform.
  Future<Either<Failure, String>> _getWebDeviceId() async {
    final prefs = _sharedPreferences;

    try {
      // Try to get existing device ID from SharedPreferences
      if (prefs != null) {
        final existingId = prefs.getString(_webDeviceIdKey);
        if (existingId != null && existingId.isNotEmpty) {
          return Right(existingId);
        }
      }

      // Generate a new device ID for web
      // Combine browser info with a UUID for uniqueness
      final webInfo = await _deviceInfo.webBrowserInfo;
      final browserName = webInfo.browserName.name;
      final platform = webInfo.platform ?? 'unknown';

      // Generate a unique ID combining browser info and UUID
      final deviceId = 'web-$browserName-$platform-${_uuid.v4()}';

      // Store it for future use
      if (prefs != null) {
        await prefs.setString(_webDeviceIdKey, deviceId);
      }

      return Right(deviceId);
    } catch (e) {
      // Fallback: generate a UUID-based device ID without browser info
      final fallbackId = 'web-${_uuid.v4()}';

      // Try to store it
      if (prefs != null) {
        try {
          await prefs.setString(_webDeviceIdKey, fallbackId);
        } catch (_) {
          // Ignore storage errors, return the ID anyway
        }
      }

      return Right(fallbackId);
    }
  }
}
