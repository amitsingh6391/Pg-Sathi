import 'package:flutter/material.dart';

import '../../../../domain/entities/subscription.dart';
import '../../../core/app_ui_constants.dart';

/// Badge widget to display subscription status.
class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.status, super.key});

  final SubscriptionStatus status;

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    switch (status) {
      case SubscriptionStatus.pending:
        color = AppUIConstants.warning;
        label = 'Pending';
      case SubscriptionStatus.pendingVerification:
        color = AppUIConstants.accent;
        label = 'Verifying';
      case SubscriptionStatus.active:
        color = AppUIConstants.success;
        label = 'Active';
      case SubscriptionStatus.expired:
        color = AppUIConstants.textTertiary;
        label = 'Expired';
      case SubscriptionStatus.cancelled:
        color = AppUIConstants.error;
        label = 'Cancelled';
      case SubscriptionStatus.rejected:
        color = AppUIConstants.error;
        label = 'Rejected';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(
        label,
        style: AppUIConstants.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}
