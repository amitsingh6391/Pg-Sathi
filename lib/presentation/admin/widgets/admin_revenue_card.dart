import 'package:material_ui/material_ui.dart';

import '../../../core/utils/indian_currency_format.dart';
import '../../../domain/entities/subscription.dart';
import '../../core/app_ui_constants.dart';

/// Hero revenue block for the admin console. Designed to sit inside a
/// PremiumHero: big collected total, pending chip and a status split bar.
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
    final pendingCount = pendingSubscriptions.length;
    final total = activeCount + expiredCount + pendingCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'PLATFORM REVENUE',
              style: AppUIConstants.caption.copyWith(
                color: AppUIConstants.textSecondary,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            if (pendingRevenue > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppUIConstants.surfaceMuted,
                  borderRadius: BorderRadius.circular(
                    AppUIConstants.radiusFull,
                  ),
                ),
                child: Text(
                  '+\u20B9${formatIndianRupeeInteger(pendingRevenue)} pending',
                  style: const TextStyle(
                    color: AppUIConstants.textPrimary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: totalRevenue),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (_, v, _) => FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '\u20B9${formatIndianRupeeInteger(v)}',
              style: const TextStyle(
                fontSize: 40,
                height: 1.1,
                fontWeight: FontWeight.w800,
                color: AppUIConstants.textPrimary,
                letterSpacing: -1,
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'collected from active PG plans',
          style: AppUIConstants.bodySm.copyWith(
            color: AppUIConstants.textSecondary,
          ),
        ),
        const SizedBox(height: AppUIConstants.spacingLg),
        _SplitBar(
          active: activeCount,
          pending: pendingCount,
          expired: expiredCount,
          total: total,
        ),
        const SizedBox(height: AppUIConstants.spacingMd),
        Row(
          children: [
            _Legend(
              color: AppUIConstants.success,
              label: 'Active',
              value: activeCount,
            ),
            _Legend(
              color: AppUIConstants.warning,
              label: 'Pending',
              value: pendingCount,
            ),
            _Legend(
              color: AppUIConstants.error,
              label: 'Expired',
              value: expiredCount,
            ),
          ],
        ),
      ],
    );
  }
}

class _SplitBar extends StatelessWidget {
  const _SplitBar({
    required this.active,
    required this.pending,
    required this.expired,
    required this.total,
  });

  final int active;
  final int pending;
  final int expired;
  final int total;

  @override
  Widget build(BuildContext context) {
    Widget seg(int v, Color c) => Expanded(
      flex: v,
      child: Container(margin: const EdgeInsets.only(right: 2), color: c),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
      child: SizedBox(
        height: 8,
        child: total == 0
            ? Container(color: AppUIConstants.surfaceMuted)
            : Row(
                children: [
                  if (active > 0) seg(active, AppUIConstants.success),
                  if (pending > 0) seg(pending, AppUIConstants.warning),
                  if (expired > 0) seg(expired, AppUIConstants.error),
                ],
              ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$value',
            style: const TextStyle(
              color: AppUIConstants.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppUIConstants.textSecondary,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}
