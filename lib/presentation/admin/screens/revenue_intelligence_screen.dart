import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/revenue_stats.dart';
import '../../core/app_ui_constants.dart';
import '../../core/widgets/premium_kit.dart';
import '../cubit/admin_intelligence_cubit.dart';

enum _Period { today, week, month, lifetime }

/// Dark premium revenue console: hero figure, period selector, KPI grid,
/// charts and ranked plan list.
class RevenueIntelligenceScreen extends StatefulWidget {
  const RevenueIntelligenceScreen({super.key});

  @override
  State<RevenueIntelligenceScreen> createState() =>
      _RevenueIntelligenceScreenState();
}

class _RevenueIntelligenceScreenState extends State<RevenueIntelligenceScreen> {
  _Period _period = _Period.lifetime;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUIConstants.background,
      appBar: AppBar(
        title: const Text('Revenue Analytics', style: AppUIConstants.headingSm),
        backgroundColor: AppUIConstants.background,
        foregroundColor: AppUIConstants.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () =>
                context.read<AdminIntelligenceCubit>().loadDashboard(),
          ),
        ],
      ),
      body: BlocBuilder<AdminIntelligenceCubit, AdminIntelligenceState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const _RevenueSkeleton();
          }

          final stats = state.revenueStats;

          final totalPayments = stats.planWiseBreakdown.fold<int>(
            0,
            (sum, plan) => sum + plan.subscriptionCount,
          );
          final avgPayment = totalPayments > 0
              ? stats.lifetimeRevenue / totalPayments
              : 0.0;

          return RefreshIndicator(
            color: AppUIConstants.primaryLight,
            backgroundColor: AppUIConstants.surface,
            onRefresh: () =>
                context.read<AdminIntelligenceCubit>().loadDashboard(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                _buildHero(stats),
                const SizedBox(height: 12),
                _buildKpiGrid(stats, avgPayment),
                const PremiumSectionHeader('Revenue trends'),
                _buildMonthlyChart(stats.monthlyData),
                const SizedBox(height: 12),
                _buildDayWiseChart(stats),
                const PremiumSectionHeader('PG growth'),
                _buildLibraryGrowthChart(stats),
                const PremiumSectionHeader('Subscriptions'),
                _buildStatsCards(stats),
                if (stats.planWiseBreakdown.isNotEmpty) ...[
                  const PremiumSectionHeader('Top plans by revenue'),
                  _buildPlanRanking(stats.planWiseBreakdown),
                ],
                const PremiumSectionHeader('Summary'),
                _buildSummaryInsightCard(stats, totalPayments),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------- hero

  double _periodValue(RevenueStats s) {
    switch (_period) {
      case _Period.today:
        return s.todayRevenue;
      case _Period.week:
        return s.weekRevenue;
      case _Period.month:
        return s.monthRevenue;
      case _Period.lifetime:
        return s.lifetimeRevenue;
    }
  }

  String _periodCaption() {
    switch (_period) {
      case _Period.today:
        return 'Collected today';
      case _Period.week:
        return 'Collected this week';
      case _Period.month:
        return 'Collected this month';
      case _Period.lifetime:
        return 'Lifetime earnings';
    }
  }

  Widget _buildHero(RevenueStats stats) {
    double growth = 0;
    if (stats.monthlyData.length >= 2) {
      final current = stats.monthlyData.last.revenue;
      final previous = stats.monthlyData[stats.monthlyData.length - 2].revenue;
      if (previous > 0) {
        growth = ((current - previous) / previous) * 100;
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        border: Border.all(color: AppUIConstants.border),
        borderRadius: BorderRadius.circular(AppUIConstants.radiusXl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'TOTAL REVENUE',
                  style: TextStyle(
                    color: AppUIConstants.textSecondary,
                    fontSize: 11.5,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (growth != 0)
                PremiumStatusPill(
                  '${growth >= 0 ? '+' : '-'}${growth.abs().toStringAsFixed(1)}% MoM',
                  color: growth >= 0
                      ? AppUIConstants.success
                      : AppUIConstants.error,
                ),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Text(
              '₹${_formatAmount(_periodValue(stats))}',
              key: ValueKey(_period),
              style: const TextStyle(
                color: AppUIConstants.textPrimary,
                fontSize: 40,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _periodCaption(),
            style: const TextStyle(
              color: AppUIConstants.textSecondary,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 18),
          _PeriodSelector(
            value: _period,
            onChanged: (p) => setState(() => _period = p),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ KPI grid

  Widget _buildKpiGrid(RevenueStats stats, double avgPayment) {
    final tiles = <Widget>[
      PremiumStatTile(
        icon: Icons.autorenew_rounded,
        value: '₹${_formatCompact(stats.mrr)}',
        label: 'Net MRR · billed today',
        color: AppUIConstants.primaryLight,
      ),
      PremiumStatTile(
        icon: Icons.trending_up_rounded,
        value: '₹${_formatCompact(stats.listPriceMrr)}',
        label: 'List MRR · renewal price',
        color: AppUIConstants.primaryLight,
      ),
      PremiumStatTile(
        icon: Icons.payments_rounded,
        value: '₹${_formatCompact(avgPayment)}',
        label: 'Avg payment',
        color: AppUIConstants.primaryLight,
      ),
      PremiumStatTile(
        icon: Icons.calendar_month_rounded,
        value: '₹${_formatCompact(stats.monthRevenue)}',
        label: 'This month',
        color: AppUIConstants.primaryLight,
      ),
    ];
    return PremiumTwoColumnGrid(children: tiles);
  }

  // -------------------------------------------------------------- charts

  Widget _emptyCard(String message) {
    return PremiumCard(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.bar_chart_rounded,
              size: 32,
              color: AppUIConstants.textTertiary,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(color: AppUIConstants.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chartTitle(String title, {String? trailing, String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: AppUIConstants.bodyLg)),
              if (trailing != null)
                Text(
                  trailing,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppUIConstants.primaryLight,
                  ),
                ),
            ],
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(subtitle, style: AppUIConstants.caption),
            ),
        ],
      ),
    );
  }

  BarTouchTooltipData _tooltip(
    BarTooltipItem? Function(BarChartGroupData) build,
  ) {
    return BarTouchTooltipData(
      getTooltipColor: (_) => AppUIConstants.chartTooltip,
      getTooltipItem: (group, gIdx, rod, rIdx) => build(group),
    );
  }

  static const _tooltipStyle = TextStyle(
    color: AppUIConstants.textPrimary,
    fontWeight: FontWeight.w600,
    fontSize: 12,
  );

  Widget _buildMonthlyChart(List<MonthlyRevenuePoint> data) {
    if (data.length < 2) return _emptyCard('Not enough data');

    final maxY = data.fold<double>(
      0,
      (max, d) => d.revenue > max ? d.revenue : max,
    );

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _chartTitle(
            'Monthly revenue',
            trailing: '₹${_formatCompact(data.last.revenue)} this month',
          ),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY > 0 ? maxY * 1.15 : 100,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY > 0 ? maxY / 4 : 1,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppUIConstants.chartGrid,
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 48,
                      getTitlesWidget: (value, meta) => Text(
                        '₹${_formatCompact(value)}',
                        style: AppUIConstants.caption.copyWith(fontSize: 9),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= data.length) return const SizedBox();
                        final isCurrent = i == data.length - 1;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            DateFormat('MMM').format(data[i].date),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: isCurrent
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                              color: isCurrent
                                  ? AppUIConstants.chartPrimary
                                  : AppUIConstants.textSecondary,
                            ),
                          ),
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
                barGroups: data.asMap().entries.map((entry) {
                  final isCurrent = entry.key == data.length - 1;
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value.revenue,
                        width: 18,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                        color: isCurrent
                            ? AppUIConstants.chartPrimary
                            : AppUIConstants.chartPrimary.withValues(
                                alpha: 0.35,
                              ),
                      ),
                    ],
                  );
                }).toList(),
                barTouchData: BarTouchData(
                  touchTooltipData: _tooltip((group) {
                    final i = group.x;
                    if (i < 0 || i >= data.length) return null;
                    final d = data[i];
                    return BarTooltipItem(
                      '${DateFormat('MMM yy').format(d.date)}\n₹${NumberFormat('#,##,###').format(d.revenue)}',
                      _tooltipStyle,
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayWiseChart(RevenueStats stats) {
    // Days with no payments must render as ₹0 — never fabricate values.
    final days = stats.dailyRevenueData
        .map((p) => _DayData(date: p.date, revenue: p.revenue))
        .toList(growable: false);
    final dailyTotal = days.fold<double>(0, (sum, d) => sum + d.revenue);

    final maxY = days.fold<double>(
      0,
      (max, d) => d.revenue > max ? d.revenue : max,
    );
    if (days.isEmpty || maxY == 0) {
      return _emptyCard(
        days.isEmpty
            ? 'No daily data available'
            : 'No payments in the last 7 days',
      );
    }

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _chartTitle(
            'Last 7 days',
            trailing: '₹${_formatCompact(dailyTotal)} total',
          ),
          SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY * 1.2,
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= days.length) return const SizedBox();
                        final isToday = i == days.length - 1;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            isToday
                                ? 'Today'
                                : DateFormat('EEE').format(days[i].date),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: isToday
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                              color: isToday
                                  ? AppUIConstants.secondary
                                  : AppUIConstants.textSecondary,
                            ),
                          ),
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
                barGroups: days.asMap().entries.map((entry) {
                  final isToday = entry.key == days.length - 1;
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value.revenue,
                        width: 24,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                        color: isToday
                            ? AppUIConstants.chartPrimary
                            : AppUIConstants.chartPrimary.withValues(
                                alpha: 0.35,
                              ),
                      ),
                    ],
                  );
                }).toList(),
                barTouchData: BarTouchData(
                  touchTooltipData: _tooltip((group) {
                    final i = group.x;
                    if (i < 0 || i >= days.length) return null;
                    final d = days[i];
                    return BarTooltipItem(
                      '${DateFormat('EEE, MMM d').format(d.date)}\n₹${NumberFormat('#,##,###').format(d.revenue)}',
                      _tooltipStyle,
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLibraryGrowthChart(RevenueStats stats) {
    final data = stats.monthlySubscriptionData;
    if (data.length < 2) return _emptyCard('Not enough data');

    final maxY = data.fold<int>(0, (max, d) => d.count > max ? d.count : max);
    final totalLibraries = stats.paidLibraries;

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _chartTitle(
            'New PGs per month',
            trailing: '$totalLibraries total PGs',
            subtitle: 'PGs joining each month',
          ),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY > 0 ? (maxY * 1.2).toDouble() : 10,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY > 4 ? (maxY / 4).toDouble() : 1,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppUIConstants.chartGrid,
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: AppUIConstants.caption.copyWith(fontSize: 9),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= data.length) return const SizedBox();
                        final isCurrent = i == data.length - 1;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            DateFormat('MMM').format(data[i].date),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: isCurrent
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                              color: isCurrent
                                  ? AppUIConstants.secondary
                                  : AppUIConstants.textSecondary,
                            ),
                          ),
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
                barGroups: data.asMap().entries.map((entry) {
                  final isCurrent = entry.key == data.length - 1;
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value.count.toDouble(),
                        width: 18,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                        color: isCurrent
                            ? AppUIConstants.secondary
                            : AppUIConstants.secondary.withValues(alpha: 0.35),
                      ),
                    ],
                  );
                }).toList(),
                barTouchData: BarTouchData(
                  touchTooltipData: _tooltip((group) {
                    final i = group.x;
                    if (i < 0 || i >= data.length) return null;
                    final d = data[i];
                    return BarTooltipItem(
                      '${DateFormat('MMM yy').format(d.date)}\n${d.count} new PGs',
                      _tooltipStyle,
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------ subscriptions

  Widget _buildStatsCards(RevenueStats stats) {
    final growth = stats.subscriptionGrowthPercent;
    final isPositiveGrowth = growth >= 0;
    return PremiumTwoColumnGrid(
      children: [
        PremiumStatTile(
          icon: Icons.verified_rounded,
          value: '${stats.activeSubscriptions}',
          label: 'Active now',
          color: AppUIConstants.success,
        ),
        PremiumStatTile(
          icon: Icons.cancel_rounded,
          value: '${stats.churnedLibraries}',
          label: 'Churned · expired / cancelled',
          color: AppUIConstants.error,
        ),
        PremiumStatTile(
          icon: Icons.add_home_work_rounded,
          value: '${stats.thisMonthSubscriptions}',
          label: 'New PGs this month',
          color: AppUIConstants.primaryLight,
        ),
        PremiumStatTile(
          icon: isPositiveGrowth
              ? Icons.trending_up_rounded
              : Icons.trending_down_rounded,
          value: '${isPositiveGrowth ? '+' : ''}${growth.toStringAsFixed(0)}%',
          label: 'vs last month (${stats.lastMonthSubscriptions} new)',
          color: isPositiveGrowth
              ? AppUIConstants.success
              : AppUIConstants.error,
        ),
      ],
    );
  }

  Widget _buildPlanRanking(List<PlanRevenueBreakdown> plans) {
    final sorted = [...plans]..sort((a, b) => b.revenue.compareTo(a.revenue));
    final top = sorted.first.revenue;
    final total = sorted.fold<double>(0, (s, p) => s + p.revenue);
    return PremiumCard(
      child: Column(
        children: [
          for (var i = 0; i < sorted.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            _RankedRow(
              rank: i + 1,
              title: sorted[i].planName,
              subtitle:
                  '${sorted[i].subscriptionCount} payments · ${total > 0 ? (sorted[i].revenue / total * 100).toStringAsFixed(0) : 0}% share',
              value: '₹${_formatCompact(sorted[i].revenue)}',
              progress: top > 0 ? sorted[i].revenue / top : 0,
              color: i == 0
                  ? AppUIConstants.secondary
                  : AppUIConstants.chartPrimary,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryInsightCard(RevenueStats stats, int totalPayments) {
    final avgRevenuePerLibrary = stats.paidLibraries > 0
        ? stats.lifetimeRevenue / stats.paidLibraries
        : 0.0;
    final retentionRate = stats.paidLibraries > 0
        ? (stats.activeSubscriptions / stats.paidLibraries) * 100
        : 0.0;
    final revenueGrowth = stats.monthlyData.length >= 2
        ? _calculateGrowth(
            stats.monthlyData[stats.monthlyData.length - 2].revenue,
            stats.monthlyData.last.revenue,
          )
        : 0.0;

    return PremiumCard(
      child: Column(
        children: [
          _buildInsightRow(
            Icons.home_work_rounded,
            'Avg revenue / PG',
            '₹${_formatCompact(avgRevenuePerLibrary)}',
            'Lifetime value per paying PG',
          ),
          const Divider(height: 24, color: AppUIConstants.divider),
          _buildInsightRow(
            Icons.shield_rounded,
            'Retention rate',
            '${retentionRate.toStringAsFixed(0)}%',
            '${stats.activeSubscriptions} of ${stats.paidLibraries} still active',
          ),
          const Divider(height: 24, color: AppUIConstants.divider),
          _buildInsightRow(
            Icons.show_chart_rounded,
            'Revenue growth',
            '${revenueGrowth >= 0 ? '+' : ''}${revenueGrowth.toStringAsFixed(1)}%',
            'This month vs last month',
            valueColor: revenueGrowth >= 0
                ? AppUIConstants.success
                : AppUIConstants.error,
          ),
          const Divider(height: 24, color: AppUIConstants.divider),
          _buildInsightRow(
            Icons.receipt_long_rounded,
            'Total transactions',
            '$totalPayments',
            'All time payment records',
          ),
        ],
      ),
    );
  }

  Widget _buildInsightRow(
    IconData icon,
    String label,
    String value,
    String description, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppUIConstants.surfaceMuted,
            borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
          ),
          child: Icon(icon, size: 16, color: AppUIConstants.primaryLight),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppUIConstants.bodyMd),
              Text(description, style: AppUIConstants.caption),
            ],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: valueColor ?? AppUIConstants.textPrimary,
          ),
        ),
      ],
    );
  }

  double _calculateGrowth(double previous, double current) {
    if (previous == 0) return current > 0 ? 100.0 : 0.0;
    return ((current - previous) / previous) * 100;
  }

  String _formatAmount(double amount) {
    return NumberFormat('#,##,###', 'en_IN').format(amount.round());
  }

  String _formatCompact(double amount) {
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.toStringAsFixed(0);
  }
}

class _DayData {
  final DateTime date;
  final double revenue;
  _DayData({required this.date, required this.revenue});
}

/// Segmented pill selector living on the hero gradient.
class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.value, required this.onChanged});

  final _Period value;
  final ValueChanged<_Period> onChanged;

  static const _labels = {
    _Period.today: 'Today',
    _Period.week: 'Week',
    _Period.month: 'Month',
    _Period.lifetime: 'All time',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppUIConstants.surfaceMuted,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
      ),
      child: Row(
        children: [
          for (final p in _Period.values)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(p),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p == value
                        ? AppUIConstants.surface
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(
                      AppUIConstants.radiusFull,
                    ),
                  ),
                  child: Text(
                    _labels[p]!,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: p == value
                          ? AppUIConstants.primaryLight
                          : AppUIConstants.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Two-column grid of equal-height tiles without fixed aspect ratio.
class _RankedRow extends StatelessWidget {
  const _RankedRow({
    required this.rank,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.progress,
    required this.color,
  });

  final int rank;
  final String title;
  final String subtitle;
  final String value;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
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
                style: const TextStyle(
                  color: AppUIConstants.primaryLight,
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
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppUIConstants.bodyMd,
                  ),
                  Text(subtitle, style: AppUIConstants.caption),
                ],
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: AppUIConstants.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 6,
              backgroundColor: AppUIConstants.surfaceMuted,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
      ],
    );
  }
}

class _RevenueSkeleton extends StatefulWidget {
  const _RevenueSkeleton();

  @override
  State<_RevenueSkeleton> createState() => _RevenueSkeletonState();
}

class _RevenueSkeletonState extends State<_RevenueSkeleton>
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

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(_c),
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        children: [
          _bone(190),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _bone(96)),
              const SizedBox(width: 12),
              Expanded(child: _bone(96)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _bone(96)),
              const SizedBox(width: 12),
              Expanded(child: _bone(96)),
            ],
          ),
          const SizedBox(height: 20),
          _bone(260),
        ],
      ),
    );
  }
}
