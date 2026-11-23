import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/services/analytics_service.dart';
import '../../core/app_ui_constants.dart';
import '../../core/widgets/premium_kit.dart';
import '../cubit/feature_analytics_cubit.dart';

// Extra dark-friendly series colors to complement the token palette.

/// Admin screen to view app-wide feature usage analytics.
/// Shows real-time metrics from Firebase Analytics for all tracked events.
class AdminFeatureAnalyticsScreen extends StatelessWidget {
  const AdminFeatureAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<FeatureAnalyticsCubit>()..loadAnalytics(),
      child: const _AdminFeatureAnalyticsView(),
    );
  }
}

class _AdminFeatureAnalyticsView extends StatefulWidget {
  const _AdminFeatureAnalyticsView();

  @override
  State<_AdminFeatureAnalyticsView> createState() =>
      _AdminFeatureAnalyticsViewState();
}

class _AdminFeatureAnalyticsViewState
    extends State<_AdminFeatureAnalyticsView> {
  String _selectedTimeRange = '7d';
  String? _selectedRole;

  static const _rangeLabels = {
    '1d': 'Last 24 hours',
    '7d': 'Last 7 days',
    '30d': 'Last 30 days',
    '90d': 'Last 90 days',
  };

  void _reload({String? role, String? timeRange, bool useCurrentRole = true}) {
    context.read<FeatureAnalyticsCubit>().loadAnalytics(
      role: useCurrentRole ? _selectedRole : role,
      timeRange: timeRange ?? _selectedTimeRange,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUIConstants.background,
      appBar: AppBar(
        title: const Text('Feature Analytics', style: AppUIConstants.headingSm),
        backgroundColor: AppUIConstants.background,
        foregroundColor: AppUIConstants.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _reload(),
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: _showHelpDialog,
            tooltip: 'Help',
          ),
        ],
      ),
      body: BlocBuilder<FeatureAnalyticsCubit, FeatureAnalyticsState>(
        builder: (context, state) {
          if (state.isLoading && state.eventCounts.isEmpty) {
            return const _FeatureSkeleton();
          }

          if (state.errorMessage != null && state.eventCounts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppUIConstants.spacing2Xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: AppUIConstants.surfaceMuted,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.cloud_off_rounded,
                        size: 34,
                        color: AppUIConstants.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppUIConstants.spacingLg),
                    Text(
                      state.errorMessage!,
                      textAlign: TextAlign.center,
                      style: AppUIConstants.bodyMd,
                    ),
                    const SizedBox(height: AppUIConstants.spacingLg),
                    ElevatedButton.icon(
                      onPressed: () => _reload(),
                      style: AppUIConstants.primaryButtonStyle,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final totalEvents = state.eventCounts.values.fold<int>(
            0,
            (s, c) => s + c,
          );

          return RefreshIndicator(
            color: AppUIConstants.primaryLight,
            backgroundColor: AppUIConstants.surface,
            onRefresh: () async => _reload(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppUIConstants.spacingLg,
                0,
                AppUIConstants.spacingLg,
                32,
              ),
              children: [
                if (state.isLoading)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: LinearProgressIndicator(
                      minHeight: 2,
                      color: AppUIConstants.primaryLight,
                      backgroundColor: AppUIConstants.surfaceMuted,
                    ),
                  ),
                _buildHero(totalEvents, state.eventCounts),
                const SizedBox(height: AppUIConstants.spacingMd),
                _buildFilters(),
                const PremiumSectionHeader('Event categories'),
                _buildEventCategories(state.eventCounts),
                const PremiumSectionHeader('Most used features'),
                _buildTopFeatures(state.eventCounts),
                const PremiumSectionHeader('Usage by role'),
                _buildRoleBreakdown(state.roleCounts),
                const PremiumSectionHeader('Platform distribution'),
                _buildPlatformBreakdown(state.platformCounts),
                const PremiumSectionHeader('Recent events'),
                _buildRecentEvents(state.recentEvents),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------- hero

  Widget _buildHero(int totalEvents, Map<String, int> eventCounts) {
    final distinct = eventCounts.values.where((c) => c > 0).length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppUIConstants.spacingXl),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        border: Border.all(color: AppUIConstants.border),
        borderRadius: BorderRadius.circular(AppUIConstants.radiusXl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TOTAL EVENTS',
            style: TextStyle(
              color: AppUIConstants.textSecondary,
              fontSize: 11.5,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Text(
              NumberFormat('#,###').format(totalEvents),
              key: ValueKey(totalEvents),
              style: const TextStyle(
                color: AppUIConstants.textPrimary,
                fontSize: 40,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_rangeLabels[_selectedTimeRange] ?? _selectedTimeRange} · $distinct active event types',
            style: const TextStyle(
              color: AppUIConstants.textSecondary,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- filters

  Widget _buildFilters() {
    const ranges = ['1d', '7d', '30d', '90d'];
    const roles = <(String?, String)>[
      (null, 'All roles'),
      ('owner', 'Owner'),
      ('student', 'Resident'),
      ('admin', 'Admin'),
    ];

    return PremiumCard(
      padding: const EdgeInsets.all(AppUIConstants.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppUIConstants.surfaceMuted,
              borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
            ),
            child: Row(
              children: [
                for (final r in ranges)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (r == _selectedTimeRange) return;
                        setState(() => _selectedTimeRange = r);
                        _reload(timeRange: r);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: r == _selectedTimeRange
                              ? AppUIConstants.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(
                            AppUIConstants.radiusFull,
                          ),
                        ),
                        child: Text(
                          r,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: r == _selectedTimeRange
                                ? Colors.white
                                : AppUIConstants.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppUIConstants.spacingMd),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final r in roles) ...[
                  _RoleChip(
                    label: r.$2,
                    selected: _selectedRole == r.$1,
                    onTap: () {
                      setState(() => _selectedRole = r.$1);
                      _reload(role: r.$1, useCurrentRole: false);
                    },
                  ),
                  const SizedBox(width: AppUIConstants.spacingSm),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------- categories

  Widget _buildEventCategories(Map<String, int> eventCounts) {
    int sum(List<String> keys) =>
        keys.fold<int>(0, (s, k) => s + (eventCounts[k] ?? 0));

    final defs = <(String, IconData, Color, List<String>)>[
      (
        'Stays',
        Icons.badge_rounded,
        AppUIConstants.primaryLight,
        [
          AnalyticsEventNames.membershipCreated,
          AnalyticsEventNames.membershipRenewed,
          AnalyticsEventNames.membershipExpired,
        ],
      ),
      (
        'Attendance',
        Icons.check_circle_rounded,
        AppUIConstants.primaryLight,
        [
          AnalyticsEventNames.attendanceMarked,
          AnalyticsEventNames.bulkAttendanceMarked,
        ],
      ),
      (
        'Invoices',
        Icons.receipt_long_rounded,
        AppUIConstants.primaryLight,
        [
          AnalyticsEventNames.invoiceGenerated,
          AnalyticsEventNames.invoiceDownloaded,
          AnalyticsEventNames.invoiceShared,
        ],
      ),
      (
        'Payments',
        Icons.payments_rounded,
        AppUIConstants.primaryLight,
        [
          AnalyticsEventNames.paymentInitiated,
          AnalyticsEventNames.paymentSuccess,
          AnalyticsEventNames.paymentFailed,
        ],
      ),
      (
        'Beds',
        Icons.bed_rounded,
        AppUIConstants.primaryLight,
        [AnalyticsEventNames.seatAssigned, AnalyticsEventNames.seatUnassigned],
      ),
      (
        'Utilities',
        Icons.build_circle_rounded,
        AppUIConstants.primaryLight,
        [
          AnalyticsEventNames.studentUtilityUsed,
          AnalyticsEventNames.bulkImportUsed,
        ],
      ),
    ];

    final categories = [
      for (final d in defs)
        _EventCategory(
          name: d.$1,
          icon: d.$2,
          color: d.$3,
          events: d.$4,
          totalCount: sum(d.$4),
        ),
    ];

    final maxCount = categories.fold<int>(
      0,
      (m, c) => c.totalCount > m ? c.totalCount : m,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final w = (constraints.maxWidth - gap * 2) / 3;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final c in categories)
              SizedBox(width: w, child: _buildCategoryCard(c, maxCount)),
          ],
        );
      },
    );
  }

  Widget _buildCategoryCard(_EventCategory category, int maxCount) {
    return PremiumCard(
      padding: const EdgeInsets.all(12),
      onTap: () {
        final state = context.read<FeatureAnalyticsCubit>().state;
        _showCategoryDetails(category, state.eventCounts);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppUIConstants.surfaceMuted,
              borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
            ),
            child: Icon(category.icon, color: category.color, size: 18),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              NumberFormat.compact().format(category.totalCount),
              style: AppUIConstants.statValue,
            ),
          ),
          Text(
            category.name,
            style: AppUIConstants.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
            child: TweenAnimationBuilder<double>(
              tween: Tween(
                begin: 0,
                end: maxCount > 0 ? category.totalCount / maxCount : 0,
              ),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 4,
                backgroundColor: AppUIConstants.surfaceMuted,
                valueColor: AlwaysStoppedAnimation(category.color),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard(String message, {IconData icon = Icons.insights_rounded}) {
    return PremiumCard(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 30, color: AppUIConstants.textTertiary),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppUIConstants.bodyMd.copyWith(
                color: AppUIConstants.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------- top features

  String _displayName(String eventName) => eventName
      .replaceAll('_', ' ')
      .split(' ')
      .map(
        (word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1),
      )
      .join(' ');

  Widget _buildTopFeatures(Map<String, int> eventCounts) {
    final sortedEntries = eventCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topEntries = sortedEntries.take(5).toList();
    if (topEntries.isEmpty) return _emptyCard('No data available');

    final features = topEntries.map((entry) {
      return _FeatureUsage(
        _displayName(entry.key),
        entry.value,
        entry.key,
        _getEventColor(entry.key),
      );
    }).toList();
    final maxCount = features.first.count;

    return PremiumCard(
      child: Column(
        children: [
          for (var i = 0; i < features.length; i++) ...[
            if (i > 0) const SizedBox(height: AppUIConstants.spacingLg),
            _buildFeatureRow(i + 1, features[i], maxCount),
          ],
        ],
      ),
    );
  }

  Widget _buildFeatureRow(int rank, _FeatureUsage feature, int maxCount) {
    final fraction = maxCount > 0 ? feature.count / maxCount : 0.0;
    final percentage = (fraction * 100).round();
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppUIConstants.surfaceMuted,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$rank',
                style: TextStyle(
                  color: feature.color,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    feature.name,
                    style: AppUIConstants.bodyMd.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    feature.eventName,
                    style: AppUIConstants.caption.copyWith(
                      fontFamily: 'monospace',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  NumberFormat('#,###').format(feature.count),
                  style: AppUIConstants.bodyLg.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text('$percentage%', style: AppUIConstants.caption),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: fraction),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 6,
              backgroundColor: AppUIConstants.surfaceMuted,
              valueColor: AlwaysStoppedAnimation(feature.color),
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------- roles

  Widget _buildRoleBreakdown(Map<String, int> roleCounts) {
    final total = roleCounts.values.fold<int>(0, (sum, count) => sum + count);

    if (total == 0) return _emptyCard('No data available');

    final roles = [
      _RoleUsage(
        'Owner',
        roleCounts['owner'] ?? 0,
        AppUIConstants.primaryLight,
        ((roleCounts['owner'] ?? 0) / total * 100).round(),
      ),
      _RoleUsage(
        'Resident',
        roleCounts['student'] ?? 0,
        AppUIConstants.secondary,
        ((roleCounts['student'] ?? 0) / total * 100).round(),
      ),
      _RoleUsage(
        'Admin',
        roleCounts['admin'] ?? 0,
        AppUIConstants.textTertiary,
        ((roleCounts['admin'] ?? 0) / total * 100).round(),
      ),
    ];

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Total events', style: AppUIConstants.bodySm),
              ),
              Text(
                NumberFormat('#,###').format(total),
                style: AppUIConstants.headingSm,
              ),
            ],
          ),
          const SizedBox(height: AppUIConstants.spacingMd),
          // Stacked share bar
          ClipRRect(
            borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  for (final r in roles)
                    if (r.eventCount > 0)
                      Expanded(
                        flex: r.eventCount,
                        child: Container(
                          margin: const EdgeInsets.only(right: 2),
                          color: r.color,
                        ),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppUIConstants.spacingLg),
          for (var i = 0; i < roles.length; i++) ...[
            if (i > 0) const SizedBox(height: AppUIConstants.spacingMd),
            _buildRoleItem(roles[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildRoleItem(_RoleUsage role) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: role.color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            role.name,
            style: AppUIConstants.bodyMd.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          NumberFormat('#,###').format(role.eventCount),
          style: AppUIConstants.bodyMd.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 8),
        PremiumStatusPill('${role.percentage}%', color: role.color),
      ],
    );
  }

  // ----------------------------------------------------------- platforms

  Widget _buildPlatformBreakdown(Map<String, int> platformCounts) {
    final total = platformCounts.values.fold<int>(
      0,
      (sum, count) => sum + count,
    );

    if (total == 0) {
      return _emptyCard('No data available', icon: Icons.devices_rounded);
    }

    int pct(String k) => ((platformCounts[k] ?? 0) / total * 100).round();

    final platforms = [
      _PlatformUsage(
        'Android',
        Icons.android_rounded,
        platformCounts['android'] ?? 0,
        AppUIConstants.primaryLight,
        pct('android'),
      ),
      _PlatformUsage(
        'iOS',
        Icons.apple_rounded,
        platformCounts['ios'] ?? 0,
        AppUIConstants.secondary,
        pct('ios'),
      ),
      _PlatformUsage(
        'Web',
        Icons.language_rounded,
        platformCounts['web'] ?? 0,
        AppUIConstants.textTertiary,
        pct('web'),
      ),
    ];

    return Row(
      children: [
        for (var i = 0; i < platforms.length; i++) ...[
          if (i > 0) const SizedBox(width: AppUIConstants.spacingMd),
          Expanded(
            child: PremiumCard(
              padding: const EdgeInsets.all(AppUIConstants.spacingMd),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppUIConstants.surfaceMuted,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      platforms[i].icon,
                      size: 22,
                      color: platforms[i].color,
                    ),
                  ),
                  const SizedBox(height: AppUIConstants.spacingSm),
                  Text(platforms[i].name, style: AppUIConstants.bodySm),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      NumberFormat.compact().format(platforms[i].eventCount),
                      style: AppUIConstants.statValue,
                    ),
                  ),
                  const SizedBox(height: 6),
                  PremiumStatusPill(
                    '${platforms[i].percentage}%',
                    color: platforms[i].color,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // -------------------------------------------------------- recent events

  Widget _buildRecentEvents(List<dynamic> recentEvents) {
    if (recentEvents.isEmpty) {
      return _emptyCard('No recent events', icon: Icons.history_rounded);
    }

    final events = recentEvents.take(10).map((event) {
      final eventName = event.eventName ?? 'Unknown';
      return _RecentEvent(
        _displayName(eventName),
        event.role ?? 'unknown',
        event.libraryId ?? 'N/A',
        event.timestamp ?? DateTime.now(),
        _getEventColor(eventName),
      );
    }).toList();

    return PremiumCard(
      child: Column(
        children: [
          for (var i = 0; i < events.length; i++)
            _buildEventTimelineRow(events[i], i == events.length - 1),
        ],
      ),
    );
  }

  Widget _buildEventTimelineRow(_RecentEvent event, bool isLast) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 16,
            child: Column(
              children: [
                const SizedBox(height: 5),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: event.color,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: AppUIConstants.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppUIConstants.spacingMd),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.eventName,
                          style: AppUIConstants.bodyMd.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${event.role} • ${event.libraryId}',
                          style: AppUIConstants.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatTimeAgo(event.timestamp),
                    style: AppUIConstants.caption,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Color _getEventColor(String eventName) {
    if (eventName.contains('membership') ||
        eventName.contains('attendance') ||
        eventName.contains('invoice') ||
        eventName.contains('payment') ||
        eventName.contains('seat') ||
        eventName.contains('utility')) {
      return AppUIConstants.primaryLight;
    }
    return AppUIConstants.textSecondary;
  }

  // ------------------------------------------------------------- sheets

  void _showCategoryDetails(
    _EventCategory category,
    Map<String, int> eventCounts,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: AppUIConstants.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: AppUIConstants.border)),
        ),
        padding: const EdgeInsets.all(AppUIConstants.spacingXl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppUIConstants.spacingLg),
                decoration: BoxDecoration(
                  color: AppUIConstants.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppUIConstants.surfaceMuted,
                    borderRadius: BorderRadius.circular(
                      AppUIConstants.radiusMd,
                    ),
                  ),
                  child: Icon(category.icon, color: category.color, size: 26),
                ),
                const SizedBox(width: AppUIConstants.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(category.name, style: AppUIConstants.headingSm),
                      Text(
                        '${NumberFormat('#,###').format(category.totalCount)} total events',
                        style: AppUIConstants.bodySm,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppUIConstants.textSecondary,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const PremiumSectionHeader('Event breakdown'),
            Expanded(
              child: ListView.separated(
                itemCount: category.events.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppUIConstants.spacingSm),
                itemBuilder: (context, index) {
                  final event = category.events[index];
                  final count = eventCounts[event] ?? 0;
                  final share = category.totalCount > 0
                      ? count / category.totalCount
                      : 0.0;
                  return Container(
                    padding: const EdgeInsets.all(AppUIConstants.spacingMd),
                    decoration: BoxDecoration(
                      color: AppUIConstants.surfaceMuted,
                      borderRadius: BorderRadius.circular(
                        AppUIConstants.radiusMd,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    event.replaceAll('_', ' ').toUpperCase(),
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppUIConstants.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'Event: $event',
                                    style: AppUIConstants.caption,
                                  ),
                                ],
                              ),
                            ),
                            PremiumStatusPill(
                              NumberFormat('#,###').format(count),
                              color: category.color,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppUIConstants.radiusFull,
                          ),
                          child: LinearProgressIndicator(
                            value: share,
                            minHeight: 5,
                            backgroundColor: AppUIConstants.border,
                            valueColor: AlwaysStoppedAnimation(category.color),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Feature Analytics'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'This dashboard shows real-time feature usage across your platform.',
              ),
              const SizedBox(height: 16),
              _buildHelpItem(
                'Event Categories',
                'Grouped events by feature type (Stays, Attendance, etc.)',
              ),
              _buildHelpItem(
                'Top Features',
                'Most frequently used features ranked by event count',
              ),
              _buildHelpItem(
                'Role Breakdown',
                'Event distribution across Admin, Owner, and Resident roles',
              ),
              _buildHelpItem(
                'Platform Distribution',
                'Usage across Android, iOS, and Web platforms',
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppUIConstants.primarySoft,
                  borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
                ),
                child: const Text(
                  'Tip: Use Firebase Console for detailed queries and custom reports.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppUIConstants.primaryLight,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 20,
            color: AppUIConstants.primaryLight,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppUIConstants.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppUIConstants.primarySoft : Colors.transparent,
          borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
          border: Border.all(
            color: selected
                ? AppUIConstants.primaryLight
                : AppUIConstants.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected
                ? AppUIConstants.primaryLight
                : AppUIConstants.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _FeatureSkeleton extends StatefulWidget {
  const _FeatureSkeleton();

  @override
  State<_FeatureSkeleton> createState() => _FeatureSkeletonState();
}

class _FeatureSkeletonState extends State<_FeatureSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _bone(double h) => Container(
    height: h,
    decoration: BoxDecoration(
      color: AppUIConstants.surfaceMuted,
      borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
    ),
  );

  Widget _row() => Row(
    children: [
      Expanded(child: _bone(104)),
      const SizedBox(width: 12),
      Expanded(child: _bone(104)),
      const SizedBox(width: 12),
      Expanded(child: _bone(104)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(_c),
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppUIConstants.spacingLg),
        children: [
          _bone(120),
          const SizedBox(height: 12),
          _bone(96),
          const SizedBox(height: 24),
          _row(),
          const SizedBox(height: 12),
          _row(),
          const SizedBox(height: 24),
          _bone(200),
        ],
      ),
    );
  }
}

// Data models
class _EventCategory {
  final String name;
  final IconData icon;
  final Color color;
  final List<String> events;
  final int totalCount;

  _EventCategory({
    required this.name,
    required this.icon,
    required this.color,
    required this.events,
    required this.totalCount,
  });
}

class _FeatureUsage {
  final String name;
  final int count;
  final String eventName;
  final Color color;

  _FeatureUsage(this.name, this.count, this.eventName, this.color);
}

class _RoleUsage {
  final String name;
  final int eventCount;
  final Color color;
  final int percentage;

  _RoleUsage(this.name, this.eventCount, this.color, this.percentage);
}

class _PlatformUsage {
  final String name;
  final IconData icon;
  final int eventCount;
  final Color color;
  final int percentage;

  _PlatformUsage(
    this.name,
    this.icon,
    this.eventCount,
    this.color,
    this.percentage,
  );
}

class _RecentEvent {
  final String eventName;
  final String role;
  final String libraryId;
  final DateTime timestamp;
  final Color color;

  _RecentEvent(
    this.eventName,
    this.role,
    this.libraryId,
    this.timestamp,
    this.color,
  );
}
