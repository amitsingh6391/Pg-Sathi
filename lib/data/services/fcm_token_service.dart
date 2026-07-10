import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../domain/repositories/notification_repository.dart';
import 'local_notification_service.dart';

/// Service for managing FCM token synchronization.
/// Handles token registration, refresh, and saving to Firestore.
class FcmTokenService {
  FcmTokenService({
    required this.messaging,
    required this.notificationRepository,
    LocalNotificationService? localNotificationService,
  }) : _localNotificationService = localNotificationService {
    _setupTokenRefreshListener();
    _setupForegroundMessageListener();
  }

  final FirebaseMessaging messaging;
  final NotificationRepository notificationRepository;
  final LocalNotificationService? _localNotificationService;

  /// Whether FCM is supported on the current platform.
  bool get _isSupported {
    return !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android);
  }

  /// Whether the current platform is iOS.
  bool get _isIOS {
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// Initializes FCM and requests permissions.
  /// Should be called on app start.
  /// On unsupported platforms (e.g., web), this is a no-op.
  Future<void> initialize() async {
    if (!_isSupported) {
      // FCM is not supported on web platform
      return;
    }

    // Request notification permissions (iOS)
    if (_isIOS) {
      try {
        final settings = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
        if (settings.authorizationStatus != AuthorizationStatus.authorized) {
          return;
        }

        // On iOS, we need to wait for APNS token before getting FCM token
        // Note: This requires Push Notifications capability (paid Apple Developer account)
        // For free accounts, this will fail gracefully
        try {
          // Request APNS token first
          final apnsToken = await messaging.getAPNSToken();
          if (apnsToken == null) {
            // Set up listener for when APNS token becomes available
            _setupApnsTokenListener();
            return;
          }
        } catch (e) {
          // Gracefully handle if Push Notifications capability is not available
          // (e.g., free Apple Developer account)
          if (e.toString().contains('aps-environment') ||
              e.toString().contains('entitlement')) {
            return;
          }
          // Set up listener to retry when APNS token becomes available
          _setupApnsTokenListener();
          return;
        }
      } catch (e) {
        // Continue anyway - Android will still work
        return;
      }
    }

    // Get initial token (after APNS token is available on iOS)
    // Use currently logged-in user if available — ensures token is saved
    // even when initialize() runs before syncTokenForUser() is called.
    final currentUser = FirebaseAuth.instance.currentUser;
    await _syncToken(userId: currentUser?.uid);
  }

  /// Sets up listener for APNS token availability on iOS.
  void _setupApnsTokenListener() {
    if (!_isIOS) return;

    // Poll for APNS token (Firebase Messaging doesn't have a direct listener)
    Future.delayed(const Duration(seconds: 2), () async {
      try {
        final apnsToken = await messaging.getAPNSToken();
        if (apnsToken != null) {
          await _syncToken();
        } else {
          // Retry after another delay
          _setupApnsTokenListener();
        }
      } catch (e) {
        // Retry after another delay
        _setupApnsTokenListener();
      }
    });
  }

  /// Syncs FCM token for the current user.
  /// Should be called after login or when user changes.
  Future<void> syncTokenForUser(String userId) async {
    await _syncToken(userId: userId);
  }

  /// Sets up listener for token refresh.
  /// When FCM token refreshes, saves it for the currently logged-in user.
  void _setupTokenRefreshListener() {
    messaging.onTokenRefresh.listen((newToken) async {
      // Get current logged-in user
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        // Save token for the current user
        await _saveToken(newToken, userId: currentUser.uid);
      }
    });
  }

  /// Sets up listener for foreground messages.
  /// Displays notifications using LocalNotificationService when app is in foreground.
  /// On iOS, notifications are also handled by AppDelegate's willPresent method.
  void _setupForegroundMessageListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      // Display notification using local notification service
      // This ensures notifications appear even when app is in foreground
      final localNotificationService = _localNotificationService;
      if (localNotificationService != null) {
        await localNotificationService.showNotification(message);
      }

      // You can add custom handling here, such as:
      // - Updating UI state
      // - Navigating to a specific screen based on message data
      // Example: Navigate based on notification data
      // if (message.data.containsKey('screen')) {
      //   // Navigate to specific screen
      // }
    });
  }

  /// Syncs current FCM token to Firestore.
  Future<void> _syncToken({String? userId}) async {
    if (!_isSupported) {
      return;
    }

    try {
      // On iOS, ensure APNS token is available first
      // Skip gracefully if Push Notifications capability is not available
      if (_isIOS) {
        try {
          final apnsToken = await messaging.getAPNSToken();
          if (apnsToken == null) {
            return;
          }
        } catch (e) {
          // Gracefully handle if capability is not available (free Apple Developer account)
          if (e.toString().contains('aps-environment') ||
              e.toString().contains('entitlement')) {
            return;
          }
          return;
        }
      }

      final token = await messaging.getToken();
      if (token != null && userId != null) {
        await _saveToken(token, userId: userId);
      }
    } catch (e) {
      // On iOS, if APNS token error, don't retry immediately
      if (_isIOS) {
        // Silently handle APNS token errors
      }
    }
  }

  /// Saves FCM token to Firestore.
  Future<void> _saveToken(String token, {String? userId}) async {
    if (userId == null) {
      // No user logged in yet - token will be saved on login
      return;
    }

    try {
      final platform = _getPlatform();
      final result = await notificationRepository.saveFcmToken(
        userId: userId,
        token: token,
        platform: platform,
      );

      // Silently handle result
      result.fold(
        (failure) => null,
        (_) => null,
      );
    } catch (e) {
      // Silently handle error
    }
  }

  /// Gets platform identifier.
  String _getPlatform() {
    if (kIsWeb) return 'web';
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    return 'unknown';
  }
}
