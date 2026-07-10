import 'package:flutter/material.dart';

import '../../../domain/entities/admin_dashboard_stats.dart';
import '../../core/app_ui_constants.dart';

/// Library growth section for admin dashboard.
class AdminLibraryGrowth extends StatelessWidget {
  const AdminLibraryGrowth({super.key, required this.stats});

  final AdminDashboardStats stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Library Growth', style: AppUIConstants.headingSm),
            const Spacer(),
            if (stats.libraryGrowthPercent > 0) _buildGrowthBadge(),
          ],
        ),
        const SizedBox(height: AppUIConstants.spacingMd),
        Container(
          padding: const EdgeInsets.all(AppUIConstants.spacingMd),
          decoration: AppUIConstants.cardDecoration,
          child: Row(
            children: [
              Expanded(
                child: _GrowthMetric(
                  value: stats.librariesToday,
                  label: 'Today',
                  color: AppUIConstants.success,
                ),
              ),
              Container(width: 1, height: 40, color: AppUIConstants.divider),
              Expanded(
                child: _GrowthMetric(
                  value: stats.librariesLast7Days,
                  label: '7 Days',
                  color: AppUIConstants.accent,
                ),
              ),
              Container(width: 1, height: 40, color: AppUIConstants.divider),
              Expanded(
                child: _GrowthMetric(
                  value: stats.librariesLast30Days,
                  label: '30 Days',
                  color: AppUIConstants.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGrowthBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppUIConstants.spacingSm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppUIConstants.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.trending_up, size: 12, color: AppUIConstants.success),
          const SizedBox(width: 2),
          Text(
            '${stats.libraryGrowthPercent.toStringAsFixed(0)}%',
            style: AppUIConstants.caption.copyWith(
              color: AppUIConstants.success,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _GrowthMetric extends StatelessWidget {
  const _GrowthMetric({
    required this.value,
    required this.label,
    required this.color,
  });

  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: AppUIConstants.caption),
      ],
    );
  }
}
