import 'package:equatable/equatable.dart';

import 'attendance.dart';
import 'slot.dart';

/// Summary of attendance for owner analytics dashboard.
class OwnerAttendanceSummary extends Equatable {
  const OwnerAttendanceSummary({
    required this.libraryId,
    required this.date,
    required this.totalMembers,
    required this.presentToday,
    required this.absentToday,
    required this.avgAttendancePercent,
    required this.avgTimeSpentMinutes,
    required this.slotSummaries,
    required this.dailyTrend,
    required this.studentRecords,
  });

  final String libraryId;
  final String date;
  final int totalMembers;
  final int presentToday;
  final int absentToday;
  final double avgAttendancePercent;
  final int avgTimeSpentMinutes;
  final List<SlotAttendanceSummary> slotSummaries;
  final List<AttendanceTrendPoint> dailyTrend;
  final List<StudentAttendanceRecord> studentRecords;

  /// Formatted average time spent.
  String get formattedAvgTime {
    final hours = avgTimeSpentMinutes ~/ 60;
    final mins = avgTimeSpentMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
  }

  /// Get slot summary by slot type.
  SlotAttendanceSummary? getSlotSummary(Slot slot) {
    return slotSummaries.cast<SlotAttendanceSummary?>().firstWhere(
      (s) => s?.slot == slot,
      orElse: () => null,
    );
  }

  /// Empty summary for initial state.
  factory OwnerAttendanceSummary.empty(String libraryId) {
    return OwnerAttendanceSummary(
      libraryId: libraryId,
      date: '',
      totalMembers: 0,
      presentToday: 0,
      absentToday: 0,
      avgAttendancePercent: 0,
      avgTimeSpentMinutes: 0,
      slotSummaries: [],
      dailyTrend: [],
      studentRecords: [],
    );
  }

  @override
  List<Object?> get props => [
    libraryId,
    date,
    totalMembers,
    presentToday,
    absentToday,
    avgAttendancePercent,
    avgTimeSpentMinutes,
    slotSummaries,
    dailyTrend,
    studentRecords,
  ];
}

/// Slot-wise attendance summary.
class SlotAttendanceSummary extends Equatable {
  const SlotAttendanceSummary({
    required this.slot,
    required this.presentCount,
    required this.totalSeats,
    required this.avgTimeSpentMinutes,
  });

  final Slot slot;
  final int presentCount;
  final int totalSeats;
  final int avgTimeSpentMinutes;

  /// Occupancy percentage.
  double get occupancyPercent {
    if (totalSeats == 0) return 0;
    return (presentCount / totalSeats) * 100;
  }

  /// Formatted average time.
  String get formattedAvgTime {
    final hours = avgTimeSpentMinutes ~/ 60;
    final mins = avgTimeSpentMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
  }

  @override
  List<Object?> get props => [
    slot,
    presentCount,
    totalSeats,
    avgTimeSpentMinutes,
  ];
}

/// Data point for attendance trend chart.
class AttendanceTrendPoint extends Equatable {
  const AttendanceTrendPoint({
    required this.date,
    required this.dayLabel,
    required this.presentCount,
    required this.totalMembers,
  });

  /// Date in yyyy-MM-dd format.
  final String date;

  /// Short day label (Mon, Tue, etc.).
  final String dayLabel;

  /// Number of students present.
  final int presentCount;

  /// Total active members on that day.
  final int totalMembers;

  /// Attendance percentage.
  double get attendancePercent {
    if (totalMembers == 0) return 0;
    return (presentCount / totalMembers) * 100;
  }

  @override
  List<Object?> get props => [date, dayLabel, presentCount, totalMembers];
}

/// Individual student's attendance record for the list view.
/// V2 Update: Supports multiple sessions per day.
class StudentAttendanceRecord extends Equatable {
  const StudentAttendanceRecord({
    required this.userId,
    required this.studentName,
    required this.seatNumber,
    required this.slot,
    required this.status,
    this.slotName,
    this.checkInTime,
    this.checkOutTime,
    this.durationMinutes,
    this.sessionCount = 1,
    this.totalMinutes,
    this.sessions = const [],
  });

  final String userId;
  final String studentName;
  final String seatNumber;
  final Slot slot;
  final AttendanceStatus status;

  /// Custom slot name (from membership). Falls back to slot.displayName if null.
  final String? slotName;

  /// First check-in time of the day (for legacy and V2).
  final DateTime? checkInTime;

  /// Last check-out time of the day (for legacy and V2).
  final DateTime? checkOutTime;

  /// Duration of single session (legacy) or current session (V2).
  final int? durationMinutes;

  /// V2: Number of sessions for the day.
  final int sessionCount;

  /// V2: Total minutes across all completed sessions.
  final int? totalMinutes;

  /// V2: Individual session details.
  final List<StudentSessionRecord> sessions;

  /// Whether student is present (checked in or checked out).
  bool get isPresent => status != AttendanceStatus.none;

  /// Whether student has an active session.
  bool get hasActiveSession => status == AttendanceStatus.checkedIn;

  /// V2: Whether this is a multi-session record.
  bool get isMultiSession => sessionCount > 1 || sessions.isNotEmpty;

  /// Formatted duration (total for V2, single for legacy).
  String? get formattedDuration {
    final minutes = totalMinutes ?? durationMinutes;
    if (minutes == null) return null;
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
  }

  /// Display name for the slot (custom name if available, otherwise legacy name).
  String get displaySlotName => slotName ?? slot.displayName;

  @override
  List<Object?> get props => [
    userId,
    studentName,
    seatNumber,
    slot,
    slotName,
    status,
    checkInTime,
    checkOutTime,
    durationMinutes,
    sessionCount,
    totalMinutes,
    sessions,
  ];
}

/// V2: Individual session record for owner view.
class StudentSessionRecord extends Equatable {
  const StudentSessionRecord({
    required this.sessionId,
    required this.checkInAt,
    this.checkOutAt,
    this.durationMinutes,
  });

  final String sessionId;
  final DateTime checkInAt;
  final DateTime? checkOutAt;
  final int? durationMinutes;

  bool get isActive => checkOutAt == null;
  bool get isComplete => checkOutAt != null;

  String? get formattedDuration {
    if (durationMinutes == null) return null;
    final hours = durationMinutes! ~/ 60;
    final mins = durationMinutes! % 60;
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
  }

  @override
  List<Object?> get props => [
    sessionId,
    checkInAt,
    checkOutAt,
    durationMinutes,
  ];
}
