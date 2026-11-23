import 'package:material_ui/material_ui.dart';

import '../../../domain/entities/user_activity_stats.dart';
import '../../core/app_ui_constants.dart';
import '../../core/widgets/premium_kit.dart';

/// User activity section for admin dashboard.
class AdminUserActivitySection extends StatelessWidget {
  const AdminUserActivitySection({super.key, required this.activity});

  final UserActivityStats activity;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PremiumSectionHeader('Resident engagement'),
        PremiumCard(
          child: Column(
            children: [
              Row(
                children: [
                  PremiumStatusPill(
                    'Stickiness ${activity.stickiness}',
                    color: AppUIConstants.primaryLight,
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () => _showDauInfoDialog(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: AppUIConstants.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text('How DAU works', style: AppUIConstants.caption),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppUIConstants.spacingMd),
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
              'DAU counts unique tenants who checked in to a PG today. This metric tracks actual engagement, not just app opens.',
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
                      'A tenant is counted once per day, regardless of multiple check-ins.',
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
    return Row(
      children: [
        Expanded(
          child: _ActivityMetric(
            label: 'DAU',
            value: '${activity.dailyActiveStudents}',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActivityMetric(
            label: 'WAU',
            value: '${activity.weeklyActiveStudents}',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActivityMetric(
            label: 'MAU',
            value: '${activity.monthlyActiveStudents}',
          ),
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
    final c = isDau ? AppUIConstants.primaryLight : AppUIConstants.textPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppUIConstants.surfaceMuted,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        border: Border.all(color: AppUIConstants.border),
      ),
      child: Column(
        children: [
          Text(value, style: AppUIConstants.headingLg.copyWith(color: c)),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppUIConstants.caption.copyWith(
              color: c,
              letterSpacing: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
