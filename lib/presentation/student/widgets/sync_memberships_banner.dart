import 'package:flutter/material.dart';

import '../../core/app_ui_constants.dart';

/// Banner to notify students about unregistered memberships that can be synced.
/// Shown when student logs in and there are memberships assigned by phone number only.
class SyncMembershipsBanner extends StatelessWidget {
  const SyncMembershipsBanner({
    super.key,
    required this.onSync,
    required this.onDismiss,
  });

  final VoidCallback onSync;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppUIConstants.spacingLg),
      padding: const EdgeInsets.all(AppUIConstants.spacingLg),
      decoration: BoxDecoration(
        color: AppUIConstants.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        border: Border.all(
          color: AppUIConstants.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.link_rounded, color: AppUIConstants.primary, size: 20),
          const SizedBox(width: AppUIConstants.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'We found existing memberships',
                  style: AppUIConstants.bodyLg.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Linked to this phone number. Sync to view them.',
                  style: AppUIConstants.bodySm.copyWith(
                    color: AppUIConstants.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppUIConstants.spacingSm),
          TextButton(
            onPressed: onDismiss,
            style: TextButton.styleFrom(
              foregroundColor: AppUIConstants.textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: onSync,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppUIConstants.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
              ),
              elevation: 0,
            ),
            child: const Text('Sync', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
