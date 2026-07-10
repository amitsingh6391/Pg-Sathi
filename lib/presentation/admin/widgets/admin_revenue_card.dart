import 'package:flutter/material.dart';

import '../../../core/utils/indian_currency_format.dart';
import '../../../domain/entities/subscription.dart';
import '../../core/app_ui_constants.dart';

/// Premium revenue card widget for admin dashboard.
/// Displays total revenue, pending revenue, and subscription stats.
class AdminRevenueCard extends StatelessWidget {
  const AdminRevenueCard({
    super.key,
    required this.allSubscriptions,
    required this.pendingSubscriptions,
  });

  final List<Subscription> allSubscriptions;
  final List<Subscription> pendingSubscriptions;

  @override
  Widget build(BuildContext context) {
    final totalRevenue = allSubscriptions
        .where((s) => s.status == SubscriptionStatus.active)
        .fold(0.0, (sum, s) => sum + s.finalAmount);

    final pendingRevenue = pendingSubscriptions.fold(
      0.0,
      (sum, s) => sum + s.finalAmount,
    );

    final activeCount = allSubscriptions
        .where((s) => s.status == SubscriptionStatus.active)
        .length;

    final expiredCount = allSubscriptions
        .where((s) => s.status == SubscriptionStatus.expired)
        .length;

    return Container(
      padding: const EdgeInsets.all(AppUIConstants.spacingLg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppUIConstants.primary, AppUIConstants.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
        boxShadow: [AppUIConstants.shadowLg],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: AppUIConstants.spacingLg),
          _buildRevenueRow(totalRevenue, pendingRevenue),
          const SizedBox(height: AppUIConstants.spacingMd),
          _buildStatsRow(
            activeCount,
            pendingSubscriptions.length,
            expiredCount,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppUIConstants.spacingSm),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
          ),
          child: const Icon(
            Icons.account_balance_wallet_outlined,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: AppUIConstants.spacingMd),
        Text(
          'Platform Revenue',
          style: AppUIConstants.headingSm.copyWith(color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildRevenueRow(double totalRevenue, double pendingRevenue) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total Collected',
                style: AppUIConstants.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '₹${formatIndianRupeeInteger(totalRevenue)}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 1,
          height: 50,
          color: Colors.white.withValues(alpha: 0.2),
        ),
        const SizedBox(width: AppUIConstants.spacingLg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pending',
                style: AppUIConstants.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '₹${formatIndianRupeeInteger(pendingRevenue)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(int active, int pending, int expired) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppUIConstants.spacingMd,
        vertical: AppUIConstants.spacingSm,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _MiniStat(value: '$active', label: 'Active'),
          _MiniStat(value: '$pending', label: 'Pending'),
          _MiniStat(value: '$expired', label: 'Expired'),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}
