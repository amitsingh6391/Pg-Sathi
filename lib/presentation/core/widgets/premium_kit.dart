import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../app_ui_constants.dart';

/// Shared building blocks for the premium redesign. Screens should use
/// these instead of re-inventing cards, headers and pills.

/// White card with hairline border and soft shadow; optional tap and accent glow.
class PremiumCard extends StatelessWidget {
  const PremiumCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppUIConstants.spacingLg),
    this.glow,
    this.margin,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  /// When set, a soft colored glow is drawn under the card.
  final Color? glow;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppUIConstants.radiusLg);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radius,
        // Library Manager card: white, hairline border, soft shadow.
        // The optional [glow] is intentionally ignored.
        boxShadow: [AppUIConstants.shadowSm],
      ),
      child: Material(
        color: AppUIConstants.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: AppUIConstants.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Section title with optional trailing action, used above every group.
class PremiumSectionHeader extends StatelessWidget {
  const PremiumSectionHeader(
    this.title, {
    super.key,
    this.action,
    this.onAction,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 20, 2, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppUIConstants.textPrimary,
              ),
            ),
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                action!,
                style: const TextStyle(
                  color: AppUIConstants.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Compact metric tile: tinted icon, big value, small label.
class PremiumStatTile extends StatelessWidget {
  const PremiumStatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.color = AppUIConstants.primaryLight,
    this.onTap,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppUIConstants.surfaceMuted,
              borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
            ),
            child: Icon(icon, size: 18, color: AppUIConstants.textSecondary),
          ),
          const SizedBox(height: 12),
          Text(value, style: AppUIConstants.statValue),
          const SizedBox(height: 2),
          Text(label, style: AppUIConstants.bodySm),
        ],
      ),
    );
  }
}

/// Tiny status chip ("Paid", "Overdue"…); color derives from the status text
/// unless [color] is given.
class PremiumStatusPill extends StatelessWidget {
  const PremiumStatusPill(this.label, {super.key, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppUIConstants.getStatusColor(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
        border: Border.all(color: c.withValues(alpha: 0.30)),
      ),
      child: Text(
        label,
        style: TextStyle(color: c, fontSize: 11.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Header band for the top of a screen: white with a hairline bottom border,
/// designed for dark content. Put the title / greeting / key figure in
/// [child]. Status-bar icons are dark over the band.
class PremiumHero extends StatelessWidget {
  const PremiumHero({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: AppUIConstants.surface,
          border: Border(bottom: BorderSide(color: AppUIConstants.border)),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: padding ?? const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Two-column grid whose rows size to their content (unlike a GridView with a
/// fixed aspect ratio, which overflows when text is large or screens narrow).
/// Tiles in the same row stretch to equal height.
class PremiumTwoColumnGrid extends StatelessWidget {
  const PremiumTwoColumnGrid({
    super.key,
    required this.children,
    this.spacing = 12,
  });

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: children[i]),
              SizedBox(width: spacing),
              Expanded(
                child: i + 1 < children.length
                    ? children[i + 1]
                    : const SizedBox(),
              ),
            ],
          ),
        ),
      );
      if (i + 2 < children.length) rows.add(SizedBox(height: spacing));
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}
