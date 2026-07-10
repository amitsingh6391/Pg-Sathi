import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/indian_currency_format.dart';
import '../../../domain/entities/expense.dart';
import '../../../domain/usecases/get_revenue_analytics.dart';
import '../../core/app_ui_constants.dart';

/// Month-wise profit view: Revenue − Expenses = Profit.
///
/// Uses [monthlyData] (from RevenueAnalytics) to look up revenue for
/// the [selectedMonth], and displays the expense list underneath.
class ProfitSection extends StatelessWidget {
  const ProfitSection({
    super.key,
    required this.selectedMonth,
    required this.monthlyData,
    required this.currentMonthRevenue,
    required this.monthExpenses,
    required this.expenses,
    required this.isCurrentMonth,
    required this.onDelete,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  final DateTime selectedMonth;
  final List<EarningsDataPoint> monthlyData;

  /// Revenue for the current calendar month (live from analytics).
  final double currentMonthRevenue;
  final double monthExpenses;
  final List<Expense> expenses;
  final bool isCurrentMonth;
  final void Function(String id) onDelete;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  /// Resolves revenue for [selectedMonth] from [monthlyData].
  /// Falls back to [currentMonthRevenue] for the current calendar month.
  double get _monthRevenue {
    if (isCurrentMonth) return currentMonthRevenue;

    for (final dp in monthlyData) {
      if (dp.date.year == selectedMonth.year &&
          dp.date.month == selectedMonth.month) {
        return dp.amount;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final revenue = _monthRevenue;
    final profit = revenue - monthExpenses;
    final isPositive = profit >= 0;

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
          _MonthNavigator(
            selectedMonth: selectedMonth,
            isCurrentMonth: isCurrentMonth,
            onPrevious: onPreviousMonth,
            onNext: onNextMonth,
          ),
          const SizedBox(height: 16),

          // Revenue − Expenses = Profit
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Revenue',
                  value: indianRupeeCurrencyFormat.format(revenue),
                  color: AppUIConstants.success,
                ),
              ),
              _Operator('−'),
              Expanded(
                child: _MiniStat(
                  label: 'Expenses',
                  value: indianRupeeCurrencyFormat.format(monthExpenses),
                  color: AppUIConstants.error,
                ),
              ),
              _Operator('='),
              Expanded(
                child: _MiniStat(
                  label: 'Profit',
                  value: indianRupeeCurrencyFormat.format(profit.abs()),
                  color: isPositive
                      ? AppUIConstants.success
                      : AppUIConstants.error,
                  prefix: isPositive ? '+' : '-',
                ),
              ),
            ],
          ),

          // Expense list for selected month
          if (expenses.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(color: AppUIConstants.divider),
            const SizedBox(height: 12),
            Text(
              'Expenses',
              style: AppUIConstants.bodySm.copyWith(
                fontWeight: FontWeight.w600,
                color: AppUIConstants.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            ...expenses.take(5).map(
              (e) => _ExpenseRow(
                expense: e,
                onDelete: () => onDelete(e.id),
              ),
            ),
            if (expenses.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+${expenses.length - 5} more',
                  style: AppUIConstants.caption,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Month Navigator
// ---------------------------------------------------------------------------

class _MonthNavigator extends StatelessWidget {
  const _MonthNavigator({
    required this.selectedMonth,
    required this.isCurrentMonth,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime selectedMonth;
  final bool isCurrentMonth;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Monthly Profit', style: AppUIConstants.headingSm),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _NavButton(
              icon: Icons.chevron_left_rounded,
              onTap: onPrevious,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                DateFormat('MMM yyyy').format(selectedMonth),
                style: AppUIConstants.bodySm.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _NavButton(
              icon: Icons.chevron_right_rounded,
              onTap: isCurrentMonth ? null : onNext,
            ),
          ],
        ),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: enabled
              ? AppUIConstants.primary.withValues(alpha: 0.08)
              : AppUIConstants.divider,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled
              ? AppUIConstants.primary
              : AppUIConstants.disabled,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _Operator extends StatelessWidget {
  const _Operator(this.symbol);

  final String symbol;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        symbol,
        style: TextStyle(
          fontSize: 20,
          color: AppUIConstants.textTertiary,
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
    this.prefix,
  });

  final String label;
  final String value;
  final Color color;
  final String? prefix;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: AppUIConstants.caption),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            prefix != null ? '$prefix$value' : value,
            style: AppUIConstants.bodySm.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({required this.expense, required this.onDelete});

  final Expense expense;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppUIConstants.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              size: 16,
              color: AppUIConstants.error,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.title,
                  style: AppUIConstants.bodySm.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${expense.category.displayName} • ${DateFormat('dd MMM').format(expense.date)}',
                  style: AppUIConstants.caption.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            indianRupeeCurrencyFormat.format(expense.amount),
            style: AppUIConstants.bodySm.copyWith(
              fontWeight: FontWeight.w600,
              color: AppUIConstants.error,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onDelete,
            child: Icon(
              Icons.close_rounded,
              size: 16,
              color: AppUIConstants.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
