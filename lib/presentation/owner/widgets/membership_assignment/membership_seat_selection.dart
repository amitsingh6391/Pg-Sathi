import 'package:material_ui/material_ui.dart';

import '../../../../domain/entities/custom_slot.dart';
import '../../../../domain/entities/library.dart';
import '../../cubit/membership_assignment_state.dart';
import '../../../core/app_ui_constants.dart';
import 'membership_header_widgets.dart';

/// Step card for choosing a bed on the bed map and a room/rent plan.
/// Collapses to a summary chip when selection is complete.
///
/// Supports two layouts, chosen by [useNewLayout]:
///   - false -> classic plan-first flow (pick a room plan, then a bed).
///   - true  -> bed-first flow (pick a bed from the full bed map, then a plan).
class SeatSelectionCard extends StatelessWidget {
  const SeatSelectionCard({
    super.key,
    required this.library,
    required this.state,
    required this.isCollapsed,
    required this.enabled,
    required this.onCustomSlotSelected,
    required this.onSeatSelected,
    required this.onChangeSelection,
    this.useNewLayout = false,
    this.slotSectionKey,
  });

  final Library library;
  final MembershipAssignmentState state;
  final bool isCollapsed;
  final bool enabled;
  final ValueChanged<String> onCustomSlotSelected;
  final ValueChanged<String> onSeatSelected;
  final VoidCallback onChangeSelection;

  final bool useNewLayout;
  final Key? slotSectionKey;

  @override
  Widget build(BuildContext context) {
    if (isCollapsed) {
      return _CollapsedSelectionSummary(
        seatId: state.selectedSeatId!,
        customSlot: state.selectedCustomSlot,
        onChangeSelection: onChangeSelection,
      );
    }

    if (useNewLayout) {
      return _SeatFirstCard(
        library: library,
        state: state,
        enabled: enabled,
        slotSectionKey: slotSectionKey,
        onCustomSlotSelected: onCustomSlotSelected,
        onSeatSelected: onSeatSelected,
      );
    }

    return MembershipStepCard(
      icon: Icons.bed_rounded,
      title: 'Choose a bed',
      subtitle: 'Pick a room type, then a vacant bed',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PlanSelector(
            state: state,
            enabled: enabled,
            onSelected: onCustomSlotSelected,
          ),
          if (state.selectedCustomSlotId != null) ...[
            const SizedBox(height: 16),
            const _BedLegend(),
            const SizedBox(height: 4),
            _ClassicBedMap(
              library: library,
              state: state,
              enabled: enabled,
              onSeatSelected: onSeatSelected,
            ),
          ],
        ],
      ),
    );
  }
}

// ===========================================================================
// Collapsed summary
// ===========================================================================

class _CollapsedSelectionSummary extends StatelessWidget {
  const _CollapsedSelectionSummary({
    required this.seatId,
    required this.onChangeSelection,
    this.customSlot,
  });

  final String seatId;
  final CustomSlot? customSlot;
  final VoidCallback onChangeSelection;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
        border: Border.all(
          color: AppUIConstants.primaryLight.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: AppUIConstants.primaryLight.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppUIConstants.primary,
              borderRadius: BorderRadius.circular(AppUIConstants.radiusSm + 2),
              boxShadow: [
                BoxShadow(
                  color: AppUIConstants.primaryLight.withValues(alpha: 0.4),
                  blurRadius: 12,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              seatId,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppUIConstants.success,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text('Bed $seatId selected', style: AppUIConstants.bodyLg),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  customSlot != null
                      ? '${customSlot!.name} · ₹${customSlot!.price.toInt()}/month'
                      : 'Custom room type',
                  style: AppUIConstants.bodySm,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onChangeSelection,
            icon: const Icon(Icons.swap_horiz_rounded, size: 16),
            label: const Text('Change'),
            style: TextButton.styleFrom(
              foregroundColor: AppUIConstants.primaryLight,
              textStyle: const TextStyle(
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

// ===========================================================================
// Legend + bed chip
// ===========================================================================

enum _BedVisual { vacant, selected, occupied, reserved }

class _BedLegend extends StatelessWidget {
  const _BedLegend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: const [
        _LegendItem(visual: _BedVisual.vacant, label: 'Vacant'),
        _LegendItem(visual: _BedVisual.selected, label: 'Selected'),
        _LegendItem(visual: _BedVisual.reserved, label: 'Reserved'),
        _LegendItem(visual: _BedVisual.occupied, label: 'Occupied'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.visual, required this.label});

  final _BedVisual visual;
  final String label;

  @override
  Widget build(BuildContext context) {
    final style = _BedStyle.of(visual);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: style.fill,
            border: Border.all(color: style.border, width: 1.5),
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: AppUIConstants.caption),
      ],
    );
  }
}

class _BedStyle {
  const _BedStyle(this.fill, this.border, this.text);

  final Color fill;
  final Color border;
  final Color text;

  static _BedStyle of(_BedVisual v) {
    switch (v) {
      case _BedVisual.selected:
        return const _BedStyle(
          AppUIConstants.primary,
          AppUIConstants.primaryLight,
          Colors.white,
        );
      case _BedVisual.occupied:
        return const _BedStyle(
          AppUIConstants.surfaceMuted,
          AppUIConstants.divider,
          AppUIConstants.textTertiary,
        );
      case _BedVisual.reserved:
        return _BedStyle(
          AppUIConstants.warning.withValues(alpha: 0.14),
          AppUIConstants.warning.withValues(alpha: 0.6),
          AppUIConstants.warning,
        );
      case _BedVisual.vacant:
        return _BedStyle(
          AppUIConstants.primaryLight.withValues(alpha: 0.06),
          AppUIConstants.primaryLight.withValues(alpha: 0.55),
          AppUIConstants.primaryLight,
        );
    }
  }
}

/// A single bed on the bed map with press / select micro-interactions.
class _BedChip extends StatefulWidget {
  const _BedChip({
    required this.label,
    required this.visual,
    required this.enabled,
    required this.onTap,
    required this.index,
  });

  final String label;
  final _BedVisual visual;
  final bool enabled;
  final VoidCallback onTap;
  final int index;

  @override
  State<_BedChip> createState() => _BedChipState();
}

class _BedChipState extends State<_BedChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final style = _BedStyle.of(widget.visual);
    final selected = widget.visual == _BedVisual.selected;
    final unavailable =
        widget.visual == _BedVisual.occupied ||
        widget.visual == _BedVisual.reserved;
    final delay = 140 + (widget.index > 24 ? 24 : widget.index) * 14;

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: delay),
      tween: Tween(begin: 0, end: 1),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.scale(scale: 0.85 + 0.15 * value, child: child),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.enabled
            ? (_) => setState(() => _pressed = true)
            : null,
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutBack,
          scale: _pressed ? 0.9 : (selected ? 1.07 : 1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: style.fill,
              borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
              border: Border.all(color: style.border, width: selected ? 2 : 1),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppUIConstants.primaryLight.withValues(
                          alpha: 0.45,
                        ),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ]
                  : const [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  unavailable ? Icons.person_rounded : Icons.bed_rounded,
                  size: 13,
                  color: style.text.withValues(alpha: 0.85),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: style.text,
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

/// Lays out [seats] in groups of [groupSize] with a small header per group.
class _BedGroups extends StatelessWidget {
  const _BedGroups({
    required this.seats,
    required this.visualFor,
    required this.enabled,
    required this.onSeatSelected,
    this.title,
  });

  final List<String> seats;
  final _BedVisual Function(String seatId) visualFor;
  final bool enabled;
  final ValueChanged<String> onSeatSelected;
  final String? title;
  static const int groupSize = 10;

  @override
  Widget build(BuildContext context) {
    final groups = <List<String>>[];
    for (var i = 0; i < seats.length; i += groupSize) {
      groups.add(
        seats.sublist(
          i,
          i + groupSize > seats.length ? seats.length : i + groupSize,
        ),
      );
    }

    var running = 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final group in groups)
          Builder(
            builder: (context) {
              final startIndex = running;
              running += group.length;
              final vacant = group
                  .where((s) => visualFor(s) == _BedVisual.vacant)
                  .length;
              final header = (title != null && groups.length == 1)
                  ? title!
                  : '${group.first} – ${group.last}';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 14, bottom: 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.meeting_room_rounded,
                          size: 14,
                          color: AppUIConstants.textTertiary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          header,
                          style: const TextStyle(
                            color: AppUIConstants.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const Spacer(),
                        Text('$vacant vacant', style: AppUIConstants.caption),
                      ],
                    ),
                  ),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          childAspectRatio: 1.15,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                    itemCount: group.length,
                    itemBuilder: (context, i) {
                      final seatId = group[i];
                      return _BedChip(
                        label: seatId,
                        visual: visualFor(seatId),
                        enabled: enabled,
                        index: startIndex + i,
                        onTap: () => onSeatSelected(seatId),
                      );
                    },
                  ),
                ],
              );
            },
          ),
      ],
    );
  }
}

// ===========================================================================
// Classic (plan-first) bed map
// ===========================================================================

class _ClassicBedMap extends StatelessWidget {
  const _ClassicBedMap({
    required this.library,
    required this.state,
    required this.enabled,
    required this.onSeatSelected,
  });

  final Library library;
  final MembershipAssignmentState state;
  final bool enabled;
  final ValueChanged<String> onSeatSelected;

  @override
  Widget build(BuildContext context) {
    // Use bed group labels if selected (honours prefix & start number),
    // otherwise fall back to PG capacity with default B numbering.
    final slot = state.selectedCustomSlot;
    final seats = slot != null
        ? slot.seatLabels
        : List.generate(library.capacity, (i) => 'B${i + 1}');

    return _BedGroups(
      seats: seats,
      title: slot?.name,
      enabled: enabled,
      onSeatSelected: onSeatSelected,
      visualFor: (seatId) {
        if (state.selectedSeatId == seatId) return _BedVisual.selected;
        if (state.isSeatCustomSlotOccupied(
          seatId,
          state.selectedCustomSlotId!,
        )) {
          return _BedVisual.occupied;
        }
        if (state.isSeatCustomSlotReserved(
          seatId,
          state.selectedCustomSlotId!,
        )) {
          return _BedVisual.reserved;
        }
        return _BedVisual.vacant;
      },
    );
  }
}

// ===========================================================================
// Bed-first layout
// ===========================================================================

class _SeatFirstCard extends StatelessWidget {
  const _SeatFirstCard({
    required this.library,
    required this.state,
    required this.enabled,
    required this.onCustomSlotSelected,
    required this.onSeatSelected,
    this.slotSectionKey,
  });

  final Library library;
  final MembershipAssignmentState state;
  final bool enabled;
  final ValueChanged<String> onCustomSlotSelected;
  final ValueChanged<String> onSeatSelected;
  final Key? slotSectionKey;

  @override
  Widget build(BuildContext context) {
    return MembershipStepCard(
      icon: Icons.bed_rounded,
      title: 'Choose a bed',
      subtitle: 'Tap a vacant bed on the bed map',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BedLegend(),
          _SeatLayoutGrid(
            library: library,
            state: state,
            enabled: enabled,
            onSeatSelected: onSeatSelected,
          ),
          if (state.selectedSeatId != null) ...[
            const SizedBox(height: 16),
            Container(
              key: slotSectionKey,
              child: _PlanSelector(
                seatId: state.selectedSeatId,
                state: state,
                enabled: enabled,
                onSelected: onCustomSlotSelected,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SeatLayoutGrid extends StatelessWidget {
  const _SeatLayoutGrid({
    required this.library,
    required this.state,
    required this.enabled,
    required this.onSeatSelected,
  });

  final Library library;
  final MembershipAssignmentState state;
  final bool enabled;
  final ValueChanged<String> onSeatSelected;

  @override
  Widget build(BuildContext context) {
    final maxSlotCapacity = state.customSlots.fold<int>(
      0,
      (max, s) => s.capacity > max ? s.capacity : max,
    );
    final totalSeats =
        (library.totalSeatCapacity != null && library.totalSeatCapacity! > 0)
        ? library.totalSeatCapacity!
        : (library.capacity > maxSlotCapacity
              ? library.capacity
              : maxSlotCapacity);

    if (totalSeats <= 0) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No beds configured. Set your total beds in PG settings.',
            textAlign: TextAlign.center,
            style: AppUIConstants.bodySm,
          ),
        ),
      );
    }

    final seats = List.generate(totalSeats, (i) => 'B${i + 1}');

    return _BedGroups(
      seats: seats,
      enabled: enabled,
      onSeatSelected: onSeatSelected,
      visualFor: (seatId) {
        if (state.selectedSeatId == seatId) return _BedVisual.selected;
        switch (state.seatLayoutStatus(seatId)) {
          case SeatLayoutStatus.occupied:
            return _BedVisual.occupied;
          case SeatLayoutStatus.reserved:
            return _BedVisual.reserved;
          case SeatLayoutStatus.partiallyAvailable:
          case SeatLayoutStatus.available:
            return _BedVisual.vacant;
        }
      },
    );
  }
}

// ===========================================================================
// Room / rent plan selector
// ===========================================================================

/// Room plan picker. When [seatId] is given it also shows the bed status for
/// each plan and the number of booked beds.
class _PlanSelector extends StatelessWidget {
  const _PlanSelector({
    required this.state,
    required this.enabled,
    required this.onSelected,
    this.seatId,
  });

  final MembershipAssignmentState state;
  final bool enabled;
  final ValueChanged<String> onSelected;
  final String? seatId;

  @override
  Widget build(BuildContext context) {
    if (state.customSlots.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.meeting_room_rounded,
              size: 16,
              color: AppUIConstants.primaryLight,
            ),
            const SizedBox(width: 6),
            Text(
              seatId != null
                  ? 'Select room type for bed $seatId'
                  : 'Room types',
              style: AppUIConstants.bodyLg.copyWith(fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final cardWidth = w > 400 ? (w - 8) / 2 : w;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: state.customSlots.map((slot) {
                final isSelected = state.selectedCustomSlotId == slot.id;
                final bookedCount = state.bookedCountForSlot(slot.id);
                final isFull =
                    slot.capacity > 0 && bookedCount >= slot.capacity;
                final fill = slot.capacity > 0
                    ? (bookedCount / slot.capacity).clamp(0.0, 1.0)
                    : 0.0;
                return SizedBox(
                  width: cardWidth,
                  child: _PlanTile(
                    name: slot.name,
                    price: '₹${slot.price.toInt()}/month',
                    booked: slot.capacity > 0
                        ? '$bookedCount/${slot.capacity} beds booked'
                        : null,
                    fill: fill,
                    isFull: isFull,
                    isSelected: isSelected,
                    badge: seatId == null
                        ? null
                        : _statusBadge(
                            state.isSeatCustomSlotOccupied(seatId!, slot.id),
                            state.isSeatCustomSlotReserved(seatId!, slot.id),
                          ),
                    onTap: enabled ? () => onSelected(slot.id) : null,
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _statusBadge(bool occupied, bool reserved) {
    final String label;
    final Color color;
    if (occupied) {
      label = 'Occupied';
      color = AppUIConstants.error;
    } else if (reserved) {
      label = 'Reserved';
      color = AppUIConstants.warning;
    } else {
      label = 'Vacant';
      color = AppUIConstants.primaryLight;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppUIConstants.surfaceMuted,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.name,
    required this.price,
    required this.fill,
    required this.isFull,
    required this.isSelected,
    required this.onTap,
    this.booked,
    this.badge,
  });

  final String name;
  final String price;
  final String? booked;
  final double fill;
  final bool isFull;
  final bool isSelected;
  final Widget? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const accent = AppUIConstants.primaryLight;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isSelected
            ? accent.withValues(alpha: 0.1)
            : AppUIConstants.surfaceMuted,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        border: Border.all(
          color: isSelected ? accent : AppUIConstants.border,
          width: isSelected ? 1.8 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.2),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : const [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                          color: isSelected
                              ? accent
                              : AppUIConstants.textPrimary,
                        ),
                      ),
                    ),
                    if (badge != null) ...[const SizedBox(width: 6), badge!],
                    if (isSelected) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.check_circle_rounded,
                        color: accent,
                        size: 16,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  price,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppUIConstants.textSecondary,
                  ),
                ),
                if (booked != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: fill,
                      minHeight: 4,
                      backgroundColor: AppUIConstants.border,
                      valueColor: AlwaysStoppedAnimation(
                        isFull
                            ? AppUIConstants.error
                            : AppUIConstants.primaryLight,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    booked!,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isFull
                          ? AppUIConstants.error
                          : AppUIConstants.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
