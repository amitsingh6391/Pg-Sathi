import 'package:material_ui/material_ui.dart';

import '../../../core/app_ui_constants.dart';

/// White rounded card with a section heading.
class NoticeSectionCard extends StatelessWidget {
  const NoticeSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.caption,
    this.padding = const EdgeInsets.all(AppUIConstants.spacingLg),
  });

  final String title;
  final String? caption;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: AppUIConstants.cardDecorationFlat,
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppUIConstants.headingSm),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(caption!, style: AppUIConstants.bodySm),
          ],
          const SizedBox(height: AppUIConstants.spacingMd),
          child,
        ],
      ),
    );
  }
}

/// Tinted rounded icon used as a row leading.
class NoticeIconBadge extends StatelessWidget {
  const NoticeIconBadge({super.key, required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

/// Icon + title + subtitle row with a trailing widget.
class NoticeRow extends StatelessWidget {
  const NoticeRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor = AppUIConstants.primary,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppUIConstants.spacingSm),
        child: Row(
          children: [
            NoticeIconBadge(icon: icon, color: iconColor),
            const SizedBox(width: AppUIConstants.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppUIConstants.bodyLg),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppUIConstants.bodySm,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// [NoticeRow] with a switch.
class NoticeSwitchRow extends StatelessWidget {
  const NoticeSwitchRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.iconColor = AppUIConstants.primary,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return NoticeRow(
      icon: icon,
      iconColor: iconColor,
      title: title,
      subtitle: subtitle,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeTrackColor: AppUIConstants.success,
      ),
    );
  }
}

/// Removable attachment / link row.
class NoticeItemRow extends StatelessWidget {
  const NoticeItemRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onRemove,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppUIConstants.spacingSm),
      padding: const EdgeInsets.fromLTRB(
        AppUIConstants.spacingMd,
        AppUIConstants.spacingXs,
        AppUIConstants.spacingXs,
        AppUIConstants.spacingXs,
      ),
      decoration: BoxDecoration(
        color: AppUIConstants.background,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
        border: Border.all(color: AppUIConstants.border),
      ),
      child: NoticeRow(
        icon: icon,
        title: title,
        subtitle: subtitle,
        trailing: IconButton(
          icon: const Icon(Icons.close_rounded, size: 20),
          color: AppUIConstants.textTertiary,
          onPressed: onRemove,
        ),
      ),
    );
  }
}
