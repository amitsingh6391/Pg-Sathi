import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

import '../core/core.dart';
import '../entities/attendance.dart';
import '../entities/attendance_stats.dart';
import '../repositories/attendance_repository.dart';

/// Use case for calculating attendance statistics.
class GetAttendanceStats
    implements UseCase<AttendanceStats, GetAttendanceStatsParams> {
  const GetAttendanceStats({required this.attendanceRepository});

  final AttendanceRepository attendanceRepository;

  @override
  Future<Either<Failure, AttendanceStats>> call(
    GetAttendanceStatsParams params,
  ) async {
    // Get attendance for the past 30 days
    final endDate = DateTime.now();
    final startDate = endDate.subtract(const Duration(days: 30));

    final result = await attendanceRepository.getAttendanceForPeriod(
      userId: params.userId,
      libraryId: params.libraryId,
      startDate: startDate,
      endDate: endDate,
    );

    return result.fold((failure) => Left(failure), (attendances) {
      // Calculate stats
      final stats = _calculateStats(
        attendances: attendances,
        userId: params.userId,
        libraryId: params.libraryId,
        startDate: startDate,
        endDate: endDate,
      );
      return Right(stats);
    });
  }

  AttendanceStats _calculateStats({
    required List<Attendance> attendances,
    required String userId,
    required String libraryId,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    // Filter only completed sessions (V2: has completed sessions, Legacy: checked out)
    final completedSessions = attendances
        .where((a) => 
            (a.isMultiSession && a.completedSessionCount > 0) ||
            (!a.isMultiSession && a.isCheckedOut && a.sessionDurationMinutes != null))
        .toList();

    // Calculate total days and present days
    final totalDays = endDate.difference(startDate).inDays + 1;
    final presentDays = completedSessions.map((a) => a.date).toSet().length;

    // Calculate total and average minutes (V2: use totalCompletedMinutes)
    final totalMinutes = completedSessions.fold<int>(
      0,
      (sum, a) => sum + a.totalCompletedMinutes,
    );
    final averageMinutesPerDay = presentDays > 0
        ? totalMinutes / presentDays
        : 0.0;

    // Calculate daily stats for last 7 days
    final dailyStats = _calculateDailyStats(completedSessions);

    // Calculate weekly stats for last 4 weeks
    final weeklyStats = _calculateWeeklyStats(completedSessions);

    // Calculate streaks
    final streaks = _calculateStreaks(completedSessions);

    return AttendanceStats(
      userId: userId,
      libraryId: libraryId,
      totalDays: totalDays,
      presentDays: presentDays,
      totalMinutes: totalMinutes,
      averageMinutesPerDay: averageMinutesPerDay,
      dailyStats: dailyStats,
      weeklyStats: weeklyStats,
      currentStreak: streaks.current,
      longestStreak: streaks.longest,
    );
  }

  List<DailyAttendanceStat> _calculateDailyStats(List<Attendance> sessions) {
    final now = DateTime.now();
    final dateFormat = DateFormat('yyyy-MM-dd');
    final dayFormat = DateFormat('E'); // Mon, Tue, etc.

    final stats = <DailyAttendanceStat>[];

    for (var i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateStr = dateFormat.format(date);
      final dayName = dayFormat.format(date);

      // Find session for this date
      final daySessions = sessions.where((s) => s.date == dateStr).toList();
      // V2: Use totalCompletedMinutes which handles both multi-session and legacy
      final totalMinutes = daySessions.fold<int>(
        0,
        (sum, s) => sum + s.totalCompletedMinutes,
      );

      stats.add(
        DailyAttendanceStat(
          date: dateStr,
          dayName: dayName,
          durationMinutes: totalMinutes,
          isPresent: daySessions.isNotEmpty,
        ),
      );
    }

    return stats;
  }

  List<WeeklyAttendanceStat> _calculateWeeklyStats(List<Attendance> sessions) {
    final now = DateTime.now();
    final stats = <WeeklyAttendanceStat>[];

    for (var weekIndex = 3; weekIndex >= 0; weekIndex--) {
      final weekEnd = now.subtract(Duration(days: weekIndex * 7));
      final weekStart = weekEnd.subtract(const Duration(days: 6));

      // Get sessions in this week
      final weekSessions = sessions.where((s) {
        final sessionDate = DateTime.tryParse(s.date);
        if (sessionDate == null) return false;
        return sessionDate.isAfter(
              weekStart.subtract(const Duration(days: 1)),
            ) &&
            sessionDate.isBefore(weekEnd.add(const Duration(days: 1)));
      }).toList();

      // V2: Use totalCompletedMinutes which handles both multi-session and legacy
      final totalMinutes = weekSessions.fold<int>(
        0,
        (sum, s) => sum + s.totalCompletedMinutes,
      );
      final presentDays = weekSessions.map((s) => s.date).toSet().length;
      final avgMinutes = presentDays > 0 ? totalMinutes / presentDays : 0.0;

      final weekLabel = weekIndex == 0
          ? 'This Week'
          : weekIndex == 1
          ? 'Last Week'
          : '${weekIndex + 1} Weeks Ago';

      stats.add(
        WeeklyAttendanceStat(
          weekNumber: 4 - weekIndex,
          weekLabel: weekLabel,
          totalMinutes: totalMinutes,
          presentDays: presentDays,
          averageMinutesPerDay: avgMinutes,
        ),
      );
    }

    return stats;
  }

  ({int current, int longest}) _calculateStreaks(List<Attendance> sessions) {
    if (sessions.isEmpty) return (current: 0, longest: 0);

    // Get unique dates sorted in descending order
    final dates =
        sessions
            .map((s) => DateTime.tryParse(s.date))
            .whereType<DateTime>()
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));

    if (dates.isEmpty) return (current: 0, longest: 0);

    // Calculate current streak
    var currentStreak = 0;
    var expectedDate = DateTime.now();

    for (final date in dates) {
      final diff = expectedDate.difference(date).inDays;
      if (diff <= 1) {
        currentStreak++;
        expectedDate = date;
      } else {
        break;
      }
    }

    // Calculate longest streak
    var longestStreak = 0;
    var tempStreak = 1;
    for (var i = 0; i < dates.length - 1; i++) {
      final diff = dates[i].difference(dates[i + 1]).inDays;
      if (diff == 1) {
        tempStreak++;
      } else {
        longestStreak = tempStreak > longestStreak ? tempStreak : longestStreak;
        tempStreak = 1;
      }
    }
    longestStreak = tempStreak > longestStreak ? tempStreak : longestStreak;

    return (current: currentStreak, longest: longestStreak);
  }
}

/// Parameters for GetAttendanceStats use case.
class GetAttendanceStatsParams extends Equatable {
  const GetAttendanceStatsParams({
    required this.userId,
    required this.libraryId,
  });

  final String userId;
  final String libraryId;

  @override
  List<Object?> get props => [userId, libraryId];
}
