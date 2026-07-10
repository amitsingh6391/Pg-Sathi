import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/attendance.dart';
import '../../../domain/entities/attendance_stats.dart';
import '../../core/app_ui_constants.dart';
import '../cubit/attendance_history_cubit.dart';

/// Attendance Details Screen - Premium, minimal UI with fixed charts.
class AttendanceDetailsScreen extends StatefulWidget {
  const AttendanceDetailsScreen({
    super.key,
    required this.userId,
    required this.libraryId,
    required this.libraryName,
  });

  final String userId;
  final String libraryId;
  final String libraryName;

  @override
  State<AttendanceDetailsScreen> createState() =>
      _AttendanceDetailsScreenState();
}

class _AttendanceDetailsScreenState extends State<AttendanceDetailsScreen> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    context.read<AttendanceHistoryCubit>().loadAttendanceData(
      userId: widget.userId,
      libraryId: widget.libraryId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUIConstants.background,
      body: BlocBuilder<AttendanceHistoryCubit, AttendanceHistoryState>(
        builder: (context, state) {
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              _buildAppBar(context),
              if (state.isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppUIConstants.primary,
                      strokeWidth: 2,
                    ),
                  ),
                )
              else if (state.hasError)
                SliverFillRemaining(
                  child: _buildErrorState(context, state.errorMessage),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(AppUIConstants.spacingXl),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Today's Attendance
                      _TodayAttendanceCard(attendance: state.todayAttendance),
                      const SizedBox(height: AppUIConstants.spacing2Xl),

                      // Stats Summary
                      if (state.hasStats) ...[
                        _StatsSummaryCard(stats: state.stats!),
                        const SizedBox(height: AppUIConstants.spacing2Xl),
                      ],

                      // Daily Bar Chart
                      if (state.hasStats &&
                          state.stats!.dailyStats.isNotEmpty) ...[
                        _DailyBarChart(dailyStats: state.stats!.dailyStats),
                        const SizedBox(height: AppUIConstants.spacing2Xl),
                      ],

                      // Weekly Trend Chart
                      if (state.hasStats &&
                          state.stats!.weeklyStats.isNotEmpty) ...[
                        _WeeklyTrendChart(
                          weeklyStats: state.stats!.weeklyStats,
                        ),
                        const SizedBox(height: AppUIConstants.spacing2Xl),
                      ],

                      // Period Selector + History List
                      _PeriodSelector(
                        selectedPeriod: state.selectedPeriod,
                        onPeriodChanged: (period) {
                          context
                              .read<AttendanceHistoryCubit>()
                              .setSelectedPeriod(period);
                        },
                      ),
                      const SizedBox(height: AppUIConstants.spacingLg),

                      _AttendanceHistoryList(
                        attendances: state.filteredHistory,
                      ),
                      const SizedBox(height: 40),
                    ]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 100,
      floating: false,
      pinned: true,
      backgroundColor: AppUIConstants.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          color: AppUIConstants.primary,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(56, 32, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text(
                    'Attendance',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.libraryName,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: _loadData,
        ),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context, String? message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppUIConstants.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              message ?? 'Failed to load data',
              textAlign: TextAlign.center,
              style: AppUIConstants.bodyMd,
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: TextButton.styleFrom(
                foregroundColor: AppUIConstants.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Today's Attendance Card - V2 with multi-session support
class _TodayAttendanceCard extends StatelessWidget {
  const _TodayAttendanceCard({this.attendance});

  final Attendance? attendance;

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('EEEE, MMMM d').format(DateTime.now());
    final hasAttendance = attendance != null;
    final isCheckedIn = attendance?.isCheckedIn ?? false;
    final isCheckedOut = attendance?.isCheckedOut ?? false;

    // V2: Multi-session info
    final isMultiSession = attendance?.isMultiSession ?? false;
    final sessionCount = isMultiSession
        ? attendance!.sessionCount
        : (hasAttendance ? 1 : 0);
    final hasMultipleSessions =
        sessionCount > 1 ||
        (isMultiSession && attendance!.completedSessionCount > 0);

    return Container(
      padding: const EdgeInsets.all(AppUIConstants.spacingXl),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        border: Border.all(
          color: isCheckedOut
              ? AppUIConstants.success.withValues(alpha: 0.3)
              : isCheckedIn
              ? AppUIConstants.accent.withValues(alpha: 0.3)
              : AppUIConstants.border,
        ),
        boxShadow: [AppUIConstants.shadowMd],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.today_rounded,
                color: AppUIConstants.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text('Today', style: AppUIConstants.bodySm),
              if (hasMultipleSessions) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppUIConstants.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(
                      AppUIConstants.radiusFull,
                    ),
                  ),
                  child: Text(
                    '$sessionCount sessions',
                    style: TextStyle(
                      color: AppUIConstants.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (isCheckedOut)
                _StatusBadge(label: 'Complete', color: AppUIConstants.success)
              else if (isCheckedIn)
                _StatusBadge(label: 'In Session', color: AppUIConstants.accent),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            today,
            style: AppUIConstants.headingSm.copyWith(
              color: AppUIConstants.textPrimary,
            ),
          ),
          const SizedBox(height: AppUIConstants.spacingLg),
          if (hasAttendance)
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _TimeDisplay(
                        label: hasMultipleSessions ? 'First In' : 'Check In',
                        time: attendance!.firstCheckInTime,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 36,
                      color: AppUIConstants.divider,
                    ),
                    Expanded(
                      child: _TimeDisplay(
                        label: hasMultipleSessions ? 'Last Out' : 'Check Out',
                        time: attendance!.lastCheckOutTime,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 36,
                      color: AppUIConstants.divider,
                    ),
                    Expanded(
                      child: _TimeDisplay(
                        label: hasMultipleSessions ? 'Total' : 'Duration',
                        duration: attendance!.formattedTotalTime,
                      ),
                    ),
                  ],
                ),
                // V2: Show session breakdown for multi-session
                if (isMultiSession && attendance!.sessions.length > 1) ...[
                  const SizedBox(height: AppUIConstants.spacingLg),
                  _buildSessionBreakdown(attendance!),
                ],
              ],
            )
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No attendance recorded',
                  style: AppUIConstants.bodySm,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSessionBreakdown(Attendance attendance) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppUIConstants.background,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.timeline_rounded,
                size: 14,
                color: AppUIConstants.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                'Session Breakdown',
                style: AppUIConstants.caption.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...attendance.sessions.asMap().entries.map((entry) {
            final index = entry.key;
            final session = entry.value;
            final checkIn = DateFormat('h:mm a').format(session.checkInAt);
            final checkOut = session.checkOutAt != null
                ? DateFormat('h:mm a').format(session.checkOutAt!)
                : 'Active';
            final duration =
                session.formattedCompletedDuration ??
                '${session.currentDurationMinutes}m';

            return Padding(
              padding: EdgeInsets.only(top: index > 0 ? 6 : 0),
              child: Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: session.isActive
                          ? AppUIConstants.accent
                          : AppUIConstants.success.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: session.isActive
                              ? Colors.white
                              : AppUIConstants.success,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$checkIn → $checkOut',
                      style: AppUIConstants.caption,
                    ),
                  ),
                  Text(
                    duration,
                    style: AppUIConstants.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: session.isActive
                          ? AppUIConstants.accent
                          : AppUIConstants.textPrimary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _TimeDisplay extends StatelessWidget {
  const _TimeDisplay({required this.label, this.time, this.duration});

  final String label;
  final DateTime? time;
  final String? duration;

  @override
  Widget build(BuildContext context) {
    final displayValue =
        duration ??
        (time != null ? DateFormat('hh:mm a').format(time!) : '--:--');

    return Column(
      children: [
        Text(label, style: AppUIConstants.caption),
        const SizedBox(height: 4),
        Text(
          displayValue,
          style: AppUIConstants.bodyLg.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// Stats Summary Card
class _StatsSummaryCard extends StatelessWidget {
  const _StatsSummaryCard({required this.stats});

  final AttendanceStats stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppUIConstants.spacingXl),
      decoration: AppUIConstants.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('30-Day Summary', style: AppUIConstants.headingSm),
          const SizedBox(height: AppUIConstants.spacingLg),
          Row(
            children: [
              Expanded(
                child: _StatColumn(
                  value: '${stats.presentDays}',
                  label: 'Days Present',
                  sublabel: 'of ${stats.totalDays}',
                ),
              ),
              Expanded(
                child: _StatColumn(
                  value: stats.formattedTotalTime,
                  label: 'Total Time',
                ),
              ),
              Expanded(
                child: _StatColumn(
                  value: stats.formattedAverageTime,
                  label: 'Avg/Day',
                ),
              ),
            ],
          ),
          if (stats.currentStreak > 0 || stats.longestStreak > 0) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppUIConstants.spacingLg),
              child: Divider(height: 1, color: AppUIConstants.divider),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StreakDisplay(
                  value: stats.currentStreak,
                  label: 'Current Streak',
                ),
                _StreakDisplay(
                  value: stats.longestStreak,
                  label: 'Best Streak',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.value, required this.label, this.sublabel});

  final String value;
  final String label;
  final String? sublabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppUIConstants.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: AppUIConstants.caption),
        if (sublabel != null) ...[
          const SizedBox(height: 2),
          Text(sublabel!, style: AppUIConstants.caption.copyWith(fontSize: 10)),
        ],
      ],
    );
  }
}

class _StreakDisplay extends StatelessWidget {
  const _StreakDisplay({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$value',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppUIConstants.textPrimary,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          'days\n$label',
          style: AppUIConstants.caption.copyWith(height: 1.2),
        ),
      ],
    );
  }
}

/// Daily Bar Chart - Fixed rendering, minimal styling
class _DailyBarChart extends StatelessWidget {
  const _DailyBarChart({required this.dailyStats});

  final List<DailyAttendanceStat> dailyStats;

  @override
  Widget build(BuildContext context) {
    // Safe maxY calculation to prevent chart errors
    double maxValue = 0;
    for (final stat in dailyStats) {
      if (stat.durationHours > maxValue) {
        maxValue = stat.durationHours;
      }
    }
    // Ensure maxY is at least 1 to prevent division by zero
    final double maxY = maxValue > 0 ? (maxValue * 1.3).ceilToDouble() : 4.0;
    final safeMaxY = maxY.clamp(1.0, 24.0);

    return Container(
      padding: const EdgeInsets.all(AppUIConstants.spacingXl),
      decoration: AppUIConstants.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Daily Hours', style: AppUIConstants.headingSm),
              Text('Last 7 days', style: AppUIConstants.bodySm),
            ],
          ),
          const SizedBox(height: AppUIConstants.spacing2Xl),
          SizedBox(
            height: 180,
            child: dailyStats.isEmpty
                ? _buildEmptyState()
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: safeMaxY,
                      minY: 0,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => AppUIConstants.chartTooltip,
                          tooltipPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          tooltipMargin: 8,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            if (groupIndex >= dailyStats.length) return null;
                            final stat = dailyStats[groupIndex];
                            return BarTooltipItem(
                              stat.formattedDuration,
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= dailyStats.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  dailyStats[index].dayName,
                                  style: AppUIConstants.caption,
                                ),
                              );
                            },
                            reservedSize: 28,
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            interval: safeMaxY / 4,
                            getTitlesWidget: (value, meta) {
                              if (value == 0) return const SizedBox.shrink();
                              return Text(
                                '${value.toInt()}h',
                                style: AppUIConstants.caption,
                              );
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: safeMaxY / 4,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: AppUIConstants.chartGrid,
                          strokeWidth: 1,
                          dashArray: [4, 4],
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: List.generate(dailyStats.length, (index) {
                        final stat = dailyStats[index];
                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: stat.durationHours,
                              color: stat.isPresent
                                  ? AppUIConstants.chartPrimary
                                  : AppUIConstants.disabled,
                              width: 24,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bar_chart_rounded,
            size: 40,
            color: AppUIConstants.disabled,
          ),
          const SizedBox(height: 8),
          Text('No data yet', style: AppUIConstants.bodySm),
        ],
      ),
    );
  }
}

/// Weekly Trend Chart - Fixed rendering
class _WeeklyTrendChart extends StatelessWidget {
  const _WeeklyTrendChart({required this.weeklyStats});

  final List<WeeklyAttendanceStat> weeklyStats;

  @override
  Widget build(BuildContext context) {
    // Safe maxY calculation
    double maxValue = 0;
    for (final stat in weeklyStats) {
      if (stat.averageHoursPerDay > maxValue) {
        maxValue = stat.averageHoursPerDay;
      }
    }
    final double maxY = maxValue > 0 ? (maxValue * 1.3).ceilToDouble() : 4.0;
    final safeMaxY = maxY.clamp(1.0, 12.0);

    return Container(
      padding: const EdgeInsets.all(AppUIConstants.spacingXl),
      decoration: AppUIConstants.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Weekly Trend', style: AppUIConstants.headingSm),
              Text('Avg hrs/day', style: AppUIConstants.bodySm),
            ],
          ),
          const SizedBox(height: AppUIConstants.spacing2Xl),
          SizedBox(
            height: 160,
            child: weeklyStats.isEmpty
                ? _buildEmptyState()
                : LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: safeMaxY,
                      lineTouchData: LineTouchData(
                        enabled: true,
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (_) => AppUIConstants.chartTooltip,
                          tooltipPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              final index = spot.x.toInt();
                              if (index < 0 || index >= weeklyStats.length) {
                                return null;
                              }
                              final stat = weeklyStats[index];
                              return LineTooltipItem(
                                '${stat.averageHoursPerDay.toStringAsFixed(1)}h',
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: safeMaxY / 4,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: AppUIConstants.chartGrid,
                          strokeWidth: 1,
                          dashArray: [4, 4],
                        ),
                      ),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= weeklyStats.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'W${weeklyStats[index].weekNumber}',
                                  style: AppUIConstants.caption,
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            interval: safeMaxY / 4,
                            getTitlesWidget: (value, meta) {
                              if (value == 0) return const SizedBox.shrink();
                              return Text(
                                '${value.toInt()}h',
                                style: AppUIConstants.caption,
                              );
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: List.generate(weeklyStats.length, (index) {
                            return FlSpot(
                              index.toDouble(),
                              weeklyStats[index].averageHoursPerDay,
                            );
                          }),
                          isCurved: true,
                          curveSmoothness: 0.3,
                          color: AppUIConstants.chartAccent,
                          barWidth: 2.5,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 4,
                                color: AppUIConstants.surface,
                                strokeWidth: 2,
                                strokeColor: AppUIConstants.chartAccent,
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppUIConstants.chartAccent.withValues(
                              alpha: 0.08,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.show_chart_rounded,
            size: 40,
            color: AppUIConstants.disabled,
          ),
          const SizedBox(height: 8),
          Text('No data yet', style: AppUIConstants.bodySm),
        ],
      ),
    );
  }
}

/// Period Selector - Minimal tabs
class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({
    required this.selectedPeriod,
    required this.onPeriodChanged,
  });

  final AttendancePeriod selectedPeriod;
  final ValueChanged<AttendancePeriod> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('History', style: AppUIConstants.headingSm),
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: AppUIConstants.divider,
            borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: AttendancePeriod.values.map((period) {
              final isSelected = period == selectedPeriod;
              return GestureDetector(
                onTap: () => onPeriodChanged(period),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppUIConstants.surface
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: isSelected ? [AppUIConstants.shadowSm] : null,
                  ),
                  child: Text(
                    _getPeriodLabel(period),
                    style: TextStyle(
                      color: isSelected
                          ? AppUIConstants.textPrimary
                          : AppUIConstants.textSecondary,
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  String _getPeriodLabel(AttendancePeriod period) {
    switch (period) {
      case AttendancePeriod.week:
        return '7D';
      case AttendancePeriod.month:
        return '30D';
      case AttendancePeriod.all:
        return 'All';
    }
  }
}

/// Attendance History List - V2 with multi-session support
class _AttendanceHistoryList extends StatelessWidget {
  const _AttendanceHistoryList({required this.attendances});

  final List<Attendance> attendances;

  @override
  Widget build(BuildContext context) {
    if (attendances.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: AppUIConstants.cardDecorationFlat,
        child: Column(
          children: [
            Icon(
              Icons.event_busy_rounded,
              size: 40,
              color: AppUIConstants.disabled,
            ),
            const SizedBox(height: 12),
            Text('No records found', style: AppUIConstants.bodySm),
          ],
        ),
      );
    }

    return Container(
      decoration: AppUIConstants.cardDecoration,
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: attendances.length,
        separatorBuilder: (_, _) =>
            const Divider(height: 1, color: AppUIConstants.divider),
        itemBuilder: (context, index) {
          return _AttendanceListItem(attendance: attendances[index]);
        },
      ),
    );
  }
}

/// V2: Updated list item with multi-session support
class _AttendanceListItem extends StatefulWidget {
  const _AttendanceListItem({required this.attendance});

  final Attendance attendance;

  @override
  State<_AttendanceListItem> createState() => _AttendanceListItemState();
}

class _AttendanceListItemState extends State<_AttendanceListItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final attendance = widget.attendance;
    final date = DateTime.tryParse(attendance.date);
    final dateStr = date != null
        ? DateFormat('EEE, MMM d').format(date)
        : attendance.date;

    // V2: Check if multi-session
    final isMultiSession = attendance.isMultiSession;
    final sessionCount = isMultiSession ? attendance.sessionCount : 1;
    final showExpandable = isMultiSession && sessionCount > 1;

    // For single session or legacy, show simple time range
    final checkInStr = attendance.firstCheckInTime != null
        ? DateFormat('h:mm a').format(attendance.firstCheckInTime!)
        : '--';
    final checkOutStr = attendance.lastCheckOutTime != null
        ? DateFormat('h:mm a').format(attendance.lastCheckOutTime!)
        : '--';

    return Column(
      children: [
        InkWell(
          onTap: showExpandable
              ? () => setState(() => _isExpanded = !_isExpanded)
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppUIConstants.spacingLg,
              vertical: AppUIConstants.spacingMd,
            ),
            child: Row(
              children: [
                // Date column
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(dateStr, style: AppUIConstants.bodyLg),
                          if (sessionCount > 1) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppUIConstants.primary.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppUIConstants.radiusFull,
                                ),
                              ),
                              child: Text(
                                '$sessionCount sessions',
                                style: TextStyle(
                                  color: AppUIConstants.primary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        attendance.slot.displayName,
                        style: AppUIConstants.caption,
                      ),
                    ],
                  ),
                ),
                // Time range (first check-in to last check-out)
                Expanded(
                  flex: 2,
                  child: Text(
                    sessionCount > 1
                        ? '$checkInStr → $checkOutStr'
                        : '$checkInStr → $checkOutStr',
                    style: AppUIConstants.bodySm,
                    textAlign: TextAlign.center,
                  ),
                ),
                // Total duration
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        attendance.formattedTotalTime,
                        style: AppUIConstants.bodyLg.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (showExpandable) ...[
                        const SizedBox(width: 4),
                        Icon(
                          _isExpanded
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          size: 18,
                          color: AppUIConstants.textSecondary,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // V2: Expanded session details
        if (_isExpanded && isMultiSession) _buildSessionDetails(attendance),
      ],
    );
  }

  Widget _buildSessionDetails(Attendance attendance) {
    final sessions = attendance.sessions;
    if (sessions.isEmpty) return const SizedBox.shrink();

    return Container(
      color: AppUIConstants.background,
      padding: const EdgeInsets.fromLTRB(
        AppUIConstants.spacingLg + 24,
        0,
        AppUIConstants.spacingLg,
        AppUIConstants.spacingMd,
      ),
      child: Column(
        children: sessions.asMap().entries.map((entry) {
          final index = entry.key;
          final session = entry.value;
          final checkIn = DateFormat('h:mm a').format(session.checkInAt);
          final checkOut = session.checkOutAt != null
              ? DateFormat('h:mm a').format(session.checkOutAt!)
              : 'Active';
          final duration = session.formattedCompletedDuration ?? '--';

          return Padding(
            padding: EdgeInsets.only(top: index > 0 ? 8 : 0),
            child: Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: session.isComplete
                        ? AppUIConstants.success.withValues(alpha: 0.1)
                        : AppUIConstants.accent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: session.isComplete
                          ? AppUIConstants.success.withValues(alpha: 0.3)
                          : AppUIConstants.accent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: session.isComplete
                            ? AppUIConstants.success
                            : AppUIConstants.accent,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$checkIn → $checkOut',
                    style: AppUIConstants.caption,
                  ),
                ),
                Text(
                  duration,
                  style: AppUIConstants.caption.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
