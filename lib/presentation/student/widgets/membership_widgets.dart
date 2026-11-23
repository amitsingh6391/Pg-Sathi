import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../core/app_ui_constants.dart';

/// Status pill for stay cards.
/// Shows PENDING, PARTIAL, ACTIVE, or EXPIRED status.
class MembershipStatusBadge extends StatelessWidget {
  const MembershipStatusBadge({
    super.key,
    required this.isPending,
    required this.isActive,
    this.hasPartialPayment = false,
    this.isExpired = false,
  });

  final bool isPending;
  final bool isActive;
  final bool hasPartialPayment;
  final bool isExpired;

  @override
  Widget build(BuildContext context) {
    final (label, color) = _getLabelAndColor();
    if (label == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 10.5,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  (String?, Color) _getLabelAndColor() {
    if (isExpired) {
      return ('EXPIRED', AppUIConstants.error);
    }

    if (isPending) {
      return (
        hasPartialPayment ? 'PARTIAL' : 'PENDING',
        AppUIConstants.warning,
      );
    }

    if (isActive) {
      final color = hasPartialPayment
          ? AppUIConstants.warning
          : AppUIConstants.success;
      return (hasPartialPayment ? 'PARTIAL' : 'ACTIVE', color);
    }

    return (null, AppUIConstants.textSecondary);
  }
}

/// Info item for displaying labeled values (stacked: value over label).
class InfoItem extends StatelessWidget {
  const InfoItem({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppUIConstants.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppUIConstants.textTertiary,
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

/// Vertical divider for separating info items.
class InfoDivider extends StatelessWidget {
  const InfoDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: AppUIConstants.border,
    );
  }
}

/// Action tile for stay cards: tinted icon well above a short label.
/// Supports an optional [statusColor] to tint the icon and label
/// for contextual feedback (e.g., verified = green, pending = amber).
class MembershipActionButton extends StatelessWidget {
  const MembershipActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
    this.statusColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isPrimary;

  /// When set, overrides the default icon/label colors with this accent.
  final Color? statusColor;

  @override
  Widget build(BuildContext context) {
    final tint =
        statusColor ??
        (isPrimary
            ? AppUIConstants.primaryLight
            : AppUIConstants.textSecondary);
    final radius = BorderRadius.circular(AppUIConstants.radiusMd);

    return Material(
      color: isPrimary
          ? AppUIConstants.primarySoft
          : (statusColor?.withValues(alpha: 0.08) ??
                AppUIConstants.surfaceMuted),
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: isPrimary
              ? AppUIConstants.primary.withValues(alpha: 0.5)
              : (statusColor?.withValues(alpha: 0.35) ?? AppUIConstants.border),
        ),
      ),
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: tint),
              const SizedBox(height: 6),
              Text(
                label,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: statusColor ?? AppUIConstants.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Circular progress ring with a centered [child]. Animates from 0 to
/// [progress] (0..1) on first build and whenever the value changes.
class StayProgressRing extends StatelessWidget {
  const StayProgressRing({
    super.key,
    required this.progress,
    this.size = 72,
    this.strokeWidth = 7,
    this.color = AppUIConstants.primaryLight,
    this.trackColor = AppUIConstants.surfaceMuted,
    this.child,
  });

  final double progress;
  final double size;
  final double strokeWidth;
  final Color color;
  final Color trackColor;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final target = progress.clamp(0.0, 1.0);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: target),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RingPainter(
              progress: value,
              strokeWidth: strokeWidth,
              color: color,
              trackColor: trackColor,
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
    required this.strokeWidth,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final double strokeWidth;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final deflated = rect.deflate(strokeWidth / 2);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    canvas.drawArc(deflated, 0, math.pi * 2, false, track);
    if (progress <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(deflated, -math.pi / 2, math.pi * 2 * progress, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}
