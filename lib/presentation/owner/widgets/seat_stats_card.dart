import 'package:flutter/material.dart';

import '../../core/app_ui_constants.dart';

/// Premium bed statistics card for owner dashboard.
/// Shows available, pending, and occupied beds with visual progress.
class SeatStatsCard extends StatelessWidget {
  const SeatStatsCard({
    super.key,
    required this.availableSeats,
    required this.pendingSeats,
    required this.occupiedSeats,
    this.onTap,
    this.isLocked = false,
    this.onLockedTap,
  });

  final int availableSeats;
  final int pendingSeats;
  final int occupiedSeats;
  final VoidCallback? onTap;
  final bool isLocked;
  final VoidCallback? onLockedTap;

  int get totalSeats => availableSeats + pendingSeats + occupiedSeats;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLocked ? onLockedTap : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppUIConstants.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isLocked
                      ? AppUIConstants.disabled.withValues(alpha: 0.3)
                      : AppUIConstants.border,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Header section
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bed Overview',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppUIConstants.textSecondary,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '$totalSeats',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                      color: isLocked
                                          ? AppUIConstants.disabled
                                          : AppUIConstants.textPrimary,
                                      height: 1.1,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'total beds',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w400,
                                      color: AppUIConstants.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Occupancy badge
                        if (totalSeats > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getOccupancyColor().withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${((occupiedSeats / totalSeats) * 100).round()}% filled',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isLocked
                                    ? AppUIConstants.disabled
                                    : _getOccupancyColor(),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Progress bar
                  if (totalSeats > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: SizedBox(
                          height: 6,
                          child: Row(
                            children: [
                              // Occupied (blue)
                              if (occupiedSeats > 0)
                                Expanded(
                                  flex: occupiedSeats,
                                  child: Container(
                                    color: isLocked
                                        ? AppUIConstants.disabled
                                        : AppUIConstants.primary,
                                  ),
                                ),
                              // Pending (amber)
                              if (pendingSeats > 0)
                                Expanded(
                                  flex: pendingSeats,
                                  child: Container(
                                    color: isLocked
                                        ? AppUIConstants.disabled.withValues(
                                            alpha: 0.7,
                                          )
                                        : AppUIConstants.warning,
                                  ),
                                ),
                              // Available (green)
                              if (availableSeats > 0)
                                Expanded(
                                  flex: availableSeats,
                                  child: Container(
                                    color: isLocked
                                        ? AppUIConstants.disabled.withValues(
                                            alpha: 0.4,
                                          )
                                        : AppUIConstants.success,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Stats row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _StatTile(
                            value: occupiedSeats,
                            label: 'Occupied',
                            color: AppUIConstants.primary,
                            isLocked: isLocked,
                          ),
                        ),
                        _VerticalDivider(isLocked: isLocked),
                        Expanded(
                          child: _StatTile(
                            value: pendingSeats,
                            label: 'Pending',
                            color: AppUIConstants.warning,
                            isLocked: isLocked,
                          ),
                        ),
                        _VerticalDivider(isLocked: isLocked),
                        Expanded(
                          child: _StatTile(
                            value: availableSeats,
                            label: 'Available',
                            color: AppUIConstants.success,
                            isLocked: isLocked,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Lock overlay
            if (isLocked)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppUIConstants.surface,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: AppUIConstants.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppUIConstants.warning,
                                  AppUIConstants.warning.withValues(alpha: 0.8),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.lock_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Subscribe to View',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppUIConstants.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getOccupancyColor() {
    if (totalSeats == 0) return AppUIConstants.textTertiary;
    final occupancyRate = occupiedSeats / totalSeats;
    if (occupancyRate >= 0.9) return AppUIConstants.error;
    if (occupancyRate >= 0.7) return AppUIConstants.warning;
    return AppUIConstants.success;
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    required this.color,
    this.isLocked = false,
  });

  final int value;
  final String label;
  final Color color;
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = isLocked ? AppUIConstants.disabled : color;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: effectiveColor,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: effectiveColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isLocked
                      ? AppUIConstants.disabled
                      : AppUIConstants.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider({this.isLocked = false});

  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            isLocked
                ? AppUIConstants.disabled.withValues(alpha: 0.3)
                : AppUIConstants.border,
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}
