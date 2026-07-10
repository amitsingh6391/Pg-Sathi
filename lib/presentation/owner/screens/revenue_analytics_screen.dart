import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/indian_currency_format.dart';
import '../../../domain/entities/payment.dart';
import '../../../domain/usecases/get_revenue_analytics.dart';
import '../../core/app_ui_constants.dart';
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Revenue Analytics'),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddExpenseSheet,
        backgroundColor: AppUIConstants.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text(
          'Add Expense',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: BlocBuilder<RevenueAnalyticsCubit, RevenueAnalyticsState>(
        builder: (context, state) {
          if (state.isLoading && !state.hasData) {
            return const Center(child: CircularProgressIndicator());
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
            return const Center(child: Text('No data available'));
          }

          return RefreshIndicator(
            onRefresh: () => context
                .read<RevenueAnalyticsCubit>()
                .loadAnalytics(widget.libraryId),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Library Name
                  Text(widget.libraryName, style: AppUIConstants.headingMd),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMMM yyyy').format(DateTime.now()),
                    style: AppUIConstants.caption,
                  ),
                  const SizedBox(height: 24),

                  // Summary Cards (4 cards now)
                  _SummarySection(analytics: analytics),
                  const SizedBox(height: 24),

                  // Profit Overview (Revenue - Expenses) with month navigation
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
                  const SizedBox(height: 24),

                  // Pie Chart - Payment Distribution
                  _PieChartSection(analytics: analytics),
                  const SizedBox(height: 24),

                  // Banner Ad - placed after summary overview
                  const SizedBox(height: 24),

                  // Line Chart with Period Selector
                  _LineChartSection(
                    analytics: analytics,
                    selectedPeriod: _selectedPeriod,
                    onPeriodChanged: (period) {
                      setState(() => _selectedPeriod = period);
                    },
                  ),
                  const SizedBox(height: 24),

                  // Payment Distribution Details
                  _PaymentDistributionSection(analytics: analytics),
                  const SizedBox(height: 24),

                  // Pending Approvals
                  if (analytics.totalPendingApprovals > 0) ...[
                    _PendingApprovalsSection(analytics: analytics),
                    const SizedBox(height: 24),
                  ],

                  // Recent Payments
                  _RecentPaymentsSection(payments: analytics.recentPayments),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.analytics});

  final RevenueAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Earnings Summary', style: AppUIConstants.headingSm),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                title: 'Today',
                value: indianRupeeCurrencyFormat.format(analytics.todayEarnings),
                icon: Icons.today_outlined,
                color: AppUIConstants.success,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                title: 'This Month',
                value: indianRupeeCurrencyFormat.format(analytics.monthEarnings),
                icon: Icons.calendar_month_outlined,
                color: AppUIConstants.primary,
                isPrimary: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                title: 'This Year',
                value: indianRupeeCurrencyFormat.format(analytics.yearEarnings),
                icon: Icons.date_range_outlined,
                color: AppUIConstants.secondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                title: 'All Time',
                value:
                    indianRupeeCurrencyFormat.format(analytics.allTimeEarnings),
                icon: Icons.all_inclusive,
                color: AppUIConstants.accent,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Pie Chart for payment distribution.
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
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppUIConstants.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Distribution (This Month)',
            style: AppUIConstants.headingSm,
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: [
                        if (analytics.upiPaymentsTotal > 0)
                          PieChartSectionData(
                            value: analytics.upiPaymentsTotal,
                            color: AppUIConstants.secondary,
                            title: '${analytics.upiPercentage.round()}%',
                            titleStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            radius: 50,
                          ),
                        if (analytics.cashPaymentsTotal > 0)
                          PieChartSectionData(
                            value: analytics.cashPaymentsTotal,
                            color: AppUIConstants.accent,
                            title: '${analytics.cashPercentage.round()}%',
                            titleStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            radius: 50,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ChartLegend(color: AppUIConstants.secondary, label: 'UPI'),
                    const SizedBox(height: 12),
                    _ChartLegend(color: AppUIConstants.accent, label: 'Cash'),
                  ],
                ),
              ],
            ),
          ),
        ],
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
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: AppUIConstants.bodyMd),
      ],
    );
  }
}

/// Line Chart for earnings trend.
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

    if (data.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxY = data.fold<double>(
      0,
      (max, d) => d.amount > max ? d.amount : max,
    );
    final compactFormat = NumberFormat.compact(locale: 'en_IN');

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
              Text('Earnings Trend', style: AppUIConstants.headingSm),
              // Period Selector
              Container(
                decoration: BoxDecoration(
                  color: AppUIConstants.divider,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PeriodButton(
                      label: '30 Days',
                      isSelected: selectedPeriod == ChartPeriod.daily,
                      onTap: () => onPeriodChanged(ChartPeriod.daily),
                    ),
                    _PeriodButton(
                      label: '12 Months',
                      isSelected: selectedPeriod == ChartPeriod.monthly,
                      onTap: () => onPeriodChanged(ChartPeriod.monthly),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
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
                          '₹${compactFormat.format(value)}',
                          style: AppUIConstants.caption.copyWith(fontSize: 10),
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
                  // Total line
                  LineChartBarData(
                    spots: data
                        .asMap()
                        .entries
                        .map((e) => FlSpot(e.key.toDouble(), e.value.amount))
                        .toList(),
                    isCurved: true,
                    color: AppUIConstants.primary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppUIConstants.primary.withValues(alpha: 0.1),
                    ),
                  ),
                ],
                minY: 0,
                maxY: maxY > 0 ? maxY * 1.1 : 100,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Legend
          Wrap(
            spacing: 16,
            children: [
              _ChartLegend(
                color: AppUIConstants.primary,
                label: 'Total Earnings',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PeriodButton extends StatelessWidget {
  const _PeriodButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppUIConstants.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: AppUIConstants.caption.copyWith(
            color: isSelected ? Colors.white : AppUIConstants.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.isPrimary = false,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isPrimary
            ? color.withValues(alpha: 0.1)
            : AppUIConstants.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPrimary
              ? color.withValues(alpha: 0.3)
              : AppUIConstants.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(title, style: AppUIConstants.caption),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppUIConstants.headingMd.copyWith(
              color: isPrimary ? color : AppUIConstants.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
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
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppUIConstants.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Payment Distribution', style: AppUIConstants.headingSm),
          const SizedBox(height: 16),

          // Large segmented bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 24,
              child: Row(
                children: [
                  if (analytics.upiPercentage > 0)
                    Expanded(
                      flex: analytics.upiPercentage.round(),
                      child: Container(
                        color: AppUIConstants.secondary,
                        alignment: Alignment.center,
                        child: analytics.upiPercentage > 15
                            ? Text(
                                '${analytics.upiPercentage.round()}%',
                                style: AppUIConstants.caption.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            : null,
                      ),
                    ),
                  if (analytics.cashPercentage > 0)
                    Expanded(
                      flex: analytics.cashPercentage.round(),
                      child: Container(
                        color: AppUIConstants.accent,
                        alignment: Alignment.center,
                        child: analytics.cashPercentage > 15
                            ? Text(
                                '${analytics.cashPercentage.round()}%',
                                style: AppUIConstants.caption.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            : null,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Details
          _PaymentTypeRow(
            color: AppUIConstants.secondary,
            label: 'UPI Direct',
            amount: indianRupeeCurrencyFormat.format(analytics.upiPaymentsTotal),
            percentage: analytics.upiPercentage,
          ),
          const SizedBox(height: 12),
          _PaymentTypeRow(
            color: AppUIConstants.accent,
            label: 'Cash',
            amount: indianRupeeCurrencyFormat.format(analytics.cashPaymentsTotal),
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
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: AppUIConstants.bodyMd)),
        Text(
          amount,
          style: AppUIConstants.bodyMd.copyWith(fontWeight: FontWeight.w600),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppUIConstants.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppUIConstants.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
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
                  'Pending Approvals',
                  style: AppUIConstants.bodyMd.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
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
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${analytics.totalPendingApprovals}',
              style: AppUIConstants.bodyMd.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
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
        Text('Recent Payments', style: AppUIConstants.headingSm),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppUIConstants.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppUIConstants.border),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: payments.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final payment = payments[index];
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _getModeColor(
                          payment.mode,
                        ).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getModeIcon(payment.mode),
                        size: 18,
                        color: _getModeColor(payment.mode),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            payment.mode.displayName,
                            style: AppUIConstants.bodyMd.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
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
                      indianRupeeCurrencyFormat.format(payment.amount),
                      style: AppUIConstants.bodyMd.copyWith(
                        fontWeight: FontWeight.w600,
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

  Color _getModeColor(PaymentMode mode) {
    switch (mode) {
      case PaymentMode.online:
        return AppUIConstants.secondary; // Fallback to UPI color
      case PaymentMode.upi:
        return AppUIConstants.secondary;
      case PaymentMode.cash:
        return AppUIConstants.accent;
    }
  }

  IconData _getModeIcon(PaymentMode mode) {
    switch (mode) {
      case PaymentMode.online:
        return Icons.account_balance_outlined; // Fallback to UPI icon
      case PaymentMode.upi:
        return Icons.account_balance_outlined;
      case PaymentMode.cash:
        return Icons.payments_outlined;
    }
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
          Icon(Icons.error_outline, size: 48, color: AppUIConstants.error),
          const SizedBox(height: 16),
          Text(message, style: AppUIConstants.bodyMd),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
