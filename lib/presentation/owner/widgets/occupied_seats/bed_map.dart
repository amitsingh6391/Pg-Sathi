import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../../core/app_ui_constants.dart';
import '../../../core/widgets/premium_kit.dart';
import '../../../../domain/usecases/get_occupied_seats.dart';
import 'resident_status.dart';

/// Colored bed chips grouped in blocks of [bedsPerGroup] ("rooms").
/// Occupied beds open the resident via [onResidentTap]; vacant beds call
/// [onVacantTap].
class BedMap extends StatelessWidget {
  const BedMap({
    super.key,
    required this.capacity,
    required this.seats,
    required this.onResidentTap,
    required this.onVacantTap,
    this.bedsPerGroup = 10,
  });

  final int capacity;
  final List<OccupiedSeatInfo> seats;
  final void Function(OccupiedSeatInfo seat) onResidentTap;
  final void Function(int bedNumber) onVacantTap;
  final int bedsPerGroup;

  @override
  Widget build(BuildContext context) {
    // Worst status wins when a bed has several stays.
    final byBed = <int, OccupiedSeatInfo>{};
    for (final s in seats) {
      final n = s.seatNumber;
      final existing = byBed[n];
      if (existing == null ||
          residentStatusOf(s).index > residentStatusOf(existing).index) {
        byBed[n] = s;
      }
    }
    final total = capacity > 0
        ? capacity
        : (byBed.keys.isEmpty ? 0 : byBed.keys.reduce((a, b) => a > b ? a : b));

    if (total == 0) return const SizedBox.shrink();

    final groups = (total / bedsPerGroup).ceil();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: PremiumCard(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PremiumSectionHeader('Bed map'),
            const _Legend(),
            const SizedBox(height: 12),
            for (var g = 0; g < groups; g++) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 6, top: 2),
                child: Text(
                  'Block ${g + 1}  ·  Beds ${g * bedsPerGroup + 1}-${((g + 1) * bedsPerGroup).clamp(0, total)}',
                  style: AppUIConstants.caption,
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (
                    var n = g * bedsPerGroup + 1;
                    n <= ((g + 1) * bedsPerGroup).clamp(0, total);
                    n++
                  )
                    _BedChip(
                      number: n,
                      seat: byBed[n],
                      onTap: () {
                        HapticFeedback.selectionClick();
                        final seat = byBed[n];
                        if (seat != null) {
                          onResidentTap(seat);
                        } else {
                          onVacantTap(n);
                        }
                      },
                    ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _BedChip extends StatelessWidget {
  const _BedChip({
    required this.number,
    required this.seat,
    required this.onTap,
  });

  final int number;
  final OccupiedSeatInfo? seat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = seat == null ? null : residentStatusOf(seat!);
    final color = status?.color;
    return Semantics(
      label: seat == null
          ? 'Bed $number vacant'
          : 'Bed $number, ${seat!.displayName}, ${status!.label}',
      button: true,
      child: Material(
        color: color == null
            ? Colors.transparent
            : color.withValues(
                alpha: status == ResidentStatus.occupied ? 0.28 : 0.22,
              ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
          side: BorderSide(
            color: color?.withValues(alpha: 0.8) ?? AppUIConstants.border,
            width: color == null ? 1 : 1.2,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.bed_rounded,
                  size: 14,
                  color: color ?? AppUIConstants.textTertiary,
                ),
                const SizedBox(height: 1),
                Text(
                  '$number',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color ?? AppUIConstants.textTertiary,
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

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget item(Color c, String label, {bool outline = false}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: outline ? Colors.transparent : c,
            borderRadius: BorderRadius.circular(3),
            border: outline ? Border.all(color: c) : null,
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: AppUIConstants.caption),
      ],
    );
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        item(ResidentStatus.occupied.color, 'Occupied'),
        item(ResidentStatus.due.color, 'Due / reserved'),
        item(ResidentStatus.expiring.color, 'Expiring'),
        item(ResidentStatus.expired.color, 'Expired'),
        item(AppUIConstants.textTertiary, 'Vacant', outline: true),
      ],
    );
  }
}
