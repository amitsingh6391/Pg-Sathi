import 'package:material_ui/material_ui.dart';

import '../../../core/app_ui_constants.dart';

/// Pinned bottom publish button.
class NoticePublishBar extends StatelessWidget {
  const NoticePublishBar({
    super.key,
    required this.busy,
    required this.isScheduled,
    required this.sendingWhatsApp,
    required this.onPressed,
  });

  final bool busy;
  final bool isScheduled;
  final bool sendingWhatsApp;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppUIConstants.spacingLg,
          vertical: AppUIConstants.spacingMd,
        ),
        decoration: const BoxDecoration(
          color: AppUIConstants.surface,
          border: Border(top: BorderSide(color: AppUIConstants.border)),
        ),
        child: FilledButton(
          onPressed: busy ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: AppUIConstants.primary,
            minimumSize: const Size.fromHeight(52),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
            ),
          ),
          child: busy
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: AppUIConstants.spacingMd),
                    Text(
                      sendingWhatsApp ? 'Publishing & sending…' : 'Publishing…',
                    ),
                  ],
                )
              : Text(isScheduled ? 'Schedule notice' : 'Publish notice'),
        ),
      ),
    );
  }
}
