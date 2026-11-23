import 'package:material_ui/material_ui.dart';

import '../../../domain/entities/admin_dashboard_stats.dart';
import '../../core/app_ui_constants.dart';
import '../../core/widgets/premium_kit.dart';

/// PG growth: new PGs onboarded today / 7 days / 30 days, as proportional bars.
class AdminLibraryGrowth extends StatelessWidget {
  const AdminLibraryGrowth({super.key, required this.stats});

  final AdminDashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final maxV = [
      stats.librariesToday,
      stats.librariesLast7Days,
      stats.librariesLast30Days,
      1,
    ].reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PremiumSectionHeader('PG onboarding'),
        PremiumCard(
          child: Column(
            children: [
              if (stats.libraryGrowthPercent > 0)
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: PremiumStatusPill(
                      '\u2191 ${stats.libraryGrowthPercent.toStringAsFixed(0)}% growth',
                      color: AppUIConstants.primaryLight,
                    ),
                  ),
                ),
              _Row(
                'Today',
                stats.librariesToday,
                maxV,
                AppUIConstants.primaryLight,
              ),
              const SizedBox(height: 12),
              _Row(
                'Last 7 days',
                stats.librariesLast7Days,
                maxV,
                AppUIConstants.textSecondary,
              ),
              const SizedBox(height: 12),
              _Row(
                'Last 30 days',
                stats.librariesLast30Days,
                maxV,
                AppUIConstants.textTertiary,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, this.max, this.color);

  final String label;
  final int value;
  final int max;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 84, child: Text(label, style: AppUIConstants.bodySm)),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value / max),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 8,
                backgroundColor: AppUIConstants.surfaceMuted,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            '$value',
            textAlign: TextAlign.right,
            style: AppUIConstants.bodyLg.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
