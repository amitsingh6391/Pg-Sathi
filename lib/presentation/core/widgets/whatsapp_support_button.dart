import 'package:material_ui/material_ui.dart';

import '../../../core/utils/whatsapp_launcher.dart';
import '../app_ui_constants.dart';

/// Common WhatsApp support floating action button.
/// Used across subscription-related screens for consistent help access.
class WhatsAppSupportButton extends StatelessWidget {
  const WhatsAppSupportButton({
    super.key,
    required this.contextMessage,
    this.heroTag,
  });

  /// Context-specific message to include in WhatsApp (e.g., PG name, amount).
  final String contextMessage;

  /// Optional unique hero tag to avoid conflicts when multiple FABs exist.
  final Object? heroTag;

  /// Support phone number (E.164 format without +).
  static const String supportPhone = '919548582776';

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: heroTag,
      onPressed: () => _launchWhatsAppSupport(),
      backgroundColor: AppUIConstants.surfaceMuted,
      foregroundColor: AppUIConstants.textPrimary,
      elevation: 6,
      highlightElevation: 2,
      shape: StadiumBorder(
        side: BorderSide(color: AppUIConstants.success.withValues(alpha: 0.6)),
      ),
      icon: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppUIConstants.success.withValues(alpha: 0.18),
        ),
        child: const Icon(
          Icons.chat_rounded,
          size: 16,
          color: AppUIConstants.success,
        ),
      ),
      label: const Text(
        'Chat with support',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
      ),
    );
  }

  Future<void> _launchWhatsAppSupport() async {
    await WhatsAppLauncher.launch(phone: supportPhone, message: contextMessage);
  }
}
