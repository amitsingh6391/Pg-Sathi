import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/admin_dashboard_stats.dart';
import '../../core/app_ui_constants.dart';
import '../cubit/admin_analytics_cubit.dart';
import '../screens/admin_library_analytics_screen.dart';
import '../screens/admin_students_analytics_screen.dart';
import '../screens/admin_owners_details_screen.dart';

/// Platform overview section showing key metrics.
/// Tappable to navigate to detailed analytics.
class AdminPlatformOverview extends StatelessWidget {
  const AdminPlatformOverview({super.key, required this.stats});

  final AdminDashboardStats stats;

  void _navigateToLibraries(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<AdminAnalyticsCubit>(),
          child: const AdminLibraryAnalyticsScreen(),
        ),
      ),
    );
  }

  void _navigateToStudents(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<AdminAnalyticsCubit>(),
          child: const AdminStudentsAnalyticsScreen(),
        ),
      ),
    );
  }

  void _navigateToOwners(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AdminOwnersDetailsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Platform Overview', style: AppUIConstants.headingSm),
            const Spacer(),
            IconButton(
              icon: Icon(
                Icons.info_outline,
                size: 18,
                color: AppUIConstants.textSecondary,
              ),
              onPressed: () => _showInfoDialog(context),
              tooltip: 'How metrics are calculated',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        const SizedBox(height: AppUIConstants.spacingMd),
        Row(
          children: [
            Expanded(
              child: _TappableMetricCard(
                icon: Icons.business_rounded,
                label: 'Libraries',
                value: '${stats.totalLibraries}',
                color: AppUIConstants.primary,
                onTap: () => _navigateToLibraries(context),
              ),
            ),
            const SizedBox(width: AppUIConstants.spacingMd),
            Expanded(
              child: _TappableMetricCard(
                icon: Icons.school_rounded,
                label: 'Students',
                value: '${stats.totalActiveStudents}',
                color: AppUIConstants.accent,
                onTap: () => _navigateToStudents(context),
              ),
            ),
            const SizedBox(width: AppUIConstants.spacingMd),
            Expanded(
              child: _TappableMetricCard(
                icon: Icons.person_outline_rounded,
                label: 'Owners',
                value: '${stats.totalActiveOwners}',
                color: AppUIConstants.secondary,
                onTap: () => _navigateToOwners(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showInfoDialog(BuildContext context) {
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
              Icons.info_outline,
              color: AppUIConstants.primary,
              size: 24,
            ),
            const SizedBox(width: AppUIConstants.spacingSm),
            const Text('Platform Metrics'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoItem(
              title: 'Libraries',
              description: 'Total number of registered libraries on the platform.',
            ),
            const SizedBox(height: AppUIConstants.spacingMd),
            _InfoItem(
              title: 'Students',
              description:
                  'Total number of students with active memberships.',
            ),
            const SizedBox(height: AppUIConstants.spacingMd),
            _InfoItem(
              title: 'Owners',
              description: 'Total number of library owners registered.',
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
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppUIConstants.bodyMd.copyWith(
            fontWeight: FontWeight.w600,
            color: AppUIConstants.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: AppUIConstants.caption.copyWith(
            color: AppUIConstants.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _TappableMetricCard extends StatelessWidget {
  const _TappableMetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppUIConstants.spacingMd,
            vertical: AppUIConstants.spacingLg,
          ),
          decoration: BoxDecoration(
            color: AppUIConstants.surface,
            borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
            border: Border.all(
              color: AppUIConstants.divider.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: color.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(height: AppUIConstants.spacingMd),
              Text(
                value,
                style: AppUIConstants.headingLg.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppUIConstants.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppUIConstants.bodySm.copyWith(
                  color: AppUIConstants.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
