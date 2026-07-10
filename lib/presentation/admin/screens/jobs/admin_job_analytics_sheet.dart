import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../domain/entities/job_alert.dart';
import '../../../core/app_ui_constants.dart';
import '../../cubit/jobs/admin_job_analytics_cubit.dart';

/// Bottom sheet displaying analytics (views / clicks / CTR / per-link breakdown)
/// for a single published [JobAlert]. Phase-2 surface.
class AdminJobAnalyticsSheet extends StatelessWidget {
  const AdminJobAnalyticsSheet({super.key, required this.job});

  final JobAlert job;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: AppUIConstants.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              _handle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Analytics',
                        style: AppUIConstants.headingMd,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  job.title,
                  style: AppUIConstants.bodyMd.copyWith(
                    color: AppUIConstants.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: BlocBuilder<AdminJobAnalyticsCubit,
                    AdminJobAnalyticsState>(
                  builder: (context, state) {
                    if (state.isLoading || state.analytics == null) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final a = state.analytics!;
                    return ListView(
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        _metricsGrid(a),
                        const SizedBox(height: 16),
                        _linkBreakdown(a),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _handle() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: AppUIConstants.border,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _metricsGrid(dynamic a) {
    // Dynamic is fine here — concrete type is JobAlertAnalytics from domain.
    // Keeping the import surface of the sheet minimal.
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.2,
      children: [
        _metric('Views', '${a.viewCount}', Icons.visibility_outlined),
        _metric(
          'Apply clicks',
          '${a.applyClickCount}',
          Icons.touch_app_outlined,
        ),
        _metric('Saves', '${a.bookmarkCount}',
            Icons.bookmark_border_rounded),
        _metric(
          'CTR',
          '${a.clickRate.toStringAsFixed(1)}%',
          Icons.trending_up_rounded,
        ),
      ],
    );
  }

  Widget _metric(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppUIConstants.cardDecorationFlat,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(children: [
            Icon(icon, size: 14, color: AppUIConstants.textTertiary),
            const SizedBox(width: 4),
            Text(label, style: AppUIConstants.caption),
          ]),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppUIConstants.statValue.copyWith(fontSize: 20),
          ),
        ],
      ),
    );
  }

  Widget _linkBreakdown(dynamic a) {
    final breakdown = a.clicksByLinkIndex as Map<int, int>;
    if (breakdown.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: AppUIConstants.cardDecorationFlat,
        child: Text(
          'No link clicks tracked yet.',
          style: AppUIConstants.bodySm,
        ),
      );
    }
    final sorted = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppUIConstants.cardDecorationFlat,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Clicks by link', style: AppUIConstants.headingSm),
          const SizedBox(height: 10),
          ...sorted.map((e) {
            final label = e.key < job.importantLinks.length
                ? job.importantLinks[e.key].label
                : 'Link ${e.key + 1}';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(label, style: AppUIConstants.bodyMd),
                  ),
                  Text(
                    '${e.value}',
                    style: AppUIConstants.bodyMd.copyWith(
                      color: AppUIConstants.accent,
                      fontWeight: FontWeight.w700,
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
