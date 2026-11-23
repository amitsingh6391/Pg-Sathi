import 'package:material_ui/material_ui.dart';

import '../../core/app_ui_constants.dart';

/// Ticket-shaped card: a stub on the left, a perforated divider with
/// notches, and a body on the right. Shared by promo and coupon lists.
class TicketCard extends StatelessWidget {
  const TicketCard({
    super.key,
    required this.stub,
    required this.body,
    required this.accent,
    this.stubWidth = 96,
    this.onTap,
  });

  final Widget stub;
  final Widget body;
  final Color accent;
  final double stubWidth;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const notch = 14.0;
    return Container(
      margin: const EdgeInsets.only(bottom: AppUIConstants.spacingMd),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
        boxShadow: [AppUIConstants.shadowSm],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: AppUIConstants.surface,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
              side: const BorderSide(color: AppUIConstants.border),
            ),
            child: InkWell(
              onTap: onTap,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: stubWidth,
                      decoration: BoxDecoration(
                        color: AppUIConstants.surfaceMuted,
                      ),
                      child: stub,
                    ),
                    SizedBox(
                      width: 1,
                      child: CustomPaint(
                        painter: _DashPainter(AppUIConstants.border),
                      ),
                    ),
                    Expanded(child: body),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: stubWidth - notch / 2,
            top: -notch / 2,
            child: _notch(notch),
          ),
          Positioned(
            left: stubWidth - notch / 2,
            bottom: -notch / 2,
            child: _notch(notch),
          ),
        ],
      ),
    );
  }

  Widget _notch(double size) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppUIConstants.background,
        shape: BoxShape.circle,
      ),
    ),
  );
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    double y = 10;
    while (y < size.height - 10) {
      canvas.drawLine(Offset(0, y), Offset(0, y + 4), paint);
      y += 8;
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter old) => old.color != color;
}

/// Human readable expiry countdown + tone.
({String label, Color color}) expiryCountdown(
  DateTime? end, {
  DateTime? start,
}) {
  final now = DateTime.now();
  if (start != null && now.isBefore(start)) {
    final d = start.difference(now);
    return (label: 'Starts in ${_span(d)}', color: AppUIConstants.primaryLight);
  }
  if (end == null) {
    return (label: 'No expiry', color: AppUIConstants.textTertiary);
  }
  if (now.isAfter(end)) {
    return (label: 'Expired', color: AppUIConstants.error);
  }
  final d = end.difference(now);
  return (
    label: 'Ends in ${_span(d)}',
    color: d.inDays < 3 ? AppUIConstants.warning : AppUIConstants.textSecondary,
  );
}

String _span(Duration d) {
  if (d.inDays >= 1) return '${d.inDays}d';
  if (d.inHours >= 1) return '${d.inHours}h';
  return '${d.inMinutes.clamp(1, 59)}m';
}

/// Animated skeleton placeholder list (no packages): pulsing blocks.
class SkeletonList extends StatefulWidget {
  const SkeletonList({super.key, this.count = 4, this.itemHeight = 124});

  final int count;
  final double itemHeight;

  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final color = Color.lerp(
          AppUIConstants.surface,
          AppUIConstants.surfaceMuted,
          Curves.easeInOut.transform(_c.value),
        )!;
        Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: AppUIConstants.border.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(6),
          ),
        );
        return ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppUIConstants.spacingLg),
          itemCount: widget.count,
          itemBuilder: (_, _) => Container(
            height: widget.itemHeight,
            margin: const EdgeInsets.only(bottom: AppUIConstants.spacingMd),
            padding: const EdgeInsets.all(AppUIConstants.spacingLg),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
              border: Border.all(color: AppUIConstants.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  decoration: BoxDecoration(
                    color: AppUIConstants.border.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(
                      AppUIConstants.radiusSm,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      bar(140, 14),
                      const SizedBox(height: 10),
                      bar(double.infinity, 10),
                      const SizedBox(height: 8),
                      bar(90, 10),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Empty / error state with icon and CTA.
class AdminEmptyState extends StatelessWidget {
  const AdminEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.actionIcon = Icons.add_rounded,
    this.color = AppUIConstants.primaryLight,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData actionIcon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.8, end: 1),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutBack,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.12),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Icon(icon, size: 40, color: color),
              ),
            ),
            const SizedBox(height: 20),
            Text(title, style: AppUIConstants.headingMd),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppUIConstants.bodyMd,
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onAction,
                style: AppUIConstants.accentButtonStyle,
                icon: Icon(actionIcon, size: 20),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
