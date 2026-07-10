import 'package:flutter/material.dart';

import '../../../../core/app_ui_constants.dart';

/// Action buttons for pending subscription approval/rejection
class SubscriptionActionButtons extends StatelessWidget {
  const SubscriptionActionButtons({
    required this.onApprove,
    required this.onReject,
    super.key,
  });

  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onReject,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppUIConstants.textSecondary,
              side: BorderSide(
                color: AppUIConstants.divider.withValues(alpha: 0.3),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Reject'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: onApprove,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppUIConstants.textPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Approve'),
          ),
        ),
      ],
    );
  }
}
