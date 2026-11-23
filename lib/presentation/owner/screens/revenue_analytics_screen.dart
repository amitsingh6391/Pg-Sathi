import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/indian_currency_format.dart';
import '../../../domain/entities/payment.dart';
import '../../../domain/usecases/get_revenue_analytics.dart';
import '../../core/app_ui_constants.dart';
import '../../core/widgets/premium_kit.dart';
import '../cubit/expense_cubit.dart';
import '../cubit/revenue_analytics_cubit.dart';
import '../widgets/add_expense_sheet.dart';
import '../widgets/profit_section.dart';

/// Time period options for chart display.
enum ChartPeriod { daily, monthly }

/// Detailed revenue analytics screen for owners.
class RevenueAnalyticsScreen extends StatefulWidget {
  const RevenueAnalyticsScreen({
    super.key,
    required this.libraryId,
    required this.libraryName,
  });

  final String libraryId;
  final String libraryName;

  @override
  State<RevenueAnalyticsScreen> createState() => _RevenueAnalyticsScreenState();
}

class _RevenueAnalyticsScreenState extends State<RevenueAnalyticsScreen> {
  ChartPeriod _selectedPeriod = ChartPeriod.daily;
  bool _hasLoadedInitially = false;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  void _loadAnalytics() {
    if (!_isRefreshing) {
      _isRefreshing = true;
      context.read<RevenueAnalyticsCubit>().loadAnalytics(widget.libraryId);
      context.read<ExpenseCubit>().loadMonthExpenses(widget.libraryId);
      _hasLoadedInitially = true;
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _isRefreshing = false;
        }
      });
    }
  }

  void _showAddExpenseSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<ExpenseCubit>(),
        child: AddExpenseSheet(libraryId: widget.libraryId),
      ),
    ).then((saved) {
      if (saved == true && mounted) {
        context.read<RevenueAnalyticsCubit>().loadAnalytics(widget.libraryId);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh when screen becomes visible again (e.g., when navigating back)
    // Only refresh if we've loaded before, route is current, and not already refreshing
    if (_hasLoadedInitially &&
        !_isRefreshing &&
        ModalRoute.of(context)?.isCurrent == true) {
      // Small delay to ensure navigation is complete
      Future.microtask(() {
        if (mounted &&
            ModalRoute.of(context)?.isCurrent == true &&
            !_isRefreshing) {
          _loadAnalytics();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUIConstants.background,
      appBar: AppBar(
        backgroundColor: AppUIConstants.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        iconTheme: const IconThemeData(color: AppUIConstants.textPrimary),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Revenue', style: AppUIConstants.headingMd),
            Text(widget.libraryName, style: AppUIConstants.caption),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddExpenseSheet,
        backgroundColor: AppUIConstants.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text(
          'Add Expense',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: BlocBuilder<RevenueAnalyticsCubit, RevenueAnalyticsState>(
        builder: (context, state) {
          if (state.isLoading && !state.hasData) {
            return const _AnalyticsSkeleton();
          }

          if (state.hasError && !state.hasData) {
            return _ErrorView(
              message: state.errorMessage ?? 'Failed to load',
              onRetry: () => context
                  .read<RevenueAnalyticsCubit>()
                  .loadAnalytics(widget.libraryId),
            );
          }

          final analytics = state.analytics;
          if (analytics == null) {
            return _EmptyAnalytics(onAddExpense: _showAddExpenseSheet);
          }

          return RefreshIndicator(
            color: AppUIConstants.primaryLight,
            backgroundColor: AppUIConstants.surface,
            onRefresh: () => context
                .read<RevenueAnalyticsCubit>()
                .loadAnalytics(widget.libraryId),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeroTotal(analytics: analytics),
                  const SizedBox(height: 12),
                  _SummarySection(analytics: analytics),

                  // Income vs expense breakdown
                  BlocBuilder<ExpenseCubit, ExpenseState>(
                    builder: (context, expenseState) {
                      return _IncomeExpenseTiles(
                        income: analytics.monthEarnings,
                        expense: expenseState.monthTotal,
                      );
                    },
                  ),

                  // Profit Overview (Revenue - Expenses) with month navigation
                  const PremiumSectionHeader('Profit overview'),
                  BlocBuilder<ExpenseCubit, ExpenseState>(
                    builder: (context, expenseState) {
                      return ProfitSection(
                        selectedMonth: expenseState.selectedMonth,
                        monthlyData: analytics.monthlyData,
                        currentMonthRevenue: analytics.monthEarnings,
                        monthExpenses: expenseState.monthTotal,
                        expenses: expenseState.expenses,
                        isCurrentMonth: expenseState.isCurrentMonth,
                        onDelete: (id) =>
                            context.read<ExpenseCubit>().deleteExpense(id),
                        onPreviousMonth: () =>
                            context.read<ExpenseCubit>().goToPreviousMonth(),
                        onNextMonth: () =>
                            context.read<ExpenseCubit>().goToNextMonth(),
                      );
                    },
                  ),

                  // Pending Approvals
                  if (analytics.totalPendingApprovals > 0) ...[
                    const SizedBox(height: 16),
                    _PendingApprovalsSection(analytics: analytics),
                  ],

                  // Line Chart with Period Selector
                  const PremiumSectionHeader('Rent trend'),
                  _LineChartSection(
                    analytics: analytics,
                    selectedPeriod: _selectedPeriod,
                    onPeriodChanged: (period) {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedPeriod = period);
                    },
                  ),

                  // Pie + distribution
                  if (analytics.monthEarnings > 0) ...[
                    const PremiumSectionHeader('How residents paid'),
                    _PieChartSection(analytics: analytics),
                    const SizedBox(height: 12),
                    _PaymentDistributionSection(analytics: analytics),
                  ],

                  // Recent Payments
                  _RecentPaymentsSection(payments: analytics.recentPayments),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Dark-tinted bordered card shared by chart and breakdown sections.
BoxDecoration _panelDecoration() => BoxDecoration(
  color: AppUIConstants.surface,
  borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
  border: Border.all(color: AppUIConstants.border),
);

class _HeroTotal extends StatelessWidget {
  const _HeroTotal({required this.analytics});

  final RevenueAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        // Dark brand card so the white text is readable.
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppUIConstants.primary, AppUIConstants.primaryLight],
        ),
        borderRadius: BorderRadius.circular(AppUIConstants.radiusXl),
        boxShadow: [
          BoxShadow(
            color: AppUIConstants.primary.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${DateFormat('MMMM yyyy').format(DateTime.now()).toUpperCase()}  •  RENT COLLECTED',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 11,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: analytics.monthEarnings),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => Text(
              indianRupeeCurrencyFormat.format(v),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 38,
                fontWeight: FontWeight.bold,
                letterSpacing: -1,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.bolt_rounded,
                  size: 14,
                  color: AppUIConstants.warning,
                ),
                const SizedBox(width: 4),
                Text(
                  'Today ${indianRupeeCurrencyFormat.format(analytics.todayEarnings)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
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

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.analytics});

  final RevenueAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: PremiumStatTile(
            icon: Icons.date_range_outlined,
            value: indianRupeeCurrencyFormat.format(analytics.yearEarnings),
            label: 'This year',
            color: AppUIConstants.primaryLight,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: PremiumStatTile(
            icon: Icons.all_inclusive,
            value: indianRupeeCurrencyFormat.format(analytics.allTimeEarnings),
            label: 'All time',
            color: AppUIConstants.primaryLight,
          ),
        ),
      ],
    );
  }
}

/// Income vs expense for the selected month, with a proportion bar.
class _IncomeExpenseTiles extends StatelessWidget {
  const _IncomeExpenseTiles({required this.income, required this.expense});

  final double income;
  final double expense;

  @override
  Widget build(BuildContext context) {
    final total = income + expense;
    final incomeFlex = total <= 0 ? 1 : (income / total * 100).round();
    final expenseFlex = total <= 0 ? 1 : (expense / total * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PremiumSectionHeader('Income vs expense'),
        Row(
          children: [
            Expanded(
              child: _FlowTile(
                icon: Icons.south_west_rounded,
                label: 'Income',
                value: indianRupeeCurrencyFormat.format(income),
                color: AppUIConstants.success,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _FlowTile(
                icon: Icons.north_east_rounded,
                label: 'Expenses',
                value: indianRupeeCurrencyFormat.format(expense),
                color: AppUIConstants.primaryLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 8,
            child: Row(
              children: [
                Expanded(
                  flex: incomeFlex.clamp(1, 100),
                  child: Container(color: AppUIConstants.chartPrimary),
                ),
                const SizedBox(width: 2),
                Expanded(
                  flex: expenseFlex.clamp(1, 100),
                  child: Container(color: AppUIConstants.chartAccent),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FlowTile extends StatelessWidget {
  const _FlowTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppUIConstants.surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: AppUIConstants.textSecondary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppUIConstants.caption),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: AppUIConstants.headingSm.copyWith(color: color),
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

/// Donut chart for UPI vs cash split.
class _PieChartSection extends StatelessWidget {
  const _PieChartSection({required this.analytics});

  final RevenueAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    if (analytics.monthEarnings == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: SizedBox(
        height: 170,
        child: Row(
          children: [
            Expanded(
              child: PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 44,
                  sections: [
                    if (analytics.upiPaymentsTotal > 0)
                      PieChartSectionData(
                        value: analytics.upiPaymentsTotal,
                        color: AppUIConstants.chartPrimary,
                        title: '${analytics.upiPercentage.round()}%',
                        titleStyle: const TextStyle(
                          color: AppUIConstants.background,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        radius: 26,
                      ),
                    if (analytics.cashPaymentsTotal > 0)
                      PieChartSectionData(
                        value: analytics.cashPaymentsTotal,
                        color: AppUIConstants.chartAccent,
                        title: '${analytics.cashPercentage.round()}%',
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        radius: 26,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 24),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _ChartLegend(color: AppUIConstants.chartPrimary, label: 'UPI'),
                SizedBox(height: 12),
                _ChartLegend(color: AppUIConstants.chartAccent, label: 'Cash'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: AppUIConstants.bodyMd),
      ],
    );
  }
}

/// Line chart for the earnings trend with a segmented period control.
class _LineChartSection extends StatelessWidget {
  const _LineChartSection({
    required this.analytics,
    required this.selectedPeriod,
    required this.onPeriodChanged,
  });

  final RevenueAnalytics analytics;
  final ChartPeriod selectedPeriod;
  final ValueChanged<ChartPeriod> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    final data = selectedPeriod == ChartPeriod.daily
        ? analytics.dailyData
        : analytics.monthlyData;

    final maxY = data.fold<double>(
      0,
      (max, d) => d.amount > max ? d.amount : max,
    );
    final periodTotal = data.fold<double>(0, (sum, d) => sum + d.amount);
    final compactFormat = NumberFormat.compact(locale: 'en_IN');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PeriodSegments(selected: selectedPeriod, onChanged: onPeriodChanged),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Column(
              key: ValueKey(selectedPeriod),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedPeriod == ChartPeriod.daily
                      ? 'LAST 30 DAYS'
                      : 'LAST 12 MONTHS',
                  style: AppUIConstants.caption.copyWith(letterSpacing: 0.8),
                ),
                const SizedBox(height: 2),
                Text(
                  indianRupeeCurrencyFormat.format(periodTotal),
                  style: AppUIConstants.statValue,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (data.isEmpty)
            SizedBox(
              height: 160,
              child: Center(
                child: Text(
                  'No rent collected in this period yet',
                  style: AppUIConstants.bodySm,
                ),
              ),
            )
          else
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
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
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => AppUIConstants.chartTooltip,
                      getTooltipItems: (spots) => spots
                          .map(
                            (s) => LineTooltipItem(
                              indianRupeeCurrencyFormat.format(s.y),
                              const TextStyle(
                                color: AppUIConstants.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '₹${compactFormat.format(value)}',
                            style: AppUIConstants.caption.copyWith(
                              fontSize: 10,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: selectedPeriod == ChartPeriod.daily ? 7 : 2,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= data.length) {
                            return const SizedBox();
                          }

                          final date = data[index].date;
                          final label = selectedPeriod == ChartPeriod.daily
                              ? DateFormat('d/M').format(date)
                              : DateFormat('MMM').format(date);
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              label,
                              style: AppUIConstants.caption.copyWith(
                                fontSize: 10,
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
                  lineBarsData: [
                    LineChartBarData(
                      spots: data
                          .asMap()
                          .entries
                          .map((e) => FlSpot(e.key.toDouble(), e.value.amount))
                          .toList(),
                      isCurved: true,
                      color: AppUIConstants.chartPrimary,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppUIConstants.chartPrimary.withValues(alpha: 0.28),
                            AppUIConstants.chartPrimary.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ],
                  minY: 0,
                  maxY: maxY > 0 ? maxY * 1.1 : 100,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PeriodSegments extends StatelessWidget {
  const _PeriodSegments({required this.selected, required this.onChanged});

  final ChartPeriod selected;
  final ValueChanged<ChartPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget seg(String label, ChartPeriod p) {
      final isSel = p == selected;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(p),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 9),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSel ? AppUIConstants.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                color: isSel ? Colors.white : AppUIConstants.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppUIConstants.background,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        border: Border.all(color: AppUIConstants.border),
      ),
      child: Row(
        children: [
          seg('30 Days', ChartPeriod.daily),
          seg('12 Months', ChartPeriod.monthly),
        ],
      ),
    );
  }
}

class _PaymentDistributionSection extends StatelessWidget {
  const _PaymentDistributionSection({required this.analytics});

  final RevenueAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    if (analytics.monthEarnings == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  if (analytics.upiPercentage > 0)
                    Expanded(
                      flex: analytics.upiPercentage.round().clamp(1, 100),
                      child: Container(color: AppUIConstants.chartPrimary),
                    ),
                  if (analytics.upiPercentage > 0 &&
                      analytics.cashPercentage > 0)
                    const SizedBox(width: 2),
                  if (analytics.cashPercentage > 0)
                    Expanded(
                      flex: analytics.cashPercentage.round().clamp(1, 100),
                      child: Container(color: AppUIConstants.chartAccent),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          _PaymentTypeRow(
            color: AppUIConstants.chartPrimary,
            label: 'UPI Direct',
            amount: indianRupeeCurrencyFormat.format(
              analytics.upiPaymentsTotal,
            ),
            percentage: analytics.upiPercentage,
          ),
          const SizedBox(height: 12),
          _PaymentTypeRow(
            color: AppUIConstants.chartAccent,
            label: 'Cash',
            amount: indianRupeeCurrencyFormat.format(
              analytics.cashPaymentsTotal,
            ),
            percentage: analytics.cashPercentage,
          ),
        ],
      ),
    );
  }
}

class _PaymentTypeRow extends StatelessWidget {
  const _PaymentTypeRow({
    required this.color,
    required this.label,
    required this.amount,
    required this.percentage,
  });

  final Color color;
  final String label;
  final String amount;
  final double percentage;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: AppUIConstants.bodyMd)),
        Text(
          amount,
          style: AppUIConstants.bodyMd.copyWith(
            fontWeight: FontWeight.w700,
            color: AppUIConstants.textPrimary,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 45,
          child: Text(
            '${percentage.round()}%',
            style: AppUIConstants.caption,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _PendingApprovalsSection extends StatelessWidget {
  const _PendingApprovalsSection({required this.analytics});

  final RevenueAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppUIConstants.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
        border: Border.all(
          color: AppUIConstants.warning.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.pending_actions_outlined,
            color: AppUIConstants.warning,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pending approvals',
                  style: AppUIConstants.bodyLg.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${analytics.pendingCashCount} Cash • ${analytics.pendingUpiCount} UPI',
                  style: AppUIConstants.caption,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppUIConstants.warning,
              borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
            ),
            child: Text(
              '${analytics.totalPendingApprovals}',
              style: const TextStyle(
                color: AppUIConstants.background,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentPaymentsSection extends StatelessWidget {
  const _RecentPaymentsSection({required this.payments});

  final List<Payment> payments;

  @override
  Widget build(BuildContext context) {
    if (payments.isEmpty) {
      return const SizedBox.shrink();
    }

    final dateFormat = DateFormat('dd MMM, hh:mm a');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PremiumSectionHeader('Recent payments'),
        Container(
          decoration: _panelDecoration(),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: payments.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, color: AppUIConstants.divider),
            itemBuilder: (context, index) {
              final payment = payments[index];
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppUIConstants.surfaceMuted,
                        borderRadius: BorderRadius.circular(
                          AppUIConstants.radiusSm,
                        ),
                      ),
                      child: Icon(
                        _getModeIcon(payment.mode),
                        size: 18,
                        color: AppUIConstants.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            payment.mode.displayName,
                            style: AppUIConstants.bodyLg,
                          ),
                          if (payment.updatedAt != null)
                            Text(
                              dateFormat.format(payment.updatedAt!),
                              style: AppUIConstants.caption,
                            ),
                        ],
                      ),
                    ),
                    Text(
                      '+${indianRupeeCurrencyFormat.format(payment.amount)}',
                      style: AppUIConstants.bodyLg.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppUIConstants.success,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  IconData _getModeIcon(PaymentMode mode) {
    switch (mode) {
      case PaymentMode.online:
      case PaymentMode.upi:
        return Icons.account_balance_outlined;
      case PaymentMode.cash:
        return Icons.payments_outlined;
    }
  }
}

class _AnalyticsSkeleton extends StatefulWidget {
  const _AnalyticsSkeleton();

  @override
  State<_AnalyticsSkeleton> createState() => _AnalyticsSkeletonState();
}

class _AnalyticsSkeletonState extends State<_AnalyticsSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _block(double h) => Container(
    height: h,
    decoration: BoxDecoration(
      color: AppUIConstants.surface,
      borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
      border: Border.all(color: AppUIConstants.border),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.4, end: 1.0).animate(_c),
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _block(150),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _block(96)),
              const SizedBox(width: 12),
              Expanded(child: _block(96)),
            ],
          ),
          const SizedBox(height: 20),
          _block(280),
        ],
      ),
    );
  }
}

class _EmptyAnalytics extends StatelessWidget {
  const _EmptyAnalytics({required this.onAddExpense});

  final VoidCallback onAddExpense;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(
                color: AppUIConstants.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.insights_rounded,
                size: 40,
                color: AppUIConstants.primaryLight,
              ),
            ),
            const SizedBox(height: 20),
            const Text('No revenue data yet', style: AppUIConstants.headingMd),
            const SizedBox(height: 8),
            const Text(
              'Rent payments and expenses will\nshow up here as they come in.',
              style: AppUIConstants.bodyMd,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onAddExpense,
              style: AppUIConstants.primaryButtonStyle,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add expense'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 48,
            color: AppUIConstants.error,
          ),
          const SizedBox(height: 16),
          Text(message, style: AppUIConstants.bodyMd),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            style: AppUIConstants.primaryButtonStyle,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
