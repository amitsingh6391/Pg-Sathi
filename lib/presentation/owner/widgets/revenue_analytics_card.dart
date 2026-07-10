import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/indian_currency_format.dart';
import '../../../domain/usecases/get_revenue_analytics.dart';
import '../../core/app_ui_constants.dart';
import '../cubit/revenue_analytics_cubit.dart';

/// Large revenue analytics card for the owner dashboard.
/// Shows: Today's earnings, month earnings, pending approvals, payment distribution.
class RevenueAnalyticsCard extends StatelessWidget {
  const RevenueAnalyticsCard({
    super.key,
    required this.libraryId,
    this.onTap,
    this.onViewCashApprovals,
    this.onViewUpiApprovals,
  });

  final String libraryId;
  final VoidCallback? onTap;
  final VoidCallback? onViewCashApprovals;
  final VoidCallback? onViewUpiApprovals;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RevenueAnalyticsCubit, RevenueAnalyticsState>(
      builder: (context, state) {
        if (state.isLoading && !state.hasData) {
          return _LoadingCard();
        }

        if (state.hasError && !state.hasData) {
          return _ErrorCard(
            message: state.errorMessage ?? 'Failed to load',
            onRetry: () =>
                context.read<RevenueAnalyticsCubit>().loadAnalytics(libraryId),
          );
        }

        final analytics = state.analytics;
        if (analytics == null) {
          return const SizedBox.shrink();
        }

        return _RevenueCard(
          analytics: analytics,
          onTap: onTap,
          onViewCashApprovals: onViewCashApprovals,
          onViewUpiApprovals: onViewUpiApprovals,
        );
      },
    );
  }
}

class _RevenueCard extends StatelessWidget {
  const _RevenueCard({
    required this.analytics,
    this.onTap,
    this.onViewCashApprovals,
    this.onViewUpiApprovals,
  });

  final RevenueAnalytics analytics;
  final VoidCallback? onTap;
  final VoidCallback? onViewCashApprovals;
  final VoidCallback? onViewUpiApprovals;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: AppUIConstants.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppUIConstants.border),
            boxShadow: [AppUIConstants.shadowSm],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppUIConstants.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_outlined,
                        color: AppUIConstants.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Revenue',
                      style: AppUIConstants.headingSm.copyWith(
                        color: AppUIConstants.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      DateFormat('MMMM yyyy').format(DateTime.now()),
                      style: AppUIConstants.caption,
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: AppUIConstants.border),

              // Earnings Row
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: _EarningsItem(
                        label: 'Today',
                        amount: indianRupeeCurrencyFormat.format(analytics.todayEarnings),
                        icon: Icons.today_outlined,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: AppUIConstants.border,
                    ),
                    Expanded(
                      child: _EarningsItem(
                        label: 'This Month',
                        amount: indianRupeeCurrencyFormat.format(analytics.monthEarnings),
                        icon: Icons.calendar_month_outlined,
                        isPrimary: true,
                      ),
                    ),
                  ],
                ),
              ),

              // Payment Distribution
              if (analytics.monthEarnings > 0) ...[
                const Divider(height: 1, color: AppUIConstants.border),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment Breakdown',
                        style: AppUIConstants.caption.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Segmented Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          height: 8,
                          child: Row(
                            children: [
                              if (analytics.upiPercentage > 0)
                                Expanded(
                                  flex: analytics.upiPercentage.round(),
                                  child: Container(
                                    color: AppUIConstants.secondary,
                                  ),
                                ),
                              if (analytics.cashPercentage > 0)
                                Expanded(
                                  flex: analytics.cashPercentage.round(),
                                  child: Container(
                                    color: AppUIConstants.accent,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Legend
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _LegendItem(
                            color: AppUIConstants.secondary,
                            label: 'UPI',
                            value: indianRupeeCurrencyFormat.format(
                              analytics.upiPaymentsTotal,
                            ),
                          ),
                          _LegendItem(
                            color: AppUIConstants.accent,
                            label: 'Cash',
                            value: indianRupeeCurrencyFormat.format(
                              analytics.cashPaymentsTotal,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              // Pending Approvals
              if (analytics.totalPendingApprovals > 0) ...[
                const Divider(height: 1, color: AppUIConstants.border),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.pending_actions_outlined,
                        size: 18,
                        color: AppUIConstants.warning,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Pending Approvals',
                        style: AppUIConstants.bodySm.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      if (analytics.pendingCashCount > 0)
                        _PendingBadge(
                          count: analytics.pendingCashCount,
                          label: 'Cash',
                          onTap: onViewCashApprovals,
                        ),
                      if (analytics.pendingCashCount > 0 &&
                          analytics.pendingUpiCount > 0)
                        const SizedBox(width: 8),
                      if (analytics.pendingUpiCount > 0)
                        _PendingBadge(
                          count: analytics.pendingUpiCount,
                          label: 'UPI',
                          onTap: onViewUpiApprovals,
                        ),
                    ],
                  ),
                ),
              ],

              // Tap indicator
              if (onTap != null) ...[
                const Divider(height: 1, color: AppUIConstants.border),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'View Details',
                        style: AppUIConstants.caption.copyWith(
                          color: AppUIConstants.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: AppUIConstants.primary,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EarningsItem extends StatelessWidget {
  const _EarningsItem({
    required this.label,
    required this.amount,
    required this.icon,
    this.isPrimary = false,
  });

  final String label;
  final String amount;
  final IconData icon;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: AppUIConstants.textTertiary),
            const SizedBox(width: 4),
            Text(label, style: AppUIConstants.caption),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          amount,
          style: isPrimary
              ? AppUIConstants.headingMd.copyWith(
                  color: AppUIConstants.primary,
                  fontWeight: FontWeight.bold,
                )
              : AppUIConstants.headingSm.copyWith(
                  color: AppUIConstants.textPrimary,
                ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(label, style: AppUIConstants.caption),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppUIConstants.bodySm.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _PendingBadge extends StatelessWidget {
  const _PendingBadge({required this.count, required this.label, this.onTap});

  final int count;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppUIConstants.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$count',
              style: AppUIConstants.bodySm.copyWith(
                fontWeight: FontWeight.bold,
                color: AppUIConstants.warning,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppUIConstants.caption.copyWith(
                color: AppUIConstants.warning,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.chevron_right, size: 14, color: AppUIConstants.warning),
          ],
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppUIConstants.border),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppUIConstants.primary,
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppUIConstants.border),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: AppUIConstants.error, size: 32),
          const SizedBox(height: 8),
          Text(message, style: AppUIConstants.bodySm),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
