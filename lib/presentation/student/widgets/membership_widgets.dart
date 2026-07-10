import 'package:flutter/material.dart';

import '../../core/app_ui_constants.dart';

/// Status badge for membership cards.
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 10,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  (String?, Color) _getLabelAndColor() {
    if (isExpired) {
      return ('EXPIRED', AppUIConstants.textTertiary);
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

/// Info item for displaying labeled values.
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
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppUIConstants.textTertiary,
            fontSize: 10,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? AppUIConstants.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
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
      color: AppUIConstants.divider,
    );
  }
}

/// Action button for membership cards.
/// Supports an optional [statusColor] to tint icon and label
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
    final iconColor = isPrimary
        ? Colors.white
        : (statusColor ?? AppUIConstants.textSecondary);
    final labelColor = isPrimary
        ? Colors.white
        : (statusColor ?? AppUIConstants.textPrimary);
    final borderColor = statusColor?.withValues(alpha: 0.4)
        ?? AppUIConstants.divider;

    return Material(
      color: isPrimary
          ? AppUIConstants.primary
          : (statusColor?.withValues(alpha: 0.06) ?? AppUIConstants.background),
      borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
            border: isPrimary ? null : Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: iconColor),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: labelColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
