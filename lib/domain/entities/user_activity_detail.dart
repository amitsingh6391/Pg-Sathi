import 'package:equatable/equatable.dart';
import 'package:pg_manager/domain/entities/user.dart';

/// Detailed information about a user's activity in a specific time period.
/// Used for drill-down views in analytics.
/// Represents consolidated activity - if a user had multiple sessions,
/// this shows the earliest check-in and latest check-out.
class UserActivityDetail extends Equatable {
  const UserActivityDetail({
    required this.userId,
    required this.userName,
    required this.role,
    required this.checkInTime,
    this.checkOutTime,
    this.libraryName,
    this.libraryId,
    this.sessionCount = 1,
  });

  /// User ID who was active.
  final String userId;

  /// User's display name.
  final String userName;

  /// User role (student/owner).
  final UserRole role;

  /// When the user checked in / started session (earliest if multiple sessions).
  final DateTime checkInTime;

  /// When the user checked out / ended session (latest if multiple, null if any still active).
  final DateTime? checkOutTime;

  /// Name of the library (if applicable for the user).
  final String? libraryName;

  /// Library ID (if applicable).
  final String? libraryId;

  /// Number of sessions for this user in the time period.
  final int sessionCount;

  /// Whether the session is still active.
  bool get isActive => checkOutTime == null;

  /// Session duration in minutes (null if still active).
  int? get durationMinutes {
    if (checkOutTime == null) return null;
    return checkOutTime!.difference(checkInTime).inMinutes;
  }

  /// Current duration including active sessions.
  int get currentDurationMinutes {
    final end = checkOutTime ?? DateTime.now();
    return end.difference(checkInTime).inMinutes;
  }

  /// Formatted duration string (e.g., "1h 30m").
  String get formattedDuration {
    final minutes = currentDurationMinutes;
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    if (hours > 0) {
      return '${hours}h ${remainingMinutes}m';
    }
    return '${minutes}m';
  }

  /// Formatted check-in time (e.g., "9:30 AM").
  String get formattedCheckInTime {
    final hour = checkInTime.hour;
    final minute = checkInTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  /// Formatted check-out time (e.g., "5:30 PM" or "Active").
  String get formattedCheckOutTime {
    if (checkOutTime == null) return 'Active';
    final hour = checkOutTime!.hour;
    final minute = checkOutTime!.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  /// Whether user had multiple sessions in this time period.
  bool get hasMultipleSessions => sessionCount > 1;

  @override
  List<Object?> get props => [
        userId,
        userName,
        role,
        checkInTime,
        checkOutTime,
        libraryName,
        libraryId,
        sessionCount,
      ];

  UserActivityDetail copyWith({
    String? userId,
    String? userName,
    UserRole? role,
    DateTime? checkInTime,
    DateTime? checkOutTime,
    String? libraryName,
    String? libraryId,
    int? sessionCount,
  }) {
    return UserActivityDetail(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      role: role ?? this.role,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      libraryName: libraryName ?? this.libraryName,
      libraryId: libraryId ?? this.libraryId,
      sessionCount: sessionCount ?? this.sessionCount,
    );
  }
}

/// Collection of user activity details grouped by date and hour.
class UserActivityTimeline extends Equatable {
  const UserActivityTimeline({
    required this.date,
    required this.sessions,
    required this.totalDuration,
  });

  /// Date of activity.
  final DateTime date;

  /// List of sessions on this date.
  final List<UserActivityDetail> sessions;

  /// Total duration across all sessions in minutes.
  final int totalDuration;

  /// Formatted date (e.g., "Jan 19, 2026").
  String get formattedDate {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  /// Formatted total duration (e.g., "3h 45m").
  String get formattedTotalDuration {
    final hours = totalDuration ~/ 60;
    final minutes = totalDuration % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  /// List of unique hours when user was active.
  List<int> get activeHours {
    return sessions.map((s) => s.checkInTime.hour).toSet().toList()..sort();
  }

  @override
  List<Object?> get props => [date, sessions, totalDuration];
}
