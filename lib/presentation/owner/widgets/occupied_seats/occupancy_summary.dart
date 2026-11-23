import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../core/app_ui_constants.dart';
import '../../../core/widgets/premium_kit.dart';

/// Counts shown in the residents summary hero.
class OccupancySummaryData {
  const OccupancySummaryData({
    required this.capacity,
    required this.occupied,
    required this.reserved,
    required this.expiring,
    required this.expired,
  });

  final int capacity;
  final int occupied;
  final int reserved;
  final int expiring;
  final int expired;

  int get taken => occupied + reserved;
  int get vacant => math.max(0, capacity - taken);
  double get fraction => capacity <= 0 ? 0 : (taken / capacity).clamp(0, 1);
}

/// Hero band: title row slot, occupancy ring, segmented bar and count tiles.
class OccupancySummaryHero extends StatelessWidget {
  const OccupancySummaryHero({super.key, required this.data, this.subtitle});

  final OccupancySummaryData data;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final percent = (data.fraction * 100).round();
    return PremiumHero(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 92,
                height: 92,
                child: CustomPaint(
                  painter: _RingPainter(data.fraction),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$percent%',
                          style: const TextStyle(
                            color: AppUIConstants.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'full',
                          style: const TextStyle(
                            color: AppUIConstants.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${data.taken} of ${data.capacity} beds filled',
                      style: const TextStyle(
                        color: AppUIConstants.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.vacant == 0
                          ? 'Your PG is full'
                          : '${data.vacant} ${data.vacant == 1 ? 'bed' : 'beds'} vacant',
                      style: const TextStyle(
                        color: AppUIConstants.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SegmentedBar(data: data),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _CountTile(
                label: 'Occupied',
                value: data.occupied,
                color: AppUIConstants.primaryLight,
              ),
              _CountTile(
                label: 'Vacant',
                value: data.vacant,
                color: AppUIConstants.textPrimary,
              ),
              _CountTile(
                label: 'Reserved',
                value: data.reserved,
                color: AppUIConstants.primaryLight,
              ),
              _CountTile(
                label: 'Expiring',
                value: data.expiring,
                color: AppUIConstants.warning,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppUIConstants.surfaceMuted,
          borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
          border: Border.all(color: AppUIConstants.border),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: AppUIConstants.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentedBar extends StatelessWidget {
  const _SegmentedBar({required this.data});

  final OccupancySummaryData data;

  @override
  Widget build(BuildContext context) {
    final paid = math.max(0, data.occupied - data.expiring);
    final segs = <(int, Color)>[
      (paid, AppUIConstants.primaryLight),
      (math.min(data.expiring, data.occupied), AppUIConstants.warning),
      (data.reserved, AppUIConstants.warning),
      (data.vacant, AppUIConstants.border),
    ].where((s) => s.$1 > 0).toList();
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 8,
        child: Row(
          children: [
            for (final s in segs)
              Expanded(
                flex: s.$1,
                child: Container(
                  color: s.$2,
                  margin: const EdgeInsets.only(right: 1.5),
                ),
              ),
            if (segs.isEmpty)
              Expanded(child: Container(color: AppUIConstants.border)),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.fraction);

  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 9.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = AppUIConstants.surfaceMuted;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, track);
    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke
      ..shader = const SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
        colors: [AppUIConstants.primaryLight, AppUIConstants.primaryLight],
        transform: GradientRotation(-math.pi / 2),
      ).createShader(rect);
    canvas.drawArc(arcRect, -math.pi / 2, math.pi * 2 * fraction, false, fill);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction;
}
