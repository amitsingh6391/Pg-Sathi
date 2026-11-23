import 'package:material_ui/material_ui.dart';

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
        color = AppUIConstants.primaryLight;
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}
