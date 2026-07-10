import 'package:flutter/material.dart';

import '../../../../core/app_ui_constants.dart';

/// Premium amount display badge with minimal design
class SubscriptionAmountBadge extends StatelessWidget {
  const SubscriptionAmountBadge({
    required this.amount,
    super.key,
  });

  final double amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppUIConstants.textPrimary.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppUIConstants.divider.withValues(alpha: 0.1),
        ),
      ),
      child: Text(
        '₹${amount.toStringAsFixed(0)}',
        style: AppUIConstants.bodyLg.copyWith(
          fontWeight: FontWeight.w700,
          color: AppUIConstants.textPrimary,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}
