import 'package:material_ui/material_ui.dart';

import '../../core/app_ui_constants.dart';

/// Banner to notify residents about stays linked to their phone number that
/// can be synced to this account.
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
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
        border: Border.all(color: AppUIConstants.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppUIConstants.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
                ),
                child: const Icon(
                  Icons.link_rounded,
                  color: AppUIConstants.primaryLight,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppUIConstants.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'We found existing stays',
                      style: AppUIConstants.bodyLg.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Linked to this phone number. Sync to see them here.',
                      style: AppUIConstants.bodySm,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppUIConstants.spacingMd),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onDismiss,
                style: TextButton.styleFrom(
                  foregroundColor: AppUIConstants.textSecondary,
                ),
                child: const Text('Later'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: onSync,
                icon: const Icon(Icons.sync_rounded, size: 18),
                label: const Text('Sync now'),
                style: AppUIConstants.primaryButtonStyle.copyWith(
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  ),
                  elevation: const WidgetStatePropertyAll(0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
