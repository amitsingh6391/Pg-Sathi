import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../../domain/entities/user.dart';
import '../../core/app_ui_constants.dart';
import '../../core/widgets/premium_kit.dart';

/// Reusable profile widgets for the resident profile experience.

/// Circular avatar with a luminous gradient ring.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.user,
    this.avatarUrl,
    this.size = 50,
    this.showBorder = false,
  });

  final User user;
  final String? avatarUrl;

  /// Avatar radius.
  final double size;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    final avatar = CircleAvatar(
      radius: size,
      backgroundColor: AppUIConstants.primarySoft,
      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
      child: avatarUrl == null
          ? Text(
              user.initials,
              style: TextStyle(
                fontSize: size * 0.6,
                fontWeight: FontWeight.bold,
                color: AppUIConstants.primaryLight,
              ),
            )
          : null,
    );

    if (!showBorder) return avatar;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [AppUIConstants.primaryLight, AppUIConstants.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppUIConstants.background,
        ),
        child: avatar,
      ),
    );
  }
}

/// Animated circular progress ring with a [child] in the middle.
class CompletionRing extends StatelessWidget {
  const CompletionRing({
    super.key,
    required this.progress,
    required this.child,
    this.size = 112,
    this.strokeWidth = 5,
    this.color = AppUIConstants.primaryLight,
  });

  /// 0..1
  final double progress;
  final Widget child;
  final double size;
  final double strokeWidth;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RingPainter(
              progress: value,
              color: color,
              strokeWidth: strokeWidth,
            ),
            child: Center(child: child),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final inset = rect.deflate(strokeWidth / 2);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = AppUIConstants.surfaceMuted;
    canvas.drawArc(inset, 0, math.pi * 2, false, track);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth
      ..color = color;
    canvas.drawArc(inset, -math.pi / 2, math.pi * 2 * progress, false, arc);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}

/// Label + value row with a tinted icon well.
class InfoTile extends StatelessWidget {
  const InfoTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.valueWidget,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final Widget? valueWidget;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppUIConstants.primaryLight.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
                ),
                child: Icon(icon, size: 19, color: AppUIConstants.primaryLight),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppUIConstants.caption),
                    const SizedBox(height: 3),
                    valueWidget ??
                        Text(
                          value,
                          style: AppUIConstants.bodyLg.copyWith(
                            fontWeight: FontWeight.w600,
                            color: valueColor ?? AppUIConstants.textPrimary,
                          ),
                        ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(height: 1, color: AppUIConstants.divider),
      ],
    );
  }
}

/// Titled card that wraps a group of rows.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    this.delay = 0,
    this.actionButton,
    this.onTap,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final int delay;
  final Widget? actionButton;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 450 + delay),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: 1),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - value)),
          child: child,
        ),
      ),
      child: PremiumCard(
        onTap: onTap,
        margin: const EdgeInsets.only(bottom: AppUIConstants.spacingLg),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppUIConstants.primaryLight),
                const SizedBox(width: 10),
                Expanded(child: Text(title, style: AppUIConstants.headingSm)),
                if (actionButton != null) actionButton!,
              ],
            ),
            const SizedBox(height: 6),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Small pill showing whether the profile is complete.
class ProfileStatusBadge extends StatelessWidget {
  const ProfileStatusBadge({super.key, required this.isComplete});

  final bool isComplete;

  @override
  Widget build(BuildContext context) {
    final c = isComplete ? AppUIConstants.success : AppUIConstants.primaryLight;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isComplete ? Icons.check_circle_rounded : Icons.pending_rounded,
            size: 15,
            color: c,
          ),
          const SizedBox(width: 6),
          Text(
            isComplete ? 'Complete' : 'Incomplete',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: c,
            ),
          ),
        ],
      ),
    );
  }
}

/// Call-to-action card nudging the resident to finish their profile.
class ProfileCompletionCard extends StatelessWidget {
  const ProfileCompletionCard({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      onTap: () {
        HapticFeedback.selectionClick();
        onComplete();
      },
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppUIConstants.surfaceMuted,
              borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
            ),
            child: const Icon(
              Icons.edit_note_rounded,
              color: AppUIConstants.primaryLight,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Complete your profile',
                  style: AppUIConstants.headingSm,
                ),
                const SizedBox(height: 3),
                Text(
                  'Add your details so your PG can recognise you',
                  style: AppUIConstants.bodySm,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: AppUIConstants.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_forward_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}

/// Grouped list of settings rows inside one card, with optional caption.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i != children.length - 1) {
        rows.add(
          const Divider(height: 1, indent: 66, color: AppUIConstants.divider),
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) PremiumSectionHeader(title!),
        PremiumCard(
          padding: EdgeInsets.zero,
          child: Column(children: rows),
        ),
      ],
    );
  }
}

/// Single tappable / switchable settings row with a tinted icon well.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.color = AppUIConstants.primaryLight,
    this.onTap,
    this.trailing,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color color;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final destructive = color == AppUIConstants.error;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: destructive
                    ? AppUIConstants.error.withValues(alpha: 0.14)
                    : AppUIConstants.surfaceMuted,
                borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
              ),
              child: Icon(
                icon,
                size: 19,
                color: destructive
                    ? AppUIConstants.error
                    : AppUIConstants.primaryLight,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppUIConstants.bodyLg.copyWith(
                      color: destructive
                          ? AppUIConstants.error
                          : AppUIConstants.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: AppUIConstants.bodySm),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (onTap != null && showChevron)
              const Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: AppUIConstants.textTertiary,
              ),
          ],
        ),
      ),
    );
  }
}
