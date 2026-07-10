import 'package:flutter/material.dart';

import '../../../domain/entities/subscription.dart';
import '../../core/app_ui_constants.dart';

/// Pending approvals section for admin dashboard.
/// Shows subscriptions awaiting approval with approve/reject actions.
class AdminPendingApprovals extends StatelessWidget {
  const AdminPendingApprovals({
    super.key,
    required this.pendingSubscriptions,
    required this.onApprove,
    required this.onReject,
    required this.onViewAll,
  });

  final List<Subscription> pendingSubscriptions;
  final void Function(Subscription) onApprove;
  final void Function(Subscription) onReject;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    if (pendingSubscriptions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: AppUIConstants.spacingMd),
        Container(
          decoration: AppUIConstants.cardDecoration,
          child: Column(
            children: pendingSubscriptions.take(3).map((sub) {
              return _PendingApprovalTile(
                subscription: sub,
                onApprove: () => onApprove(sub),
                onReject: () => onReject(sub),
                showDivider: sub != pendingSubscriptions.take(3).last,
              );
            }).toList(),
          ),
        ),
        if (pendingSubscriptions.length > 3) ...[
          const SizedBox(height: AppUIConstants.spacingSm),
          Center(
            child: TextButton(
              onPressed: onViewAll,
              child: Text(
                'View All ${pendingSubscriptions.length} Pending',
                style: AppUIConstants.bodySm.copyWith(
                  color: AppUIConstants.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppUIConstants.warning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            Icons.pending_actions,
            color: AppUIConstants.warning,
            size: 18,
          ),
        ),
        const SizedBox(width: AppUIConstants.spacingSm),
        Text('Pending Approvals', style: AppUIConstants.headingSm),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppUIConstants.spacingMd,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: AppUIConstants.warning,
            borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
          ),
          child: Text(
            '${pendingSubscriptions.length}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _PendingApprovalTile extends StatelessWidget {
  const _PendingApprovalTile({
    required this.subscription,
    required this.onApprove,
    required this.onReject,
    this.showDivider = true,
  });

  final Subscription subscription;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppUIConstants.spacingMd),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppUIConstants.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
                ),
                child: Icon(
                  Icons.pending_actions,
                  color: AppUIConstants.warning,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppUIConstants.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${subscription.seatCount} seats • ${subscription.durationInMonths} mo',
                      style: AppUIConstants.bodyMd.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'TXN: ${subscription.transactionId ?? "N/A"}',
                      style: AppUIConstants.caption,
                    ),
                  ],
                ),
              ),
              Text(
                '₹${subscription.finalAmount.toStringAsFixed(0)}',
                style: AppUIConstants.bodyLg.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppUIConstants.primary,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppUIConstants.spacingMd,
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppUIConstants.error,
                    side: BorderSide(color: AppUIConstants.error),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: AppUIConstants.spacingMd),
              Expanded(
                child: ElevatedButton(
                  onPressed: onApprove,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppUIConstants.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text('Approve'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppUIConstants.spacingMd),
        if (showDivider) Divider(height: 1, color: AppUIConstants.divider),
      ],
    );
  }
}
