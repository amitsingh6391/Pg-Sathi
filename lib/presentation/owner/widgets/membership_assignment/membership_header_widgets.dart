import 'package:material_ui/material_ui.dart';

import '../../../../domain/entities/library.dart';
import '../../../../domain/entities/membership.dart';
import '../../cubit/membership_assignment_state.dart';
import '../../../core/app_ui_constants.dart';
import '../../../core/widgets/premium_kit.dart';

/// Hero header for the Add Tenant flow: back button, title, PG name and the
/// step indicator.
class MembershipAppHeader extends StatelessWidget {
  const MembershipAppHeader({
    super.key,
    required this.library,
    this.onBulkImport,
    this.stepper,
  });

  final Library library;
  final VoidCallback? onBulkImport;

  /// Optional step indicator rendered inside the hero.
  final Widget? stepper;

  @override
  Widget build(BuildContext context) {
    return PremiumHero(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppUIConstants.textPrimary,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Add Tenant',
                      style: TextStyle(
                        color: AppUIConstants.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.4,
                      ),
                    ),
                    Text(
                      library.name,
                      style: const TextStyle(
                        color: AppUIConstants.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (stepper != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 0, 0),
              child: stepper,
            ),
        ],
      ),
    );
  }
}

/// Three-step progress indicator: Resident -> Bed -> Rent & plan.
/// [done] marks completed steps; [current] is the active (first incomplete).
class MembershipStepper extends StatelessWidget {
  const MembershipStepper({
    super.key,
    required this.done,
    required this.current,
  });

  final List<bool> done;
  final int current;

  static const _labels = ['Resident', 'Bed', 'Rent & plan'];

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < _labels.length; i++) {
      children.add(
        _StepDot(
          index: i,
          label: _labels[i],
          isDone: done[i],
          isActive: i == current,
        ),
      );
      if (i < _labels.length - 1) {
        children.add(
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18, left: 6, right: 6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 3,
                decoration: BoxDecoration(
                  color: done[i]
                      ? AppUIConstants.primaryLight
                      : AppUIConstants.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        );
      }
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.index,
    required this.label,
    required this.isDone,
    required this.isActive,
  });

  final int index;
  final String label;
  final bool isDone;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final filled = isDone || isActive;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone
                ? AppUIConstants.primaryLight
                : (isActive
                      ? AppUIConstants.primary
                      : AppUIConstants.surfaceMuted),
            border: Border.all(
              color: filled ? Colors.transparent : AppUIConstants.border,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppUIConstants.primary.withValues(alpha: 0.25),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: isActive
                          ? Colors.white
                          : AppUIConstants.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: filled
                ? AppUIConstants.textPrimary
                : AppUIConstants.textSecondary,
            fontSize: 11.5,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Section card with an icon-well header, used for each step of the flow.
class MembershipStepCard extends StatelessWidget {
  const MembershipStepCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.child,
    this.trailing,
    this.iconColor = AppUIConstants.primaryLight,
    this.dimmed = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final Color iconColor;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: dimmed ? 0.55 : 1,
      child: PremiumCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(
                        AppUIConstants.radiusSm,
                      ),
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppUIConstants.headingSm),
                        if (subtitle != null)
                          Text(subtitle!, style: AppUIConstants.bodySm),
                      ],
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
            const Divider(height: 1, color: AppUIConstants.divider),
            Padding(padding: const EdgeInsets.all(16), child: child),
          ],
        ),
      ),
    );
  }
}

/// Sticky bottom bar: live summary (bed + rent) and the primary CTA.
class MembershipStickyBar extends StatelessWidget {
  const MembershipStickyBar({
    super.key,
    required this.bedLabel,
    required this.roomLabel,
    required this.total,
    required this.ctaLabel,
    required this.onPressed,
    this.isSubmitting = false,
    this.ready = false,
  });

  final String? bedLabel;
  final String? roomLabel;
  final double? total;
  final String ctaLabel;
  final VoidCallback? onPressed;
  final bool isSubmitting;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        border: const Border(top: BorderSide(color: AppUIConstants.border)),
        boxShadow: [AppUIConstants.shadowLg],
      ),
      child: Row(
        children: [
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: bedLabel == null
                  ? const Column(
                      key: ValueKey('none'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('No bed selected', style: AppUIConstants.bodyLg),
                        Text(
                          'Pick a bed on the bed map',
                          style: AppUIConstants.bodySm,
                        ),
                      ],
                    )
                  : Column(
                      key: ValueKey('$bedLabel-$total'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          total != null
                              ? '\u20b9${total!.toStringAsFixed(0)}'
                              : 'Bed $bedLabel',
                          style: AppUIConstants.headingMd,
                        ),
                        Text(
                          [
                            'Bed $bedLabel',
                            if (roomLabel != null) roomLabel!,
                          ].join(' \u00b7 '),
                          style: AppUIConstants.bodySm,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: isSubmitting ? null : onPressed,
              style: AppUIConstants.primaryButtonStyle.copyWith(
                backgroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.disabled)
                      ? AppUIConstants.disabled
                      : (ready
                            ? AppUIConstants.primaryLight
                            : AppUIConstants.surfaceMuted),
                ),
                foregroundColor: WidgetStatePropertyAll(
                  ready ? Colors.white : AppUIConstants.textSecondary,
                ),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ctaLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Summary header card showing PG info and bed availability.
class MembershipSummaryCard extends StatelessWidget {
  const MembershipSummaryCard({
    super.key,
    required this.library,
    required this.state,
  });

  final Library library;
  final MembershipAssignmentState state;

  @override
  Widget build(BuildContext context) {
    // Count occupied seats across all custom slots
    final occupied = state.memberships
        .where(
          (m) =>
              m.assignedSeatId != null &&
              m.slotId != null &&
              m.status == MembershipStatus.active,
        )
        .length;
    final reserved = state.memberships
        .where(
          (m) =>
              m.assignedSeatId != null &&
              m.slotId != null &&
              m.status == MembershipStatus.pendingPayment,
        )
        .length;
    final totalSeats = library.totalSeatCapacity ?? library.capacity;
    final totalAvailable = totalSeats - occupied - reserved;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppUIConstants.border),
      ),
      child: Column(
        children: [
          // Library Info Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppUIConstants.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.apartment_rounded,
                  color: AppUIConstants.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      library.name,
                      style: const TextStyle(
                        color: AppUIConstants.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${library.totalSeatCapacity ?? library.capacity} beds total',
                      style: const TextStyle(
                        color: AppUIConstants.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Overall Availability
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppUIConstants.surfaceMuted,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  label: 'Available',
                  value: totalAvailable,
                  color: AppUIConstants.success,
                ),
                Container(width: 1, height: 30, color: AppUIConstants.border),
                _StatItem(
                  label: 'Occupied',
                  value: occupied,
                  color: AppUIConstants.error,
                ),
                Container(width: 1, height: 30, color: AppUIConstants.border),
                _StatItem(
                  label: 'Reserved',
                  value: reserved,
                  color: AppUIConstants.warning,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: AppUIConstants.textSecondary, fontSize: 11),
        ),
      ],
    );
  }
}
