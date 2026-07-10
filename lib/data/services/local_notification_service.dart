import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Callback type for handling notification taps with parsed data.
typedef NotificationTapCallback = void Function(Map<String, dynamic> data);

/// Service for displaying local notifications.
/// Handles foreground notifications on both Android and iOS.
class LocalNotificationService {
  LocalNotificationService() {
    _initialize();
  }

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// Global callback for notification taps. Set from main.dart or app startup.
  static NotificationTapCallback? onNotificationTap;

  /// Initializes the local notifications plugin.
  Future<void> _initialize() async {
    if (kIsWeb) {
      // Local notifications not supported on web
      return;
    }

    // Android initialization settings
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // iOS initialization settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions on iOS
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }

    // Request permissions on Android 13+
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }
  }

  /// Handles notification tap events.
  /// Parses the payload and delegates to the registered callback.
  static void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    try {
      // Payload is stored as JSON string
      final data = jsonDecode(payload) as Map<String, dynamic>;
      onNotificationTap?.call(data);
    } catch (_) {
      // Legacy format or unparseable payload — ignore gracefully
    }
  }

  /// Displays a notification from a Firebase RemoteMessage.
  /// This is called when a notification is received in the foreground.
  Future<void> showNotification(RemoteMessage message) async {
    if (kIsWeb) {
      return;
    }

    final notification = message.notification;
    if (notification == null) {
      return;
    }

    final androidDetails = AndroidNotificationDetails(
      'default', // Channel ID (must match MainActivity.kt)
      'Default Notifications', // Channel name
      channelDescription: 'Default notification channel for PG Sathi',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Use messageId as notification ID to avoid duplicates
    final notificationId =
        message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch;

    // Serialize data as JSON for reliable parsing on tap
    final payload = message.data.isNotEmpty
        ? jsonEncode(message.data)
        : null;

    await _notifications.show(
      notificationId,
      notification.title,
      notification.body,
      details,
      payload: payload,
    );
  }

  /// Creates the notification channel for Android.
  /// This should be called on app startup (handled by MainActivity.kt).
  /// Kept here for reference and potential manual channel creation.
  static Future<void> createNotificationChannel() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    const androidChannel = AndroidNotificationChannel(
      'default', // Channel ID
      'Default Notifications', // Channel name
      description: 'Default notification channel for PG Sathi',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(androidChannel);
  }
}
