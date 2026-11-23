import 'package:material_ui/material_ui.dart';

import '../../../core/app_ui_constants.dart';

enum NoticeEmptyKind { active, scheduled, expired }

class NoticeEmptyState extends StatelessWidget {
  const NoticeEmptyState({
    super.key,
    required this.kind,
    required this.onCreate,
  });

  final NoticeEmptyKind kind;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final (icon, title, subtitle) = switch (kind) {
      NoticeEmptyKind.active => (
        Icons.campaign_outlined,
        'No live notices',
        'Share updates, holidays or rules with your tenants.',
      ),
      NoticeEmptyKind.scheduled => (
        Icons.schedule_rounded,
        'Nothing scheduled',
        'Schedule a notice to go live at a later time.',
      ),
      NoticeEmptyKind.expired => (
        Icons.history_rounded,
        'No expired notices',
        'Notices with an end date will show here once they end.',
      ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppUIConstants.primary.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 34, color: AppUIConstants.primary),
          ),
          const SizedBox(height: AppUIConstants.spacingLg),
          Text(title, style: AppUIConstants.headingSm),
          const SizedBox(height: AppUIConstants.spacingSm),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppUIConstants.bodyMd,
          ),
          if (kind != NoticeEmptyKind.expired) ...[
            const SizedBox(height: AppUIConstants.spacingXl),
            OutlinedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Create notice'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppUIConstants.primary,
                side: const BorderSide(color: AppUIConstants.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
