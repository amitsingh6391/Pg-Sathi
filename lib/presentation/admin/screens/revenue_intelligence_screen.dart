import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/revenue_stats.dart';
import '../../core/app_ui_constants.dart';
import '../cubit/admin_intelligence_cubit.dart';

/// Simple, clean Revenue Analytics Screen with meaningful insights.
class RevenueIntelligenceScreen extends StatelessWidget {
  const RevenueIntelligenceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUIConstants.background,
      appBar: AppBar(
        title: const Text('Revenue Analytics'),
        backgroundColor: AppUIConstants.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => context.read<AdminIntelligenceCubit>().loadDashboard(),
          ),
        ],
      ),
      body: BlocBuilder<AdminIntelligenceCubit, AdminIntelligenceState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final stats = state.revenueStats;

          // Calculate total payments from all plans
          final totalPayments = stats.planWiseBreakdown.fold<int>(
            0,
            (sum, plan) => sum + plan.subscriptionCount,
          );

          // Calculate average payment amount
          final avgPayment = totalPayments > 0
              ? stats.lifetimeRevenue / totalPayments
              : 0.0;

          return RefreshIndicator(
            onRefresh: () => context.read<AdminIntelligenceCubit>().loadDashboard(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Total Revenue Hero
                _buildTotalRevenueCard(stats),
                const SizedBox(height: 16),

                // Revenue Breakdown Row
                _buildRevenueRow(stats),
                const SizedBox(height: 16),

                // Key Insights Row
                _buildInsightsRow(stats, avgPayment),
                const SizedBox(height: 16),

                // Monthly Revenue Chart
                _buildMonthlyChart(stats.monthlyData),
                const SizedBox(height: 16),

                // Library Growth Chart (unique libraries per month)
                _buildLibraryGrowthChart(stats),
                const SizedBox(height: 16),

                // Day-wise Revenue (Last 7 Days)
                _buildDayWiseChart(stats),
                const SizedBox(height: 16),

                // Library & Payment Stats
                _buildStatsCards(stats, totalPayments, avgPayment),
                const SizedBox(height: 16),

                // Summary Insight Card (at bottom)
                _buildSummaryInsightCard(stats, totalPayments),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTotalRevenueCard(RevenueStats stats) {
    // Calculate growth
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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppUIConstants.primary, AppUIConstants.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Revenue',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              if (growth != 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (growth >= 0 ? Colors.green : Colors.red).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        growth >= 0 ? Icons.trending_up : Icons.trending_down,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${growth.abs().toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '₹${_formatAmount(stats.lifetimeRevenue)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Lifetime earnings',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueRow(RevenueStats stats) {
    return Row(
      children: [
        Expanded(child: _buildRevenueCard('Today', stats.todayRevenue, AppUIConstants.success)),
        const SizedBox(width: 10),
        Expanded(child: _buildRevenueCard('This Week', stats.weekRevenue, AppUIConstants.accent)),
        const SizedBox(width: 10),
        Expanded(child: _buildRevenueCard('This Month', stats.monthRevenue, AppUIConstants.primary)),
      ],
    );
  }

  Widget _buildRevenueCard(String label, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppUIConstants.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: AppUIConstants.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            '₹${_formatCompact(amount)}',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsRow(RevenueStats stats, double avgPayment) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppUIConstants.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Insights',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInsightItem(
                  'Net MRR',
                  '₹${_formatCompact(stats.mrr)}',
                  'Billed today',
                  Icons.autorenew_rounded,
                  AppUIConstants.accent,
                ),
              ),
              _verticalDivider(),
              Expanded(
                child: _buildInsightItem(
                  'List MRR',
                  '₹${_formatCompact(stats.listPriceMrr)}',
                  'At renewal price',
                  Icons.trending_up_rounded,
                  AppUIConstants.primary,
                ),
              ),
              _verticalDivider(),
              Expanded(
                child: _buildInsightItem(
                  'Avg Payment',
                  '₹${_formatCompact(avgPayment)}',
                  'Per transaction',
                  Icons.payments_rounded,
                  AppUIConstants.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInsightItem(String title, String value, String subtitle, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: TextStyle(fontSize: 10, color: AppUIConstants.textSecondary),
        ),
        Text(
          subtitle,
          style: TextStyle(fontSize: 9, color: AppUIConstants.textTertiary),
        ),
      ],
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 1,
      height: 50,
      color: AppUIConstants.divider,
    );
  }

  Widget _buildMonthlyChart(List<MonthlyRevenuePoint> data) {
    if (data.length < 2) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppUIConstants.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppUIConstants.border),
        ),
        child: Center(
          child: Text(
            'Not enough data',
            style: TextStyle(color: AppUIConstants.textSecondary),
          ),
        ),
      );
    }

    final maxY = data.fold<double>(0, (max, d) => d.revenue > max ? d.revenue : max);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppUIConstants.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Monthly Revenue',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
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
                  getDrawingHorizontalLine: (value) =>
                      FlLine(color: AppUIConstants.border, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '₹${_formatCompact(value)}',
                          style: TextStyle(fontSize: 9, color: AppUIConstants.textSecondary),
                        );
                      },
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
                              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.normal,
                              color: isCurrent ? AppUIConstants.primary : AppUIConstants.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        color: isCurrent
                            ? AppUIConstants.primary
                            : AppUIConstants.primary.withValues(alpha: 0.4),
                      ),
                    ],
                  );
                }).toList(),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, gIdx, rod, rIdx) {
                      final i = group.x;
                      if (i < 0 || i >= data.length) return null;
                      final d = data[i];
                      return BarTooltipItem(
                        '${DateFormat('MMM yy').format(d.date)}\n₹${NumberFormat('#,##,###').format(d.revenue)}',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayWiseChart(RevenueStats stats) {
    // Days with no payments must render as \u20B90 \u2014 never fabricate values.
    final days = stats.dailyRevenueData
        .map((p) => _DayData(date: p.date, revenue: p.revenue))
        .toList(growable: false);
    final dailyTotal = days.fold<double>(0, (sum, d) => sum + d.revenue);

    final maxY = days.fold<double>(0, (max, d) => d.revenue > max ? d.revenue : max);
    if (days.isEmpty || maxY == 0) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppUIConstants.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppUIConstants.border),
        ),
        child: Center(
          child: Text(
            days.isEmpty
                ? 'No daily data available'
                : 'No payments in the last 7 days',
            style: TextStyle(color: AppUIConstants.textSecondary),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppUIConstants.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Last 7 Days',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              Text(
                '₹${_formatCompact(dailyTotal)} total',
                style: TextStyle(fontSize: 12, color: AppUIConstants.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY > 0 ? maxY * 1.2 : 100,
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                            isToday ? 'Today' : DateFormat('EEE').format(days[i].date),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: isToday ? FontWeight.w700 : FontWeight.normal,
                              color: isToday ? AppUIConstants.success : AppUIConstants.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        color: isToday
                            ? AppUIConstants.success
                            : AppUIConstants.success.withValues(alpha: 0.4),
                      ),
                    ],
                  );
                }).toList(),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, gIdx, rod, rIdx) {
                      final i = group.x;
                      if (i < 0 || i >= days.length) return null;
                      final d = days[i];
                      return BarTooltipItem(
                        '${DateFormat('EEE, MMM d').format(d.date)}\n₹${NumberFormat('#,##,###').format(d.revenue)}',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(RevenueStats stats, int totalPayments, double avgPayment) {
    final growth = stats.subscriptionGrowthPercent;
    final isPositiveGrowth = growth >= 0;
    
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Active Now',
                '${stats.activeSubscriptions}',
                'Subscription valid today',
                Icons.verified_rounded,
                AppUIConstants.success,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Churned',
                '${stats.churnedLibraries}',
                'Expired / cancelled',
                Icons.cancel_rounded,
                AppUIConstants.error,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'This Month',
                '${stats.thisMonthSubscriptions}',
                'New libraries joined',
                Icons.calendar_month_rounded,
                AppUIConstants.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Growth',
                '${isPositiveGrowth ? '+' : ''}${growth.toStringAsFixed(0)}%',
                'vs last month (${stats.lastMonthSubscriptions} new)',
                isPositiveGrowth ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                isPositiveGrowth ? AppUIConstants.success : AppUIConstants.error,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppUIConstants.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  title,
                  style: TextStyle(fontSize: 12, color: AppUIConstants.textSecondary),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 10, color: AppUIConstants.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLibraryGrowthChart(RevenueStats stats) {
    final data = stats.monthlySubscriptionData;
    if (data.length < 2) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppUIConstants.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppUIConstants.border),
        ),
        child: Center(
          child: Text(
            'Not enough data',
            style: TextStyle(color: AppUIConstants.textSecondary),
          ),
        ),
      );
    }

    final maxY = data.fold<int>(0, (max, d) => d.count > max ? d.count : max);
    // Use paidLibraries as the total (unique libraries that ever paid)
    final totalLibraries = stats.paidLibraries;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppUIConstants.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Library Growth',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              Text(
                '$totalLibraries total libraries',
                style: TextStyle(fontSize: 12, color: AppUIConstants.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'New libraries joining each month',
            style: TextStyle(fontSize: 10, color: AppUIConstants.textTertiary),
          ),
          const SizedBox(height: 16),
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
                  getDrawingHorizontalLine: (value) =>
                      FlLine(color: AppUIConstants.border, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(fontSize: 9, color: AppUIConstants.textSecondary),
                        );
                      },
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
                              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.normal,
                              color: isCurrent ? AppUIConstants.accent : AppUIConstants.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        color: isCurrent
                            ? AppUIConstants.accent
                            : AppUIConstants.accent.withValues(alpha: 0.4),
                      ),
                    ],
                  );
                }).toList(),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, gIdx, rod, rIdx) {
                      final i = group.x;
                      if (i < 0 || i >= data.length) return null;
                      final d = data[i];
                      return BarTooltipItem(
                        '${DateFormat('MMM yy').format(d.date)}\n${d.count} new libraries',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryInsightCard(RevenueStats stats, int totalPayments) {
    // Calculate key insights
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppUIConstants.primary.withValues(alpha: 0.05),
            AppUIConstants.accent.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppUIConstants.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded, size: 18, color: AppUIConstants.primary),
              const SizedBox(width: 8),
              const Text(
                'Summary Insights',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInsightRow(
            'Avg Revenue / Library',
            '₹${_formatCompact(avgRevenuePerLibrary)}',
            'Lifetime value per paying library',
          ),
          const Divider(height: 20),
          _buildInsightRow(
            'Retention Rate',
            '${retentionRate.toStringAsFixed(0)}%',
            '${stats.activeSubscriptions} of ${stats.paidLibraries} still active',
          ),
          const Divider(height: 20),
          _buildInsightRow(
            'Revenue Growth',
            '${revenueGrowth >= 0 ? '+' : ''}${revenueGrowth.toStringAsFixed(1)}%',
            'This month vs last month',
            valueColor: revenueGrowth >= 0 ? AppUIConstants.success : AppUIConstants.error,
          ),
          const Divider(height: 20),
          _buildInsightRow(
            'Total Transactions',
            '$totalPayments',
            'All time payment records',
          ),
        ],
      ),
    );
  }

  Widget _buildInsightRow(String label, String value, String description, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              Text(
                description,
                style: TextStyle(fontSize: 10, color: AppUIConstants.textTertiary),
              ),
            ],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
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
