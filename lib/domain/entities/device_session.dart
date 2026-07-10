import 'package:equatable/equatable.dart';

/// Represents an active device session for a user.
/// Tracks device-specific login information for security purposes.
class DeviceSession extends Equatable {
  const DeviceSession({
    required this.id,
    required this.userId,
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.loginTime,
    required this.lastActiveTime,
    this.isRevoked = false,
    this.ipAddress,
    this.location,
    this.browser,
    this.osVersion,
    this.fcmToken,
  });

  /// Unique session identifier.
  final String id;

  /// User ID who owns this session.
  final String userId;

  /// Unique device identifier.
  final String deviceId;

  /// Human-readable device name (e.g., "iPhone 14 Pro", "Chrome on Windows").
  final String deviceName;

  /// Platform (iOS, Android, Web, macOS, Windows, Linux).
  final String platform;

  /// When the user logged in from this device.
  final DateTime loginTime;

  /// Last time this device was active.
  final DateTime lastActiveTime;

  /// Whether this session has been revoked/logged out.
  final bool isRevoked;

  /// IP address (optional).
  final String? ipAddress;

  /// Location (optional, e.g., "Mumbai, India").
  final String? location;

  /// Browser name (for web sessions).
  final String? browser;

  /// OS version.
  final String? osVersion;

  /// FCM token for push notifications.
  final String? fcmToken;

  /// Whether this session is currently active (within last 30 days and not revoked).
  bool get isActive {
    if (isRevoked) return false;
    final now = DateTime.now();
    final difference = now.difference(lastActiveTime);
    return difference.inDays < 30;
  }

  /// Time since last active (human-readable).
  String get timeSinceActive {
    final now = DateTime.now();
    final difference = now.difference(lastActiveTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}w ago';
    } else {
      return '${(difference.inDays / 30).floor()}mo ago';
    }
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        deviceId,
        deviceName,
        platform,
        loginTime,
        lastActiveTime,
        isRevoked,
        ipAddress,
        location,
        browser,
        osVersion,
        fcmToken,
      ];

  DeviceSession copyWith({
    String? id,
    String? userId,
    String? deviceId,
    String? deviceName,
    String? platform,
    DateTime? loginTime,
    DateTime? lastActiveTime,
    bool? isRevoked,
    String? ipAddress,
    String? location,
    String? browser,
    String? osVersion,
    String? fcmToken,
  }) {
    return DeviceSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      platform: platform ?? this.platform,
      loginTime: loginTime ?? this.loginTime,
      lastActiveTime: lastActiveTime ?? this.lastActiveTime,
      isRevoked: isRevoked ?? this.isRevoked,
      ipAddress: ipAddress ?? this.ipAddress,
      location: location ?? this.location,
      browser: browser ?? this.browser,
      osVersion: osVersion ?? this.osVersion,
      fcmToken: fcmToken ?? this.fcmToken,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'platform': platform,
      'loginTime': loginTime.toIso8601String(),
      'lastActiveTime': lastActiveTime.toIso8601String(),
      'isRevoked': isRevoked,
      if (ipAddress != null) 'ipAddress': ipAddress,
      if (location != null) 'location': location,
      if (browser != null) 'browser': browser,
      if (osVersion != null) 'osVersion': osVersion,
      if (fcmToken != null) 'fcmToken': fcmToken,
    };
  }

  factory DeviceSession.fromJson(String id, Map<String, dynamic> json) {
    return DeviceSession(
      id: id,
      userId: json['userId'] as String,
      deviceId: json['deviceId'] as String,
      deviceName: json['deviceName'] as String,
      platform: json['platform'] as String,
      loginTime: DateTime.parse(json['loginTime'] as String),
      lastActiveTime: DateTime.parse(json['lastActiveTime'] as String),
      isRevoked: json['isRevoked'] as bool? ?? false,
      ipAddress: json['ipAddress'] as String?,
      location: json['location'] as String?,
      browser: json['browser'] as String?,
      osVersion: json['osVersion'] as String?,
      fcmToken: json['fcmToken'] as String?,
    );
  }
}
