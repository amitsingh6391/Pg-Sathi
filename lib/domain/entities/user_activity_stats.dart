import 'package:equatable/equatable.dart';

/// User activity statistics for admin dashboard.
/// Provides DAU, WAU, MAU and activity insights.
class UserActivityStats extends Equatable {
  const UserActivityStats({
    required this.dailyActiveStudents,
    required this.weeklyActiveStudents,
    required this.monthlyActiveStudents,
    required this.dailyActiveOwners,
    required this.weeklyActiveOwners,
    required this.hourlyActivityBreakdown,
    required this.peakHours,
    this.todayVsYesterday,
    this.thisWeekVsLastWeek,
    required this.generatedAt,
  });

  /// Empty stats constructor.
  const UserActivityStats.empty()
    : dailyActiveStudents = 0,
      weeklyActiveStudents = 0,
      monthlyActiveStudents = 0,
      dailyActiveOwners = 0,
      weeklyActiveOwners = 0,
      hourlyActivityBreakdown = const [],
      peakHours = const [],
      todayVsYesterday = null,
      thisWeekVsLastWeek = null,
      generatedAt = null;

  /// Daily active students (unique students who opened the app today).
  final int dailyActiveStudents;

  /// Weekly active students (unique students who opened the app in last 7 days).
  final int weeklyActiveStudents;

  /// Monthly active students (unique students who opened the app in last 30 days).
  final int monthlyActiveStudents;

  /// Daily active owners (unique owners who opened the app today).
  final int dailyActiveOwners;

  /// Weekly active owners (unique owners who opened the app in last 7 days).
  final int weeklyActiveOwners;

  /// Hourly breakdown of app sessions (24 entries, one per hour).
  final List<HourlyActivity> hourlyActivityBreakdown;

  /// Peak app usage hours (top 3).
  final List<int> peakHours;

  /// Comparison: Today vs Yesterday (percentage change).
  final double? todayVsYesterday;

  /// Comparison: This week vs Last week (percentage change).
  final double? thisWeekVsLastWeek;

  /// When these stats were generated.
  final DateTime? generatedAt;

  /// Formatted DAU/WAU/MAU ratio.
  String get stickiness {
    if (monthlyActiveStudents == 0) return '0%';
    final ratio = (dailyActiveStudents / monthlyActiveStudents) * 100;
    return '${ratio.toStringAsFixed(1)}%';
  }

  @override
  List<Object?> get props => [
    dailyActiveStudents,
    weeklyActiveStudents,
    monthlyActiveStudents,
    dailyActiveOwners,
    weeklyActiveOwners,
    hourlyActivityBreakdown,
    peakHours,
    todayVsYesterday,
    thisWeekVsLastWeek,
    generatedAt,
  ];

  UserActivityStats copyWith({
    int? dailyActiveStudents,
    int? weeklyActiveStudents,
    int? monthlyActiveStudents,
    int? dailyActiveOwners,
    int? weeklyActiveOwners,
    List<HourlyActivity>? hourlyActivityBreakdown,
    List<int>? peakHours,
    double? todayVsYesterday,
    double? thisWeekVsLastWeek,
    DateTime? generatedAt,
  }) {
    return UserActivityStats(
      dailyActiveStudents: dailyActiveStudents ?? this.dailyActiveStudents,
      weeklyActiveStudents: weeklyActiveStudents ?? this.weeklyActiveStudents,
      monthlyActiveStudents:
          monthlyActiveStudents ?? this.monthlyActiveStudents,
      dailyActiveOwners: dailyActiveOwners ?? this.dailyActiveOwners,
      weeklyActiveOwners: weeklyActiveOwners ?? this.weeklyActiveOwners,
      hourlyActivityBreakdown:
          hourlyActivityBreakdown ?? this.hourlyActivityBreakdown,
      peakHours: peakHours ?? this.peakHours,
      todayVsYesterday: todayVsYesterday ?? this.todayVsYesterday,
      thisWeekVsLastWeek: thisWeekVsLastWeek ?? this.thisWeekVsLastWeek,
      generatedAt: generatedAt ?? this.generatedAt,
    );
  }
}

/// Hourly activity data point.
class HourlyActivity extends Equatable {
  const HourlyActivity({
    required this.hour,
    required this.activeUsers,
    required this.checkIns,
  });

  /// Hour of day (0-23).
  final int hour;

  /// Number of active users in this hour.
  final int activeUsers;

  /// Number of app sessions started in this hour.
  final int checkIns;

  /// Formatted hour for display (e.g., "9 AM").
  String get formattedHour {
    if (hour == 0) return '12 AM';
    if (hour == 12) return '12 PM';
    if (hour < 12) return '$hour AM';
    return '${hour - 12} PM';
  }

  @override
  List<Object?> get props => [hour, activeUsers, checkIns];
}
