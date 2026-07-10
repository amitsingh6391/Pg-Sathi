import 'package:equatable/equatable.dart';

/// Statistics for a student's attendance over a period.
class AttendanceStats extends Equatable {
  const AttendanceStats({
    required this.userId,
    required this.libraryId,
    required this.totalDays,
    required this.presentDays,
    required this.totalMinutes,
    required this.averageMinutesPerDay,
    required this.dailyStats,
    required this.weeklyStats,
    this.monthlyAverage,
    this.currentStreak = 0,
    this.longestStreak = 0,
  });

  final String userId;
  final String libraryId;

  /// Total number of days in the period.
  final int totalDays;

  /// Number of days with attendance (checked in and out).
  final int presentDays;

  /// Total minutes spent across all sessions.
  final int totalMinutes;

  /// Average minutes per day (only counting present days).
  final double averageMinutesPerDay;

  /// Daily stats for chart display (last 7 days).
  final List<DailyAttendanceStat> dailyStats;

  /// Weekly stats for trend display (last 4 weeks).
  final List<WeeklyAttendanceStat> weeklyStats;

  /// Monthly average (optional).
  final double? monthlyAverage;

  /// Current streak of consecutive days.
  final int currentStreak;

  /// Longest streak of consecutive days.
  final int longestStreak;

  /// Attendance percentage.
  double get attendancePercentage {
    if (totalDays == 0) return 0;
    return (presentDays / totalDays) * 100;
  }

  /// Formatted total time (e.g., "45h 30m").
  String get formattedTotalTime {
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
  }

  /// Formatted average time (e.g., "6h 25m").
  String get formattedAverageTime {
    final avgMins = averageMinutesPerDay.round();
    final hours = avgMins ~/ 60;
    final mins = avgMins % 60;
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
  }

  /// Empty stats for when no data is available.
  factory AttendanceStats.empty({
    required String userId,
    required String libraryId,
  }) {
    return AttendanceStats(
      userId: userId,
      libraryId: libraryId,
      totalDays: 0,
      presentDays: 0,
      totalMinutes: 0,
      averageMinutesPerDay: 0,
      dailyStats: [],
      weeklyStats: [],
    );
  }

  @override
  List<Object?> get props => [
    userId,
    libraryId,
    totalDays,
    presentDays,
    totalMinutes,
    averageMinutesPerDay,
    dailyStats,
    weeklyStats,
    monthlyAverage,
    currentStreak,
    longestStreak,
  ];
}

/// Daily attendance stat for charts.
class DailyAttendanceStat extends Equatable {
  const DailyAttendanceStat({
    required this.date,
    required this.dayName,
    required this.durationMinutes,
    required this.isPresent,
  });

  /// Date in yyyy-MM-dd format.
  final String date;

  /// Short day name (Mon, Tue, etc.).
  final String dayName;

  /// Duration in minutes.
  final int durationMinutes;

  /// Whether the student was present.
  final bool isPresent;

  /// Duration in hours for chart display.
  double get durationHours => durationMinutes / 60;

  /// Formatted duration.
  String get formattedDuration {
    final hours = durationMinutes ~/ 60;
    final mins = durationMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
  }

  @override
  List<Object?> get props => [date, dayName, durationMinutes, isPresent];
}

/// Weekly attendance stat for trend charts.
class WeeklyAttendanceStat extends Equatable {
  const WeeklyAttendanceStat({
    required this.weekNumber,
    required this.weekLabel,
    required this.totalMinutes,
    required this.presentDays,
    required this.averageMinutesPerDay,
  });

  /// Week number (1-52).
  final int weekNumber;

  /// Label for display (e.g., "Week 1", "Dec 15-21").
  final String weekLabel;

  /// Total minutes for the week.
  final int totalMinutes;

  /// Days present in the week.
  final int presentDays;

  /// Average minutes per day.
  final double averageMinutesPerDay;

  /// Average hours per day for chart.
  double get averageHoursPerDay => averageMinutesPerDay / 60;

  @override
  List<Object?> get props => [
    weekNumber,
    weekLabel,
    totalMinutes,
    presentDays,
    averageMinutesPerDay,
  ];
}
