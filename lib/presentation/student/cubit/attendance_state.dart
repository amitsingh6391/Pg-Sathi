part of 'attendance_cubit.dart';

/// State for AttendanceCubit.
///
/// V2 Update: Supports multiple check-in/check-out sessions per day.
/// Represents the current attendance status for a student on a given day/slot.
class AttendanceState extends Equatable {
  const AttendanceState({
    this.status = AttendanceStatus.none,
    this.attendance,
    this.isLoading = false,
    this.errorMessage,
    this.date,
    this.slot,
  });

  /// Current attendance status.
  final AttendanceStatus status;

  /// The attendance record (if exists).
  final Attendance? attendance;

  /// Whether an operation is in progress.
  final bool isLoading;

  /// Error message if any operation failed.
  final String? errorMessage;

  /// Current date (yyyy-MM-dd format).
  final String? date;

  /// Current slot being managed.
  final Slot? slot;

  /// Whether there's an error.
  bool get hasError => errorMessage != null;

  /// Whether user can check in.
  /// V2: Can check in if no attendance or no active session.
  bool get canCheckIn {
    if (isLoading) return false;
    if (attendance == null) return true;
    return attendance!.canCheckIn;
  }

  /// Whether user can check out.
  /// V2: Can check out if there's an active session.
  bool get canCheckOut {
    if (isLoading) return false;
    if (attendance == null) return false;
    return attendance!.canCheckOut;
  }

  /// Whether attendance has any completed sessions.
  bool get hasCompletedSessions {
    if (attendance == null) return false;
    if (attendance!.isMultiSession) {
      return attendance!.completedSessionCount > 0;
    }
    return attendance!.isCheckedOut;
  }

  /// V2: Number of completed sessions today.
  int get completedSessionCount {
    if (attendance == null) return 0;
    if (attendance!.isMultiSession) {
      return attendance!.completedSessionCount;
    }
    return attendance!.isCheckedOut ? 1 : 0;
  }

  /// V2: Total time spent today (all completed sessions).
  int get totalMinutesToday {
    if (attendance == null) return 0;
    return attendance!.totalCompletedMinutes;
  }

  /// V2: Formatted total time today.
  String get formattedTotalTime {
    if (attendance == null) return '0m';
    return attendance!.formattedTotalTime;
  }

  /// Whether currently in an active session.
  bool get isInActiveSession {
    if (attendance == null) return false;
    return attendance!.isCheckedIn;
  }

  /// V2: Active session check-in time.
  DateTime? get activeSessionCheckInTime {
    if (attendance == null) return null;
    if (attendance!.isMultiSession) {
      return attendance!.activeSession?.checkInAt;
    }
    return attendance!.checkInTime;
  }

  AttendanceState copyWith({
    AttendanceStatus? status,
    Attendance? attendance,
    bool? isLoading,
    String? errorMessage,
    String? date,
    Slot? slot,
    bool clearError = false,
    bool clearAttendance = false,
  }) {
    return AttendanceState(
      status: status ?? this.status,
      attendance: clearAttendance ? null : (attendance ?? this.attendance),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      date: date ?? this.date,
      slot: slot ?? this.slot,
    );
  }

  @override
  List<Object?> get props => [
    status,
    attendance,
    isLoading,
    errorMessage,
    date,
    slot,
  ];
}
