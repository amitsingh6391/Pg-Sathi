import 'package:material_ui/material_ui.dart';

import '../../../core/app_ui_constants.dart';
import 'notice_form_parts.dart';

/// "Send on WhatsApp" switch for the create-notice form.
class NoticeWhatsAppToggle extends StatelessWidget {
  const NoticeWhatsAppToggle({
    super.key,
    required this.value,
    required this.credits,
    required this.isScheduled,
    required this.onChanged,
  });

  final bool value;

  /// Available credits; null while loading.
  final int? credits;
  final bool isScheduled;

  /// Null disables the switch.
  final ValueChanged<bool>? onChanged;

  bool get _canSend => isScheduled || (credits ?? 0) > 0;

  String get _subtitle {
    if (isScheduled) return 'Sent when it goes live, if credits are available';
    if (credits == null) return 'Checking credits…';
    if (credits! <= 0) return 'No credits left — buy from WhatsApp Credits';
    return '$credits credits left • 1 per resident';
  }

  @override
  Widget build(BuildContext context) {
    return NoticeSwitchRow(
      icon: Icons.chat_outlined,
      iconColor: AppUIConstants.success,
      title: 'WhatsApp message',
      subtitle: _subtitle,
      value: value && _canSend,
      onChanged: _canSend ? onChanged : null,
    );
  }
}
