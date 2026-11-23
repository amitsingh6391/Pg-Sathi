import 'package:material_ui/material_ui.dart';
import 'package:unicons/unicons.dart';

import '../../../core/app_ui_constants.dart';

/// Reminder delivery options.
enum ReminderDeliveryOption { pushOnly, whatsappOnly, both }

/// Compact push / WhatsApp / both picker for the reminder sheet.
class ReminderDeliverySelector extends StatelessWidget {
  const ReminderDeliverySelector({
    super.key,
    required this.selected,
    required this.hasPhone,
    required this.onChanged,
  });

  final ReminderDeliveryOption selected;
  final bool hasPhone;
  final ValueChanged<ReminderDeliveryOption> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Send via', style: AppUIConstants.headingSm),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<ReminderDeliveryOption>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              backgroundColor: AppUIConstants.surface,
              foregroundColor: AppUIConstants.textSecondary,
              selectedBackgroundColor: AppUIConstants.primary,
              selectedForegroundColor: AppUIConstants.surface,
              side: const BorderSide(color: AppUIConstants.border),
            ),
            segments: [
              const ButtonSegment(
                value: ReminderDeliveryOption.pushOnly,
                icon: Icon(UniconsLine.bell, size: 18),
                label: Text('Push'),
              ),
              if (hasPhone)
                const ButtonSegment(
                  value: ReminderDeliveryOption.whatsappOnly,
                  icon: Icon(UniconsLine.whatsapp, size: 18),
                  label: Text('WhatsApp'),
                ),
              if (hasPhone)
                const ButtonSegment(
                  value: ReminderDeliveryOption.both,
                  icon: Icon(UniconsLine.share_alt, size: 18),
                  label: Text('Both'),
                ),
            ],
            selected: {selected},
            onSelectionChanged: (values) => onChanged(values.first),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          hasPhone
              ? _description(selected)
              : 'WhatsApp unavailable: no phone number on file',
          style: AppUIConstants.bodySm,
        ),
      ],
    );
  }

  String _description(ReminderDeliveryOption option) {
    return switch (option) {
      ReminderDeliveryOption.pushOnly => 'In-app push notification only',
      ReminderDeliveryOption.whatsappOnly =>
        'Opens the resident\'s WhatsApp chat',
      ReminderDeliveryOption.both => 'Push notification and WhatsApp chat',
    };
  }
}
