import 'package:material_ui/material_ui.dart';

import '../../../../domain/entities/notice.dart';
import '../../../core/app_ui_constants.dart';

/// Two-option pill selector for who receives the notice.
class NoticeAudienceSelector extends StatelessWidget {
  const NoticeAudienceSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final NoticeTargetAudience value;
  final ValueChanged<NoticeTargetAudience>? onChanged;

  static const _options = [
    (NoticeTargetAudience.all, Icons.groups_outlined, 'All tenants'),
    (
      NoticeTargetAudience.activeStudents,
      Icons.verified_user_outlined,
      'Active only',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppUIConstants.spacingXs),
      decoration: BoxDecoration(
        color: AppUIConstants.background,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        border: Border.all(color: AppUIConstants.border),
      ),
      child: Row(
        children: [
          for (final (audience, icon, label) in _options)
            Expanded(
              child: _Option(
                icon: icon,
                label: label,
                selected: value == audience,
                onTap: onChanged == null ? null : () => onChanged!(audience),
              ),
            ),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? AppUIConstants.surface
        : AppUIConstants.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: AppUIConstants.spacingMd),
        decoration: BoxDecoration(
          color: selected ? AppUIConstants.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppUIConstants.labelMd.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
