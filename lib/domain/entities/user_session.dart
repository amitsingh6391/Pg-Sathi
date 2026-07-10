import 'package:equatable/equatable.dart';
import 'package:pg_manager/domain/entities/user.dart';

/// Represents an actual app usage session by a user.
/// Tracks when a user opens and uses the app, independent of attendance.
class UserSession extends Equatable {
  const UserSession({
    required this.id,
    required this.userId,
    required this.startTime,
    required this.role,
    this.endTime,
    this.lastActiveTime,
    this.deviceId,
  });

  /// Unique session identifier.
  final String id;

  /// User ID who opened the app.
  final String userId;

  /// When the app was opened (session started).
  final DateTime startTime;

  /// When the app was closed or session ended.
  final DateTime? endTime;

  /// Last time the user was active in this session.
  final DateTime? lastActiveTime;

  /// User role (student or owner).
  final UserRole role;

  /// Device ID for analytics.
  final String? deviceId;

  /// Whether the session is currently active.
  bool get isActive => endTime == null;

  /// Session duration in minutes (null if still active).
  int? get durationMinutes {
    if (endTime == null) return null;
    return endTime!.difference(startTime).inMinutes;
  }

  /// Current session duration including active time.
  int get currentDurationMinutes {
    final end = endTime ?? lastActiveTime ?? DateTime.now();
    return end.difference(startTime).inMinutes;
  }

  /// Hour of day when session started (0-23).
  int get startHour => startTime.hour;

  /// Date of session (normalized to midnight).
  DateTime get sessionDate {
    return DateTime(startTime.year, startTime.month, startTime.day);
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    startTime,
    endTime,
    lastActiveTime,
    role,
    deviceId,
  ];

  UserSession copyWith({
    String? id,
    String? userId,
    DateTime? startTime,
    DateTime? endTime,
    DateTime? lastActiveTime,
    UserRole? role,
    String? deviceId,
  }) {
    return UserSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      lastActiveTime: lastActiveTime ?? this.lastActiveTime,
      role: role ?? this.role,
      deviceId: deviceId ?? this.deviceId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'lastActiveTime': lastActiveTime?.toIso8601String(),
      'role': _roleToString(role),
      'deviceId': deviceId,
    };
  }

  static String _roleToString(UserRole role) {
    switch (role) {
      case UserRole.student:
        return 'student';
      case UserRole.owner:
        return 'owner';
      case UserRole.admin:
        return 'admin';
    }
  }

  factory UserSession.fromJson(String id, Map<String, dynamic> json) {
    return UserSession(
      id: id,
      userId: json['userId'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : null,
      lastActiveTime: json['lastActiveTime'] != null
          ? DateTime.parse(json['lastActiveTime'] as String)
          : null,
      role: _parseUserRole(json['role'] as String?),
      deviceId: json['deviceId'] as String?,
    );
  }

  static UserRole _parseUserRole(String? roleStr) {
    if (roleStr == null) return UserRole.student;
    switch (roleStr) {
      case 'student':
        return UserRole.student;
      case 'owner':
        return UserRole.owner;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.student;
    }
  }
}
