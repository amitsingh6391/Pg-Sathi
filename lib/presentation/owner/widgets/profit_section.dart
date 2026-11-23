import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/indian_currency_format.dart';
import '../../../domain/entities/expense.dart';
import '../../../domain/usecases/get_revenue_analytics.dart';
import '../../core/app_ui_constants.dart';
import '../../core/widgets/premium_kit.dart';

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
    final tone = isPositive ? AppUIConstants.success : AppUIConstants.error;
    final total = revenue + monthExpenses;
    final revenueFlex = total <= 0 ? 1 : (revenue / total * 100).round();

    return PremiumCard(
      padding: const EdgeInsets.all(AppUIConstants.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MonthNavigator(
            selectedMonth: selectedMonth,
            isCurrentMonth: isCurrentMonth,
            onPrevious: onPreviousMonth,
            onNext: onNextMonth,
          ),
          const SizedBox(height: 18),
          Text(
            isPositive ? 'NET PROFIT' : 'NET LOSS',
            style: TextStyle(
              color: tone,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${isPositive ? '+' : '-'}${indianRupeeCurrencyFormat.format(profit.abs())}',
              style: const TextStyle(
                color: AppUIConstants.textPrimary,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: total <= 0
                  ? const ColoredBox(color: AppUIConstants.surfaceMuted)
                  : Row(
                      children: [
                        Expanded(
                          flex: revenueFlex.clamp(1, 99),
                          child: const ColoredBox(
                            color: AppUIConstants.success,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          flex: (100 - revenueFlex).clamp(1, 99),
                          child: const ColoredBox(color: AppUIConstants.error),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Rent collected',
                  value: indianRupeeCurrencyFormat.format(revenue),
                  color: AppUIConstants.success,
                  icon: Icons.south_west_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(
                  label: 'Expenses',
                  value: indianRupeeCurrencyFormat.format(monthExpenses),
                  color: AppUIConstants.error,
                  icon: Icons.north_east_rounded,
                ),
              ),
            ],
          ),

          // Expense list for selected month
          if (expenses.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(color: AppUIConstants.divider),
            const SizedBox(height: 8),
            Text(
              'Expenses this month',
              style: AppUIConstants.bodySm.copyWith(
                fontWeight: FontWeight.w600,
                color: AppUIConstants.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            ...expenses
                .take(5)
                .map(
                  (e) =>
                      _ExpenseRow(expense: e, onDelete: () => onDelete(e.id)),
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
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppUIConstants.surfaceMuted,
            borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
          ),
          child: const Icon(
            Icons.savings_rounded,
            size: 18,
            color: AppUIConstants.primaryLight,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text('PG profit', style: AppUIConstants.headingSm),
        ),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: AppUIConstants.surfaceMuted,
            borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _NavButton(icon: Icons.chevron_left_rounded, onTap: onPrevious),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  DateFormat('MMM yyyy').format(selectedMonth),
                  style: AppUIConstants.bodySm.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppUIConstants.textPrimary,
                  ),
                ),
              ),
              _NavButton(
                icon: Icons.chevron_right_rounded,
                onTap: isCurrentMonth ? null : onNext,
              ),
            ],
          ),
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
          color: enabled ? AppUIConstants.primarySoft : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled
              ? AppUIConstants.primaryLight
              : AppUIConstants.disabled,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: AppUIConstants.caption,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
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
              color: AppUIConstants.error.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
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
