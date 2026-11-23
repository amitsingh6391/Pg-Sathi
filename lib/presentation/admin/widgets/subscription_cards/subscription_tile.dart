import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import '../../../../domain/entities/subscription.dart';
import '../../../core/app_ui_constants.dart';
import '../subscription_widgets/status_badge.dart';
import 'widgets/subscription_action_buttons.dart';
import 'widgets/subscription_amount_badge.dart';
import 'widgets/subscription_info_row.dart';

/// Status-colored subscription row used inside a PG subscription card.
class SubscriptionTile extends StatelessWidget {
  const SubscriptionTile({
    required this.subscription,
    required this.onApprove,
    required this.onReject,
    this.onDelete,
    super.key,
  });

  final Subscription subscription;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback? onDelete;

  bool get _isPending =>
      subscription.status == SubscriptionStatus.pending ||
      subscription.status == SubscriptionStatus.pendingVerification;

  Color get _statusColor {
    switch (subscription.status) {
      case SubscriptionStatus.active:
        return AppUIConstants.success;
      case SubscriptionStatus.pending:
        return AppUIConstants.warning;
      case SubscriptionStatus.pendingVerification:
        return AppUIConstants.primaryLight;
      case SubscriptionStatus.cancelled:
      case SubscriptionStatus.rejected:
        return AppUIConstants.error;
      case SubscriptionStatus.expired:
        return AppUIConstants.textTertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      decoration: BoxDecoration(
        color: AppUIConstants.surfaceMuted,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    _buildHeader(color),
                    const SizedBox(height: 12),
                    SubscriptionInfoRow(
                      subscription: subscription,
                      dateFormat: DateFormat('dd MMM yyyy'),
                    ),
                    if (_isPending) ...[
                      const SizedBox(height: 14),
                      SubscriptionActionButtons(
                        onApprove: onApprove,
                        onReject: onReject,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color color) {
    return Row(
      children: [
        StatusBadge(status: subscription.status),
        const Spacer(),
        SubscriptionAmountBadge(amount: subscription.finalAmount, color: color),
        if (!_isPending && onDelete != null)
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
            iconSize: 18,
            color: AppUIConstants.textTertiary,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            tooltip: 'Delete',
          ),
      ],
    );
  }
}
