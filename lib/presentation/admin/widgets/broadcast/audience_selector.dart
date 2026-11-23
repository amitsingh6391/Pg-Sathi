import 'package:material_ui/material_ui.dart';

import '../../../../domain/usecases/send_admin_broadcast_notification.dart';
import '../../../core/app_ui_constants.dart';
import '../../../core/widgets/premium_kit.dart';

/// Audience selector rendered as grouped choice chips with a live
/// description of the currently selected audience.
class AudienceSelector extends StatelessWidget {
  const AudienceSelector({
    super.key,
    required this.selectedAudience,
    required this.onAudienceChanged,
  });

  final BroadcastAudience selectedAudience;
  final ValueChanged<BroadcastAudience> onAudienceChanged;

  static const _groups = <_Group>[
    _Group('PG owners', Icons.business_rounded, AppUIConstants.textSecondary, [
      _Option(
        BroadcastAudience.allOwners,
        'All owners',
        'Every registered PG owner',
        Icons.people_rounded,
      ),
      _Option(
        BroadcastAudience.ownersWithLibrary,
        'Active',
        'Owners who have set up a PG',
        Icons.check_circle_rounded,
      ),
      _Option(
        BroadcastAudience.ownersWithoutLibrary,
        'Pending setup',
        'Owners who have not added a PG yet',
        Icons.hourglass_top_rounded,
      ),
    ]),
    _Group('Residents', Icons.groups_rounded, AppUIConstants.textSecondary, [
      _Option(
        BroadcastAudience.allStudents,
        'All residents',
        'Every registered resident',
        Icons.groups_rounded,
      ),
      _Option(
        BroadcastAudience.studentsWithActiveMembership,
        'Active stay',
        'Residents with an active stay',
        Icons.bed_rounded,
      ),
      _Option(
        BroadcastAudience.activeStudents,
        'Recently active',
        'Active in the last 30 days (faster delivery)',
        Icons.trending_up_rounded,
      ),
    ]),
    _Group('Custom', Icons.tune_rounded, AppUIConstants.textSecondary, [
      _Option(
        BroadcastAudience.selectedLibraries,
        'Owners of chosen PGs',
        'Pick specific PGs, message their owners',
        Icons.checklist_rounded,
      ),
      _Option(
        BroadcastAudience.selectedLibraryStudents,
        'Residents of chosen PGs',
        'Pick specific PGs, message residents',
        Icons.filter_list_rounded,
      ),
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    String description = '';
    for (final g in _groups) {
      for (final o in g.options) {
        if (o.audience == selectedAudience) description = o.description;
      }
    }
    return PremiumCard(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumSectionHeader('Audience'),
          for (final g in _groups) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 4),
              child: Row(
                children: [
                  Icon(g.icon, size: 14, color: g.color),
                  const SizedBox(width: 6),
                  Text(
                    g.title.toUpperCase(),
                    style: AppUIConstants.caption.copyWith(
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w700,
                      color: g.color,
                    ),
                  ),
                ],
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final o in g.options)
                  _AudienceChip(
                    option: o,
                    color: g.color,
                    selected: o.audience == selectedAudience,
                    onTap: () => onAudienceChanged(o.audience),
                  ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Container(
              key: ValueKey(selectedAudience),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppUIConstants.surfaceMuted,
                borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: AppUIConstants.textTertiary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(description, style: AppUIConstants.bodySm),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Group {
  const _Group(this.title, this.icon, this.color, this.options);
  final String title;
  final IconData icon;
  final Color color;
  final List<_Option> options;
}

class _Option {
  const _Option(this.audience, this.label, this.description, this.icon);
  final BroadcastAudience audience;
  final String label;
  final String description;
  final IconData icon;
}

class _AudienceChip extends StatelessWidget {
  const _AudienceChip({
    required this.option,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final _Option option;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: selected
            ? color.withValues(alpha: 0.18)
            : AppUIConstants.surfaceMuted,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
        border: Border.all(
          color: selected ? color : AppUIConstants.border,
          width: selected ? 1.4 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? Icons.check_rounded : option.icon,
                  size: 16,
                  color: selected ? color : AppUIConstants.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  option.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? AppUIConstants.textPrimary
                        : AppUIConstants.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
