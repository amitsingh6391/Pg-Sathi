import 'package:equatable/equatable.dart';

/// Represents a single check-in/check-out session within an attendance day.
///
/// Multiple sessions can exist for the same day when a student checks in
/// and out multiple times.
class AttendanceSession extends Equatable {
  const AttendanceSession({
    required this.sessionId,
    required this.checkInAt,
    this.checkOutAt,
    this.checkInDistance,
    this.checkOutDistance,
  });

  /// Unique identifier for this session within the attendance day.
  final String sessionId;

  /// When the student checked in for this session.
  final DateTime checkInAt;

  /// When the student checked out (null if session is still active).
  final DateTime? checkOutAt;

  /// Distance from library in meters when checked in.
  final double? checkInDistance;

  /// Distance from library in meters when checked out.
  final double? checkOutDistance;

  /// Whether this session is currently active (checked in but not checked out).
  bool get isActive => checkOutAt == null;

  /// Whether this session is complete (has both check-in and check-out).
  bool get isComplete => checkOutAt != null;

  /// Duration of this session in minutes (null if session is active).
  int? get durationMinutes {
    if (checkOutAt == null) return null;
    return checkOutAt!.difference(checkInAt).inMinutes;
  }

  /// Current session duration (including active time).
  /// For active sessions, calculates duration from check-in to now.
  int get currentDurationMinutes {
    final endTime = checkOutAt ?? DateTime.now();
    return endTime.difference(checkInAt).inMinutes;
  }

  /// Formatted session duration (e.g., "2h 30m").
  String get formattedDuration {
    final minutes = currentDurationMinutes;
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
  }

  /// Formatted completed session duration (null if still active).
  String? get formattedCompletedDuration {
    final minutes = durationMinutes;
    if (minutes == null) return null;
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
  }

  /// Creates a completed session from this session.
  AttendanceSession complete({
    required DateTime checkOutTime,
    required double distanceFromLibrary,
  }) {
    return AttendanceSession(
      sessionId: sessionId,
      checkInAt: checkInAt,
      checkOutAt: checkOutTime,
      checkInDistance: checkInDistance,
      checkOutDistance: distanceFromLibrary,
    );
  }

  /// Creates a new active session (checked in, not checked out).
  factory AttendanceSession.checkIn({
    required String sessionId,
    required DateTime checkInTime,
    required double distanceFromLibrary,
  }) {
    return AttendanceSession(
      sessionId: sessionId,
      checkInAt: checkInTime,
      checkInDistance: distanceFromLibrary,
    );
  }

  @override
  List<Object?> get props => [
    sessionId,
    checkInAt,
    checkOutAt,
    checkInDistance,
    checkOutDistance,
  ];
}
