import 'package:flutter/material.dart';

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

  /// Context-specific message to include in WhatsApp (e.g., library name, amount).
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
      backgroundColor: AppUIConstants.primary,
      foregroundColor: Colors.white,
      elevation: 4,
      icon: const Icon(Icons.support_agent_rounded, size: 22),
      label: const Text(
        'Need Help?',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  Future<void> _launchWhatsAppSupport() async {
    await WhatsAppLauncher.launch(
      phone: supportPhone,
      message: contextMessage,
    );
  }
}
