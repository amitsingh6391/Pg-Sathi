import 'package:flutter/material.dart';

import '../../../domain/entities/user_activity_stats.dart';
import '../../core/app_ui_constants.dart';


/// User activity section for admin dashboard.
class AdminUserActivitySection extends StatelessWidget {
  const AdminUserActivitySection({super.key, required this.activity});

  final UserActivityStats activity;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('User Activity', style: AppUIConstants.headingSm),
            const Spacer(),
            IconButton(
              icon: Icon(
                Icons.info_outline,
                size: 18,
                color: AppUIConstants.textSecondary,
              ),
              onPressed: () => _showDauInfoDialog(context),
              tooltip: 'How DAU is calculated',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: AppUIConstants.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppUIConstants.accent.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                'Stickiness: ${activity.stickiness}',
                style: AppUIConstants.caption.copyWith(
                  color: AppUIConstants.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppUIConstants.spacingMd),
        Container(
          padding: const EdgeInsets.all(AppUIConstants.spacingLg),
          decoration: BoxDecoration(
            color: AppUIConstants.surface,
            borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
            border: Border.all(
              color: AppUIConstants.divider.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              _buildStudentActivity(),
            ],
          ),
        ),
      ],
    );
  }

  void _showDauInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppUIConstants.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
        ),
        title: Row(
          children: [
            Icon(
              Icons.analytics_outlined,
              color: AppUIConstants.primary,
              size: 24,
            ),
            const SizedBox(width: AppUIConstants.spacingSm),
            const Text('Daily Active Users (DAU)'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How it\'s calculated:',
              style: AppUIConstants.bodyMd.copyWith(
                fontWeight: FontWeight.w600,
                color: AppUIConstants.textPrimary,
              ),
            ),
            const SizedBox(height: AppUIConstants.spacingSm),
            Text(
              'DAU counts unique students who checked in to a library today. This metric tracks actual engagement, not just app opens.',
              style: AppUIConstants.bodySm.copyWith(
                color: AppUIConstants.textSecondary,
              ),
            ),
            const SizedBox(height: AppUIConstants.spacingMd),
            Container(
              padding: const EdgeInsets.all(AppUIConstants.spacingMd),
              decoration: BoxDecoration(
                color: AppUIConstants.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
                border: Border.all(
                  color: AppUIConstants.primary.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 18,
                    color: AppUIConstants.primary,
                  ),
                  const SizedBox(width: AppUIConstants.spacingSm),
                  Expanded(
                    child: Text(
                      'A student is counted once per day, regardless of multiple check-ins.',
                      style: AppUIConstants.caption.copyWith(
                        color: AppUIConstants.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentActivity() {
    return Column(
      children: [
        Row(
          children: [
            Icon(
              Icons.school_outlined,
              size: 16,
              color: AppUIConstants.textSecondary,
            ),
            const SizedBox(width: AppUIConstants.spacingSm),
            Text(
              'Students',
              style: AppUIConstants.bodySm.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppUIConstants.spacingMd),
        Row(
          children: [
            Expanded(
              child: _ActivityMetric(
                label: 'DAU',
                value: '${activity.dailyActiveStudents}',
              ),
            ),
            Expanded(
              child: _ActivityMetric(
                label: 'WAU',
                value: '${activity.weeklyActiveStudents}',
              ),
            ),
            Expanded(
              child: _ActivityMetric(
                label: 'MAU',
                value: '${activity.monthlyActiveStudents}',
              ),
            ),
          ],
        ),
      ],
    );
  }

}

class _ActivityMetric extends StatelessWidget {
  const _ActivityMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDau = label == 'DAU';
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: isDau
                ? AppUIConstants.primary.withValues(alpha: 0.08)
                : AppUIConstants.surface,
            borderRadius: BorderRadius.circular(10),
            border: isDau
                ? Border.all(
                    color: AppUIConstants.primary.withValues(alpha: 0.2),
                    width: 1,
                  )
                : null,
          ),
          child: Text(
            value,
            style: AppUIConstants.headingLg.copyWith(
              fontWeight: FontWeight.bold,
              color: isDau
                  ? AppUIConstants.primary
                  : AppUIConstants.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: AppUIConstants.bodySm.copyWith(
            color: isDau
                ? AppUIConstants.primary
                : AppUIConstants.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

