import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../domain/entities/subscription.dart';
import '../../../core/app_ui_constants.dart';
import '../subscription_widgets/status_badge.dart';
import 'widgets/subscription_action_buttons.dart';
import 'widgets/subscription_amount_badge.dart';
import 'widgets/subscription_info_row.dart';

/// Premium subscription tile with minimal, clean design
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

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppUIConstants.divider.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildContent(),
          if (_isPending) ...[
            const SizedBox(height: 20),
            SubscriptionActionButtons(
              onApprove: onApprove,
              onReject: onReject,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        StatusBadge(status: subscription.status),
        const Spacer(),
        if (!_isPending && onDelete != null)
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
            iconSize: 18,
            color: AppUIConstants.textSecondary.withValues(alpha: 0.5),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            tooltip: 'Delete',
          ),
      ],
    );
  }

  Widget _buildContent() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SubscriptionInfoRow(
            subscription: subscription,
            dateFormat: DateFormat('dd MMM yyyy'),
          ),
        ),
        const SizedBox(width: 20),
        SubscriptionAmountBadge(amount: subscription.finalAmount),
      ],
    );
  }
}
