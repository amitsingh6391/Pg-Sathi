import 'package:flutter/material.dart';

import '../../../../domain/entities/custom_slot.dart';
import '../../../../domain/entities/library.dart';
import '../../cubit/membership_assignment_state.dart';

/// Card for selecting a room/bed plan and then bed.
/// Collapses to a summary chip when selection is complete.
///
/// Supports two layouts, chosen by [useNewLayout]:
///   - false → classic plan-first flow (pick a room plan, then a bed).
///   - true  → bed-first flow (pick a bed from the full grid, then a plan).
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
      final customSlot = state.selectedCustomSlot;
      return _CollapsedSelectionSummary(
        seatId: state.selectedSeatId!,
        customSlot: customSlot,
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.touch_app_rounded,
                    color: Color(0xFF6366F1),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Step 1: Select Plan & Bed',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        'Choose room/bed plan, then select an available bed',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                  ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Room/bed plan selection (FIRST STEP)
                _SlotSelector(
                  state: state,
                  enabled: enabled,
                  onCustomSlotSelected: onCustomSlotSelected,
                ),

                // Bed Grid (appears after plan selection)
                if (state.selectedCustomSlotId != null) ...[
                  const SizedBox(height: 16),
                  if (state.selectedCustomSlot != null)
                    _CustomSeatLegend(slot: state.selectedCustomSlot!),
                  const SizedBox(height: 8),
                  _SeatGrid(
                    library: library,
                    state: state,
                    enabled: enabled,
                    onSeatSelected: onSeatSelected,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Check Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF10B981),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),

          // Bed Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.bed_rounded,
                  color: Color(0xFF6366F1),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  seatId,
                  style: const TextStyle(
                    color: Color(0xFF6366F1),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Plan Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.meeting_room_rounded,
                  color: Color(0xFF6366F1),
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  customSlot?.name ?? 'Custom',
                  style: const TextStyle(
                    color: Color(0xFF6366F1),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),

          // Change Button
          TextButton(
            onPressed: onChangeSelection,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Change',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomSeatLegend extends StatelessWidget {
  const _CustomSeatLegend({required this.slot});

  final CustomSlot slot;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF6366F1);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _LegendItem(color: const Color(0xFF10B981), label: 'Available'),
        _LegendItem(color: Colors.amber.shade600, label: 'Reserved'),
        _LegendItem(color: Colors.red.shade500, label: 'Occupied'),
        _LegendItem(color: color, label: 'Selected', filled: true),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    this.filled = false,
  });

  final Color color;
  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: filled ? color : color.withValues(alpha: 0.2),
            border: Border.all(color: color, width: 1.5),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _SlotSelector extends StatelessWidget {
  const _SlotSelector({
    required this.state,
    required this.enabled,
    required this.onCustomSlotSelected,
  });

  final MembershipAssignmentState state;
  final bool enabled;
  final ValueChanged<String> onCustomSlotSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Room/bed plans
        if (state.customSlots.isNotEmpty) ...[
          if (state.customSlots.length > 2) ...[
            Text(
              'Room / Bed Plans',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              // Calculate card width: use 2 columns on larger screens, 1 on smaller
              // Account for spacing (8px) and padding (16px on each side)
              final availableWidth = constraints.maxWidth;
              final cardWidth = availableWidth > 400
                  ? (availableWidth - 8) /
                        2 // 2 columns with spacing
                  : availableWidth; // 1 column on small screens

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: state.customSlots.map((slot) {
                  final isSelected = state.selectedCustomSlotId == slot.id;
                  const color = Color(0xFF6366F1);

                  return SizedBox(
                    width: cardWidth,
                    child: Material(
                      color: isSelected
                          ? color.withValues(alpha: 0.1)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: enabled
                            ? () {
                                onCustomSlotSelected(slot.id);
                              }
                            : null,
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? color
                                  : const Color(0xFFE2E8F0),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.meeting_room_rounded,
                                color: isSelected
                                    ? color
                                    : const Color(0xFF94A3B8),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      slot.name,
                                      style: TextStyle(
                                        color: isSelected
                                            ? color
                                            : const Color(0xFF64748B),
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "${slot.capacity} beds • ${slot.price.toInt()}/month",
                                      style: TextStyle(
                                        color: isSelected
                                            ? color.withValues(alpha: 0.7)
                                            : const Color(0xFF94A3B8),
                                        fontSize: 11,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected) ...[
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: Color(0xFF6366F1),
                                  size: 16,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _SeatGrid extends StatelessWidget {
  const _SeatGrid({
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
    // otherwise fall back to library capacity with default B numbering.
    final slot = state.selectedCustomSlot;
    final seats = slot != null
        ? slot.seatLabels
        : List.generate(library.capacity, (i) => 'B${i + 1}');

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        childAspectRatio: 1.1,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      itemCount: seats.length,
      itemBuilder: (context, index) {
        final seatId = seats[index];
        // Check bed status across the PG, regardless of bed group.
        final isOccupied = state.isSeatCustomSlotOccupied(
          seatId,
          state.selectedCustomSlotId!,
        );
        final isReserved = state.isSeatCustomSlotReserved(
          seatId,
          state.selectedCustomSlotId!,
        );
        final isSelected = state.selectedSeatId == seatId;

        const Color customSlotColor = Color(0xFF6366F1);

        Color bgColor;
        Color borderColor;
        Color textColor;

        if (isSelected) {
          bgColor = customSlotColor;
          borderColor = const Color(0xFF4F46E5);
          textColor = Colors.white;
        } else if (isOccupied) {
          bgColor = Colors.red.shade50;
          borderColor = Colors.red.shade200;
          textColor = Colors.red.shade600;
        } else if (isReserved) {
          bgColor = Colors.amber.shade50;
          borderColor = Colors.amber.shade200;
          textColor = Colors.amber.shade700;
        } else {
          bgColor = const Color(0xFF10B981).withValues(alpha: 0.08);
          borderColor = const Color(0xFF10B981).withValues(alpha: 0.4);
          textColor = const Color(0xFF10B981);
        }

        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 150 + (index * 15)),
          tween: Tween(begin: 0, end: 1),
          builder: (context, value, child) {
            return Transform.scale(
              scale: 0.85 + (0.15 * value),
              child: Opacity(opacity: value, child: child),
            );
          },
          child: Material(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            elevation: isSelected ? 3 : 0,
            shadowColor: isSelected
                ? customSlotColor.withValues(alpha: 0.4)
                : Colors.transparent,
            child: InkWell(
              onTap: enabled ? () => onSeatSelected(seatId) : null,
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: borderColor,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    seatId,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SeatLayoutLegend(),
            const SizedBox(height: 4),
            _SeatLayoutGrid(
              library: library,
              state: state,
              enabled: enabled,
              onSeatSelected: onSeatSelected,
            ),
            if (state.selectedSeatId != null) ...[
              const SizedBox(height: 8),
              Padding(
                key: slotSectionKey,
                padding: EdgeInsets.zero,
                child: _SeatSlotSelector(
                  seatId: state.selectedSeatId!,
                  state: state,
                  enabled: enabled,
                  onCustomSlotSelected: onCustomSlotSelected,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SeatLayoutLegend extends StatelessWidget {
  const _SeatLayoutLegend();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          const _LegendItem(color: Color(0xFF10B981), label: 'Available'),
          const SizedBox(width: 12),
          _LegendItem(color: Colors.amber.shade600, label: 'Reserved'),
          const SizedBox(width: 12),
          _LegendItem(color: Colors.red.shade500, label: 'Occupied'),
          const SizedBox(width: 12),
          const _LegendItem(
            color: Color(0xFF6366F1),
            label: 'Selected',
            filled: true,
          ),
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
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No beds configured. Set your total beds in PG settings.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ),
      );
    }

    final seats = List.generate(totalSeats, (i) => 'B${i + 1}');

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        childAspectRatio: 1.1,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      padding: const EdgeInsets.only(top: 16, bottom: 12),
      itemCount: seats.length,
      itemBuilder: (context, index) {
        final seatId = seats[index];
        final layoutStatus = state.seatLayoutStatus(seatId);
        final isSelected = state.selectedSeatId == seatId;

        const Color selectedColor = Color(0xFF6366F1);

        Color bgColor;
        Color borderColor;
        Color textColor;

        if (isSelected) {
          bgColor = selectedColor;
          borderColor = const Color(0xFF4F46E5);
          textColor = Colors.white;
        } else {
          switch (layoutStatus) {
            case SeatLayoutStatus.partiallyAvailable:
              bgColor = const Color(0xFF795548).withValues(alpha: 0.08);
              borderColor = const Color(0xFF795548).withValues(alpha: 0.45);
              textColor = const Color(0xFF5D4037);
            case SeatLayoutStatus.occupied:
              bgColor = Colors.red.shade50;
              borderColor = Colors.red.shade200;
              textColor = Colors.red.shade600;
            case SeatLayoutStatus.reserved:
              bgColor = Colors.amber.shade50;
              borderColor = Colors.amber.shade200;
              textColor = Colors.amber.shade700;
            case SeatLayoutStatus.available:
              bgColor = const Color(0xFF10B981).withValues(alpha: 0.08);
              borderColor = const Color(0xFF10B981).withValues(alpha: 0.4);
              textColor = const Color(0xFF10B981);
          }
        }

        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 150 + (index * 15)),
          tween: Tween(begin: 0, end: 1),
          builder: (context, value, child) {
            return Transform.scale(
              scale: 0.85 + (0.15 * value),
              child: Opacity(opacity: value, child: child),
            );
          },
          child: Material(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            elevation: isSelected ? 3 : 0,
            shadowColor: isSelected
                ? selectedColor.withValues(alpha: 0.4)
                : Colors.transparent,
            child: InkWell(
              onTap: enabled ? () => onSeatSelected(seatId) : null,
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: borderColor,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    seatId,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SeatSlotSelector extends StatelessWidget {
  const _SeatSlotSelector({
    required this.seatId,
    required this.state,
    required this.enabled,
    required this.onCustomSlotSelected,
  });

  final String seatId;
  final MembershipAssignmentState state;
  final bool enabled;
  final ValueChanged<String> onCustomSlotSelected;

  @override
  Widget build(BuildContext context) {
    if (state.customSlots.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.bed_rounded,
              size: 16,
              color: Color(0xFF6366F1),
            ),
            const SizedBox(width: 6),
            Text(
              'Select plan for bed $seatId',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth;
            final cardWidth = availableWidth > 400
                ? (availableWidth - 8) / 2
                : availableWidth;

            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: state.customSlots.map((slot) {
                final isSelected = state.selectedCustomSlotId == slot.id;
                final isOccupied = state.isSeatCustomSlotOccupied(
                  seatId,
                  slot.id,
                );
                final isReserved = state.isSeatCustomSlotReserved(
                  seatId,
                  slot.id,
                );
                final bookedCount = state.bookedCountForSlot(slot.id);
                final isFull =
                    slot.capacity > 0 && bookedCount >= slot.capacity;
                const color = Color(0xFF6366F1);

                return SizedBox(
                  width: cardWidth,
                  child: Material(
                    color: isSelected
                        ? color.withValues(alpha: 0.1)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: enabled
                          ? () => onCustomSlotSelected(slot.id)
                          : null,
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? color : const Color(0xFFE2E8F0),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.bed_rounded,
                              color: isSelected
                                  ? color
                                  : const Color(0xFF94A3B8),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          slot.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: isSelected
                                                ? color
                                                : const Color(0xFF1E293B),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      _SlotSeatStatusBadge(
                                        isOccupied: isOccupied,
                                        isReserved: isReserved,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    slot.capacity > 0
                                        ? '\u20b9${slot.price.toInt()}/month \u00b7 $bookedCount/${slot.capacity} booked'
                                        : '\u20b9${slot.price.toInt()}/month',
                                    style: TextStyle(
                                      color: isFull
                                          ? Colors.red.shade400
                                          : (isSelected
                                                ? color.withValues(alpha: 0.7)
                                                : const Color(0xFF94A3B8)),
                                      fontSize: 11,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF6366F1),
                                size: 16,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _SlotSeatStatusBadge extends StatelessWidget {
  const _SlotSeatStatusBadge({
    required this.isOccupied,
    required this.isReserved,
  });

  final bool isOccupied;
  final bool isReserved;

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color color;
    if (isOccupied) {
      label = 'Occupied';
      color = Colors.red.shade500;
    } else if (isReserved) {
      label = 'Reserved';
      color = Colors.amber.shade700;
    } else {
      label = 'Free';
      color = const Color(0xFF10B981);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
