import 'package:flutter/material.dart';

import '../../../domain/entities/user_activity_stats.dart';
import '../../core/app_ui_constants.dart';
import '../screens/hourly_activity_drill_down_screen.dart';

/// Simple bar chart showing hourly activity.
/// Each bar is tappable to show drill-down details.
class AdminActivityChart extends StatelessWidget {
  const AdminActivityChart({
    super.key,
    required this.hourlyActivity,
    this.date,
  });

  final List<HourlyActivity> hourlyActivity;
  
  /// Date for which hourly activity is shown.
  /// Defaults to today if not provided.
  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    if (hourlyActivity.isEmpty) {
      return Center(
        child: Text(
          'No activity data',
          style: AppUIConstants.bodySm.copyWith(
            color: AppUIConstants.textTertiary,
          ),
        ),
      );
    }

    // Find max value for scaling
    final maxCheckIns = hourlyActivity.fold<int>(
      1,
      (max, activity) => activity.checkIns > max ? activity.checkIns : max,
    );

    // Show all 24 hours
    final displayHours = hourlyActivity;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Fixed bar width for consistent sizing across all 24 hours
          const barWidth = 32.0;
          const spacing = 2.0;
          final totalWidth = (barWidth + spacing) * displayHours.length;

          return SizedBox(
            width: totalWidth,
            height: 120,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: displayHours.map((activity) {
            final barHeight = maxCheckIns > 0
                ? (activity.checkIns / maxCheckIns) *
                      (constraints.maxHeight - 20)
                : 0.0;

            final isActive = activity.checkIns > 0;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: GestureDetector(
                    onTap: isActive
                        ? () => _navigateToDrillDown(context, activity)
                        : null,
                    child: Tooltip(
                      message:
                          '${activity.formattedHour}: ${activity.checkIns} check-ins\nTap to view details',
                      child: SizedBox(
                        width: barWidth,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              height: barHeight.clamp(4.0, 100.0),
                              width: barWidth * 0.7,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? AppUIConstants.accent.withValues(
                                        alpha:
                                            0.3 +
                                            (activity.checkIns / maxCheckIns) * 0.7,
                                      )
                                    : AppUIConstants.divider,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _getShortHourLabel(activity.hour),
                              style: TextStyle(
                                fontSize: 8,
                                color: isActive
                                    ? AppUIConstants.textSecondary
                                    : AppUIConstants.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }

  String _getShortHourLabel(int hour) {
    return hour.toString().padLeft(2, '0');
  }

  void _navigateToDrillDown(BuildContext context, HourlyActivity activity) {
    final targetDate = date ?? DateTime.now();
    Navigator.of(context).push(
      HourlyActivityDrillDownScreen.route(
        date: targetDate,
        hour: activity.hour,
      ),
    );
  }
}
