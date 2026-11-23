import 'package:material_ui/material_ui.dart';

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
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
    );
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onReject,
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('Reject'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppUIConstants.error,
              side: BorderSide(
                color: AppUIConstants.error.withValues(alpha: 0.5),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: shape,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: onApprove,
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Approve'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppUIConstants.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              elevation: 0,
              shape: shape,
            ),
          ),
        ),
      ],
    );
  }
}
