import 'package:material_ui/material_ui.dart';

import '../../../domain/entities/library.dart';
import '../../../domain/usecases/get_all_libraries.dart';
import '../../core/app_ui_constants.dart';

/// PG listing card for the explore screen. Mirrors the Library Manager
/// explore card (photo with overlays, name/area, amenity chips, solid CTA)
/// and adds PG specifics: rent-from and a bed occupancy meter.
class ExploreLibraryCard extends StatelessWidget {
  const ExploreLibraryCard({
    super.key,
    required this.libraryWithStats,
    required this.onTap,
  });

  final LibraryWithStats libraryWithStats;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final library = libraryWithStats.library;
    final stats = libraryWithStats.stats;
    final availableBeds = stats.availableSeats;
    final isFull = availableBeds <= 0;
    final total = stats.totalSeats > 0 ? stats.totalSeats : library.capacity;
    final occupiedBeds = total > 0 ? total - availableBeds.clamp(0, total) : 0;
    final occupiedRatio = total > 0 ? occupiedBeds / total : 0.0;
    final distanceKm = libraryWithStats.distanceKm;
    final price = library.customMonthlyPrice;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [AppUIConstants.shadowSm],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---- Photo with overlays ----
              Stack(
                children: [
                  _CardImage(
                    photoUrl: library.photos.isNotEmpty
                        ? library.photos.first
                        : null,
                  ),
                  // Bottom scrim so overlaid chips stay readable
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.32),
                          ],
                          stops: const [0.55, 1.0],
                        ),
                      ),
                    ),
                  ),
                  if (distanceKm != null)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: _GlassPill(
                        icon: Icons.near_me_rounded,
                        label: '${distanceKm.toStringAsFixed(1)} km',
                      ),
                    ),
                  if (library.photos.length > 1)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: _GlassPill(
                        icon: Icons.photo_library_outlined,
                        label: '${library.photos.length}',
                      ),
                    ),
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: _VacancyBadge(
                      available: availableBeds,
                      isFull: isFull,
                    ),
                  ),
                ],
              ),
              // ---- Content ----
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                library.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: AppUIConstants.textPrimary,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.location_on_rounded,
                                    size: 14,
                                    color: AppUIConstants.textTertiary,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      library.area ?? library.location,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppUIConstants.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (price != null) ...[
                          const SizedBox(width: 12),
                          _RentTag(price: price),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),
                    _AmenitiesRow(facilities: library.enabledFacilities),
                    if (total > 0) ...[
                      const SizedBox(height: 14),
                      _OccupancyMeter(
                        ratio: occupiedRatio,
                        occupied: occupiedBeds,
                        total: total,
                        isFull: isFull,
                      ),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isFull ? null : onTap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppUIConstants.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppUIConstants.divider,
                          disabledForegroundColor: AppUIConstants.textTertiary,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          isFull ? 'No beds available' : 'View beds & rent',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// PG cover image with a graceful placeholder + loading state.
class _CardImage extends StatelessWidget {
  const _CardImage({required this.photoUrl});

  final String? photoUrl;

  static const double _height = 172;

  @override
  Widget build(BuildContext context) {
    if (photoUrl == null) return _placeholder();
    return Image.network(
      photoUrl!,
      height: _height,
      width: double.infinity,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          height: _height,
          width: double.infinity,
          color: AppUIConstants.divider,
          child: const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppUIConstants.textTertiary,
              ),
            ),
          ),
        );
      },
      errorBuilder: (_, _, _) => _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      height: _height,
      width: double.infinity,
      color: AppUIConstants.divider,
      child: const Icon(
        Icons.apartment_rounded,
        size: 40,
        color: AppUIConstants.textTertiary,
      ),
    );
  }
}

/// Frosted pill used for overlays on the image (distance, photo count).
class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Solid vacancy badge — real bed count, colour-coded by urgency.
class _VacancyBadge extends StatelessWidget {
  const _VacancyBadge({required this.available, required this.isFull});

  final int available;
  final bool isFull;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    if (isFull) {
      color = AppUIConstants.textSecondary;
      label = 'Fully occupied';
    } else if (available <= 5) {
      color = AppUIConstants.warning;
      label = 'Only $available ${available == 1 ? 'bed' : 'beds'} left';
    } else {
      color = AppUIConstants.success;
      label = '$available beds vacant';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// "₹X / month" rent tag shown beside the PG name.
class _RentTag extends StatelessWidget {
  const _RentTag({required this.price});

  final double price;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '₹${price.toStringAsFixed(0)}',
          style: const TextStyle(
            color: AppUIConstants.primary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'per month',
          style: TextStyle(fontSize: 11.5, color: AppUIConstants.textTertiary),
        ),
      ],
    );
  }
}

/// Thin bed-occupancy bar with label.
class _OccupancyMeter extends StatelessWidget {
  const _OccupancyMeter({
    required this.ratio,
    required this.occupied,
    required this.total,
    required this.isFull,
  });

  final double ratio;
  final int occupied;
  final int total;
  final bool isFull;

  @override
  Widget build(BuildContext context) {
    const labelStyle = TextStyle(
      fontSize: 12,
      color: AppUIConstants.textSecondary,
    );
    return Column(
      children: [
        Row(
          children: [
            Text('${(ratio * 100).round()}% occupied', style: labelStyle),
            const Spacer(),
            Text('$occupied/$total beds', style: labelStyle),
          ],
        ),
        const SizedBox(height: 6),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: ratio),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (_, v, _) => ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: v,
              minHeight: 5,
              backgroundColor: AppUIConstants.divider,
              valueColor: AlwaysStoppedAnimation(
                isFull ? AppUIConstants.textSecondary : AppUIConstants.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AmenitiesRow extends StatelessWidget {
  const _AmenitiesRow({required this.facilities});

  final List<LibraryFacility> facilities;

  @override
  Widget build(BuildContext context) {
    if (facilities.isEmpty) return const SizedBox.shrink();

    const maxVisible = 4;
    final visible = facilities.take(maxVisible).toList();
    final extra = facilities.length - visible.length;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...visible.map((f) => _AmenityChip(facility: f)),
        if (extra > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppUIConstants.divider,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '+$extra more',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppUIConstants.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}

class _AmenityChip extends StatelessWidget {
  const _AmenityChip({required this.facility});

  final LibraryFacility facility;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppUIConstants.divider,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon(facility), size: 14, color: AppUIConstants.textSecondary),
          const SizedBox(width: 5),
          Text(
            _label(facility),
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: AppUIConstants.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  static IconData _icon(LibraryFacility facility) {
    switch (facility) {
      case LibraryFacility.ac:
        return Icons.ac_unit;
      case LibraryFacility.wifi:
        return Icons.wifi;
      case LibraryFacility.powerBackup:
        return Icons.power;
      case LibraryFacility.washroom:
        return Icons.bathtub_outlined;
      case LibraryFacility.drinkingWater:
        return Icons.water_drop;
      case LibraryFacility.cctv:
        return Icons.videocam;
    }
  }

  static String _label(LibraryFacility facility) {
    switch (facility) {
      case LibraryFacility.ac:
        return 'AC';
      case LibraryFacility.wifi:
        return 'WiFi';
      case LibraryFacility.powerBackup:
        return 'Power';
      case LibraryFacility.washroom:
        return 'Attached bath';
      case LibraryFacility.drinkingWater:
        return 'RO water';
      case LibraryFacility.cctv:
        return 'CCTV';
    }
  }
}
