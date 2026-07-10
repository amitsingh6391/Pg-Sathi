import 'package:flutter/material.dart';

import '../../../domain/entities/user_activity_stats.dart';
import '../../core/app_ui_constants.dart';
import 'admin_activity_chart.dart';

/// Hourly activity chart section for admin dashboard.
class AdminHourlyActivity extends StatelessWidget {
  const AdminHourlyActivity({super.key, required this.activity});

  final UserActivityStats activity;

  @override
  Widget build(BuildContext context) {
    if (activity.hourlyActivityBreakdown.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Hourly Activity', style: AppUIConstants.headingSm),
            const Spacer(),
            if (activity.peakHours.isNotEmpty)
              Text(
                'Peak: ${activity.peakHours.map(_formatHour).join(", ")}',
                style: AppUIConstants.caption.copyWith(
                  color: AppUIConstants.accent,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppUIConstants.spacingMd),
        Container(
          padding: const EdgeInsets.all(AppUIConstants.spacingLg),
          decoration: AppUIConstants.cardDecoration,
          child: Column(
            children: [
              if (_hasComparisons()) _buildComparisons(),
              SizedBox(
                height: 100,
                child: AdminActivityChart(
                  hourlyActivity: activity.hourlyActivityBreakdown,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _hasComparisons() {
    return activity.todayVsYesterday != null ||
        activity.thisWeekVsLastWeek != null;
  }

  Widget _buildComparisons() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppUIConstants.spacingMd),
      child: Row(
        children: [
          if (activity.todayVsYesterday != null)
            _ComparisonChip(
              label: 'vs Yesterday',
              value: activity.todayVsYesterday!,
            ),
          if (activity.thisWeekVsLastWeek != null) ...[
            const SizedBox(width: AppUIConstants.spacingSm),
            _ComparisonChip(
              label: 'vs Last Week',
              value: activity.thisWeekVsLastWeek!,
            ),
          ],
        ],
      ),
    );
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12 AM';
    if (hour == 12) return '12 PM';
    if (hour < 12) return '$hour AM';
    return '${hour - 12} PM';
  }
}

class _ComparisonChip extends StatelessWidget {
  const _ComparisonChip({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final isPositive = value >= 0;
    final color = isPositive ? AppUIConstants.success : AppUIConstants.error;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppUIConstants.spacingSm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPositive ? Icons.arrow_upward : Icons.arrow_downward,
            size: 10,
            color: color,
          ),
          const SizedBox(width: 2),
          Text(
            '${value.abs().toStringAsFixed(0)}% $label',
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
