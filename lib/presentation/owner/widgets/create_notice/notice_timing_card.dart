import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/app_ui_constants.dart';
import 'notice_form_parts.dart';

/// Publish-at and expires-at pickers.
class NoticeTimingCard extends StatelessWidget {
  const NoticeTimingCard({
    super.key,
    required this.scheduledFor,
    required this.expiresAt,
    required this.enabled,
    required this.onPickSchedule,
    required this.onPickExpiry,
    required this.onClearSchedule,
    required this.onClearExpiry,
  });

  static final _format = DateFormat('d MMM, h:mm a');
  static final _dateOnly = DateFormat('EEE, d MMM y');

  final DateTime? scheduledFor;
  final DateTime? expiresAt;
  final bool enabled;
  final VoidCallback onPickSchedule;
  final VoidCallback onPickExpiry;
  final VoidCallback onClearSchedule;
  final VoidCallback onClearExpiry;

  Widget _trailing(DateTime? value, VoidCallback onClear) {
    if (value == null) {
      return const Padding(
        padding: EdgeInsets.all(AppUIConstants.spacingMd),
        child: Icon(
          Icons.chevron_right_rounded,
          color: AppUIConstants.textTertiary,
        ),
      );
    }
    return IconButton(
      icon: const Icon(Icons.close_rounded, size: 20),
      color: AppUIConstants.textTertiary,
      onPressed: enabled ? onClear : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return NoticeSectionCard(
      title: 'Timing',
      caption: 'Optional',
      padding: const EdgeInsets.fromLTRB(
        AppUIConstants.spacingLg,
        AppUIConstants.spacingLg,
        AppUIConstants.spacingXs,
        AppUIConstants.spacingSm,
      ),
      child: Column(
        children: [
          NoticeRow(
            icon: Icons.schedule_rounded,
            title: 'Publish',
            subtitle: scheduledFor == null
                ? 'Right now'
                : _dateOnly.format(scheduledFor!),
            onTap: enabled ? onPickSchedule : null,
            trailing: _trailing(scheduledFor, onClearSchedule),
          ),
          NoticeRow(
            icon: Icons.event_busy_outlined,
            iconColor: AppUIConstants.warning,
            title: 'Expires',
            subtitle: expiresAt == null ? 'Never' : _format.format(expiresAt!),
            onTap: enabled ? onPickExpiry : null,
            trailing: _trailing(expiresAt, onClearExpiry),
          ),
        ],
      ),
    );
  }
}
