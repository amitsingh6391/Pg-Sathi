import 'package:equatable/equatable.dart';

import 'attendance_session.dart';
import 'slot.dart';

/// Represents a student's attendance record for a library session.
/// Supports geo-fenced check-in/check-out with slot-wise tracking.
///
/// V2 Update: Now supports multiple check-in/check-out sessions per day.
/// Backward compatible with legacy single-session attendance records.
class Attendance extends Equatable {
  const Attendance({
    required this.id,
    required this.userId,
    required this.libraryId,
    required this.seatId,
    required this.slot,
    required this.date,
    required this.status,
    this.checkInTime,
    this.checkOutTime,
    this.checkInDistance,
    this.checkOutDistance,
    this.createdAt,
    this.sessions = const [],
  });

  final String id;
  final String userId;
  final String libraryId;
  final String seatId;
  final Slot slot;

  /// Date in yyyy-MM-dd format for easy querying.
  final String date;

  final AttendanceStatus status;

  /// Legacy single-session check-in time.
  /// For multi-session records, use [sessions] instead.
  /// Kept for backward compatibility with existing data.
  final DateTime? checkInTime;

  /// Legacy single-session check-out time.
  /// For multi-session records, use [sessions] instead.
  /// Kept for backward compatibility with existing data.
  final DateTime? checkOutTime;

  /// Distance from library in meters when checked in (legacy).
  final double? checkInDistance;

  /// Distance from library in meters when checked out (legacy).
  final double? checkOutDistance;

  final DateTime? createdAt;

  /// V2: List of check-in/check-out sessions for this day.
  /// Empty for legacy single-session records.
  final List<AttendanceSession> sessions;

  // V2: Multi-session computed properties

  /// Whether this is a V2 multi-session attendance record.
  bool get isMultiSession => sessions.isNotEmpty;

  /// The currently active session (checked in but not checked out).
  /// Returns null if no session is active.
  AttendanceSession? get activeSession {
    if (sessions.isEmpty) return null;
    try {
      return sessions.firstWhere((s) => s.isActive);
    } catch (_) {
      return null;
    }
  }

  /// Whether there is an active session.
  bool get hasActiveSession => activeSession != null;

  /// All completed sessions (checked in and checked out).
  List<AttendanceSession> get completedSessions {
    return sessions.where((s) => s.isComplete).toList();
  }

  /// Total number of sessions for the day.
  int get sessionCount => sessions.length;

  /// Number of completed sessions.
  int get completedSessionCount => completedSessions.length;

  /// Total duration of all completed sessions in minutes.
  int get totalCompletedMinutes {
    if (isMultiSession) {
      return completedSessions.fold<int>(
        0,
        (sum, s) => sum + (s.durationMinutes ?? 0),
      );
    }
    // Legacy single-session fallback
    return sessionDurationMinutes ?? 0;
  }

  /// Total duration including active session in minutes.
  int get totalMinutesIncludingActive {
    if (isMultiSession) {
      return sessions.fold<int>(0, (sum, s) => sum + s.currentDurationMinutes);
    }
    // Legacy single-session fallback
    if (checkInTime == null) return 0;
    final endTime = checkOutTime ?? DateTime.now();
    return endTime.difference(checkInTime!).inMinutes;
  }

  /// Formatted total time for all completed sessions (e.g., "5h 30m").
  String get formattedTotalTime {
    final minutes = totalCompletedMinutes;
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
  }

  /// First check-in time of the day (from sessions or legacy).
  DateTime? get firstCheckInTime {
    if (sessions.isNotEmpty) {
      final sorted = [...sessions]
        ..sort((a, b) => a.checkInAt.compareTo(b.checkInAt));
      return sorted.first.checkInAt;
    }
    return checkInTime;
  }

  /// Last check-out time of the day (from completed sessions or legacy).
  DateTime? get lastCheckOutTime {
    if (sessions.isNotEmpty) {
      final completed = completedSessions;
      if (completed.isEmpty) return null;
      final sorted = [...completed]
        ..sort(
          (a, b) => (a.checkOutAt ?? DateTime.now()).compareTo(
            b.checkOutAt ?? DateTime.now(),
          ),
        );
      return sorted.last.checkOutAt;
    }
    return checkOutTime;
  }

  // V2: Updated status logic for multi-session

  /// Checks if user is currently checked in.
  /// For V2: Returns true if there's an active session.
  bool get isCheckedIn {
    if (isMultiSession) {
      return hasActiveSession;
    }
    return status == AttendanceStatus.checkedIn;
  }

  /// Checks if user has checked out (no active session).
  /// For V2: Returns true if all sessions are complete.
  bool get isCheckedOut {
    if (isMultiSession) {
      return sessions.isNotEmpty && !hasActiveSession;
    }
    return status == AttendanceStatus.checkedOut;
  }

  /// Whether user can check in again.
  /// V2: Can check in if there's no active session (even after previous checkout).
  /// This enables multi-session support where users can check-in multiple times per day.
  bool get canCheckIn {
    if (isMultiSession) {
      return !hasActiveSession;
    }
    // For legacy records: allow check-in if not currently checked in.
    // This means after checkout, user CAN check in again (V2 behavior applied to legacy).
    // Note: The actual multi-session creation happens in the use case layer.
    return status != AttendanceStatus.checkedIn;
  }

  /// Whether user can check out.
  /// For V2: Can check out if there's an active session.
  bool get canCheckOut {
    if (isMultiSession) {
      return hasActiveSession;
    }
    return status.canCheckOut;
  }

  // Legacy single-session properties (backward compatible)

  /// Session duration in minutes (if checked out).
  /// For legacy single-session records.
  int? get sessionDurationMinutes {
    if (checkInTime == null || checkOutTime == null) return null;
    return checkOutTime!.difference(checkInTime!).inMinutes;
  }

  /// Formatted session duration (e.g., "2h 30m").
  /// For V2 records, returns total completed time.
  String? get formattedDuration {
    if (isMultiSession) {
      return formattedTotalTime;
    }
    final minutes = sessionDurationMinutes;
    if (minutes == null) return null;
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    libraryId,
    seatId,
    slot,
    date,
    status,
    checkInTime,
    checkOutTime,
    checkInDistance,
    checkOutDistance,
    createdAt,
    sessions,
  ];

  Attendance copyWith({
    String? id,
    String? userId,
    String? libraryId,
    String? seatId,
    Slot? slot,
    String? date,
    AttendanceStatus? status,
    DateTime? checkInTime,
    DateTime? checkOutTime,
    double? checkInDistance,
    double? checkOutDistance,
    DateTime? createdAt,
    List<AttendanceSession>? sessions,
  }) {
    return Attendance(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      libraryId: libraryId ?? this.libraryId,
      seatId: seatId ?? this.seatId,
      slot: slot ?? this.slot,
      date: date ?? this.date,
      status: status ?? this.status,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      checkInDistance: checkInDistance ?? this.checkInDistance,
      checkOutDistance: checkOutDistance ?? this.checkOutDistance,
      createdAt: createdAt ?? this.createdAt,
      sessions: sessions ?? this.sessions,
    );
  }

  /// Creates a new V2 attendance record with the first check-in session.
  factory Attendance.checkInV2({
    required String id,
    required String userId,
    required String libraryId,
    required String seatId,
    required Slot slot,
    required String date,
    required String sessionId,
    required double distanceFromLibrary,
  }) {
    final now = DateTime.now();
    final session = AttendanceSession.checkIn(
      sessionId: sessionId,
      checkInTime: now,
      distanceFromLibrary: distanceFromLibrary,
    );

    return Attendance(
      id: id,
      userId: userId,
      libraryId: libraryId,
      seatId: seatId,
      slot: slot,
      date: date,
      status: AttendanceStatus.checkedIn,
      createdAt: now,
      sessions: [session],
    );
  }

  /// Adds a new check-in session to an existing attendance record.
  Attendance addSession({
    required String sessionId,
    required double distanceFromLibrary,
  }) {
    if (hasActiveSession) {
      throw StateError('Cannot start new session while another is active');
    }

    final now = DateTime.now();
    final newSession = AttendanceSession.checkIn(
      sessionId: sessionId,
      checkInTime: now,
      distanceFromLibrary: distanceFromLibrary,
    );

    return copyWith(
      status: AttendanceStatus.checkedIn,
      sessions: [...sessions, newSession],
    );
  }

  /// Completes the active session (check out).
  Attendance completeActiveSession({required double distanceFromLibrary}) {
    if (!hasActiveSession) {
      throw StateError('No active session to complete');
    }

    final now = DateTime.now();
    final updatedSessions = sessions.map((s) {
      if (s.isActive) {
        return s.complete(
          checkOutTime: now,
          distanceFromLibrary: distanceFromLibrary,
        );
      }
      return s;
    }).toList();

    return copyWith(
      status: AttendanceStatus.checkedOut,
      sessions: updatedSessions,
    );
  }

  /// Creates a new check-in attendance record (legacy V1).
  /// @deprecated Use [Attendance.checkInV2] for new records.
  factory Attendance.checkIn({
    required String id,
    required String userId,
    required String libraryId,
    required String seatId,
    required Slot slot,
    required String date,
    required double distanceFromLibrary,
  }) {
    return Attendance(
      id: id,
      userId: userId,
      libraryId: libraryId,
      seatId: seatId,
      slot: slot,
      date: date,
      status: AttendanceStatus.checkedIn,
      checkInTime: DateTime.now(),
      checkInDistance: distanceFromLibrary,
      createdAt: DateTime.now(),
    );
  }

  /// Marks this attendance as checked out (legacy V1).
  /// @deprecated Use [completeActiveSession] for V2 records.
  Attendance checkOut({required double distanceFromLibrary}) {
    if (isMultiSession) {
      return completeActiveSession(distanceFromLibrary: distanceFromLibrary);
    }
    return copyWith(
      status: AttendanceStatus.checkedOut,
      checkOutTime: DateTime.now(),
      checkOutDistance: distanceFromLibrary,
    );
  }
}

/// Attendance status enum.
/// - none: No attendance record for today (not checked in yet)
/// - checkedIn: User has an active session (checked in but not checked out)
/// - checkedOut: User has completed their session(s) (no active session)
enum AttendanceStatus {
  none,
  checkedIn,
  checkedOut;

  String get displayName {
    switch (this) {
      case AttendanceStatus.none:
        return 'Not Checked In';
      case AttendanceStatus.checkedIn:
        return 'Checked In';
      case AttendanceStatus.checkedOut:
        return 'Checked Out';
    }
  }

  String get shortName {
    switch (this) {
      case AttendanceStatus.none:
        return '-';
      case AttendanceStatus.checkedIn:
        return 'IN';
      case AttendanceStatus.checkedOut:
        return 'OUT';
    }
  }

  /// Whether user can check in.
  /// Note: For V2 multi-session, use [Attendance.canCheckIn] instead.
  bool get canCheckIn => this == AttendanceStatus.none;

  /// Whether user can check out.
  /// Note: For V2 multi-session, use [Attendance.canCheckOut] instead.
  bool get canCheckOut => this == AttendanceStatus.checkedIn;

  /// Whether attendance has any completed sessions.
  bool get isComplete => this == AttendanceStatus.checkedOut;

  static AttendanceStatus fromString(String? value) {
    if (value == null) return AttendanceStatus.none;
    return AttendanceStatus.values.cast<AttendanceStatus?>().firstWhere(
          (s) => s?.name.toLowerCase() == value.toLowerCase(),
          orElse: () => AttendanceStatus.none,
        ) ??
        AttendanceStatus.none;
  }
}

/// Result of location validation for attendance.
class LocationValidationResult extends Equatable {
  const LocationValidationResult({
    required this.isValid,
    required this.distanceInMeters,
    this.errorMessage,
  });

  final bool isValid;
  final double distanceInMeters;
  final String? errorMessage;

  /// Maximum allowed distance from library in meters.
  static const double maxAllowedDistance = 100.0;

  factory LocationValidationResult.valid(double distance) {
    return LocationValidationResult(isValid: true, distanceInMeters: distance);
  }

  factory LocationValidationResult.outOfRange(double distance) {
    return LocationValidationResult(
      isValid: false,
      distanceInMeters: distance,
      errorMessage:
          'You are ${distance.toStringAsFixed(0)}m away. Please be within ${maxAllowedDistance.toStringAsFixed(0)}m of the library.',
    );
  }

  factory LocationValidationResult.permissionDenied() {
    return const LocationValidationResult(
      isValid: false,
      distanceInMeters: -1,
      errorMessage:
          'Location permission denied. Please enable location access.',
    );
  }

  factory LocationValidationResult.serviceDisabled() {
    return const LocationValidationResult(
      isValid: false,
      distanceInMeters: -1,
      errorMessage: 'Location services are disabled. Please enable GPS.',
    );
  }

  factory LocationValidationResult.libraryLocationMissing() {
    return const LocationValidationResult(
      isValid: false,
      distanceInMeters: -1,
      errorMessage: 'Library location not configured. Contact owner.',
    );
  }

  @override
  List<Object?> get props => [isValid, distanceInMeters, errorMessage];
}
