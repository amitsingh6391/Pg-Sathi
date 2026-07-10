import 'package:flutter/material.dart';

import '../../../core/utils/map_launcher.dart';
import '../../../domain/entities/library.dart';
import '../../core/app_ui_constants.dart';

/// Read-only preview of the library listing as seen by students.
/// Shows photos, address, facilities, and seat availability.
class LibraryPreviewScreen extends StatelessWidget {
  const LibraryPreviewScreen({
    super.key,
    required this.library,
    required this.availableSeats,
    required this.totalSeats,
  });

  final Library library;
  final int availableSeats;
  final int totalSeats;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUIConstants.background,
      body: CustomScrollView(
        slivers: [
          _PreviewAppBar(library: library),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Photos Gallery
                if (library.photos.isNotEmpty)
                  _PhotosGallery(photos: library.photos),

                // Library Info Card
                _LibraryInfoCard(library: library),

                // Seat Availability
                _SeatAvailabilityCard(
                  available: availableSeats,
                  total: totalSeats,
                ),

                // Facilities
                if (library.enabledFacilities.isNotEmpty)
                  _FacilitiesCard(facilities: library.enabledFacilities),

                // Address Card
                _AddressCard(library: library),

                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// App Bar
// =============================================================================

class _PreviewAppBar extends StatelessWidget {
  const _PreviewAppBar({required this.library});

  final Library library;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: library.photos.isEmpty ? 120 : 200,
      pinned: true,
      backgroundColor: AppUIConstants.primary,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppUIConstants.accent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'PREVIEW',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              library.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white,),
            ),
          ],
        ),
        titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
        background: library.photos.isNotEmpty
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    library.photos.first,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        Container(color: AppUIConstants.primary),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : null,
      ),
    );
  }
}

// =============================================================================
// Photos Gallery
// =============================================================================

class _PhotosGallery extends StatelessWidget {
  const _PhotosGallery({required this.photos});

  final List<String> photos;

  @override
  Widget build(BuildContext context) {
    if (photos.length <= 1) return const SizedBox.shrink();

    return Container(
      height: 80,
      margin: const EdgeInsets.only(top: AppUIConstants.spacingLg),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppUIConstants.spacingLg,
        ),
        itemCount: photos.length,
        itemBuilder: (context, index) {
          return Container(
            width: 80,
            margin: const EdgeInsets.only(right: AppUIConstants.spacingSm),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
              border: Border.all(color: AppUIConstants.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.network(
              photos[index],
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                color: AppUIConstants.divider,
                child: Icon(
                  Icons.image_not_supported_outlined,
                  color: AppUIConstants.textTertiary,
                  size: 24,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// =============================================================================
// Library Info Card
// =============================================================================

class _LibraryInfoCard extends StatelessWidget {
  const _LibraryInfoCard({required this.library});

  final Library library;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppUIConstants.spacingLg),
      padding: const EdgeInsets.all(AppUIConstants.spacingLg),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        boxShadow: [AppUIConstants.shadowSm],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.local_library_outlined,
                color: AppUIConstants.primary,
                size: 20,
              ),
              const SizedBox(width: AppUIConstants.spacingSm),
              Text(library.name, style: AppUIConstants.headingMd),
            ],
          ),
          if (library.area != null && library.area!.isNotEmpty) ...[
            const SizedBox(height: AppUIConstants.spacingSm),
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: AppUIConstants.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(library.area!, style: AppUIConstants.bodySm),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// Seat Availability Card
// =============================================================================

class _SeatAvailabilityCard extends StatelessWidget {
  const _SeatAvailabilityCard({required this.available, required this.total});

  final int available;
  final int total;

  @override
  Widget build(BuildContext context) {
    final percentage = total > 0 ? (available / total) : 0.0;
    final availabilityColor = percentage > 0.5
        ? AppUIConstants.success
        : percentage > 0.2
        ? AppUIConstants.warning
        : AppUIConstants.error;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppUIConstants.spacingLg),
      padding: const EdgeInsets.all(AppUIConstants.spacingLg),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        boxShadow: [AppUIConstants.shadowSm],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.event_seat_outlined,
                color: AppUIConstants.primary,
                size: 20,
              ),
              const SizedBox(width: AppUIConstants.spacingSm),
              Text('Seat Availability', style: AppUIConstants.headingSm),
            ],
          ),
          const SizedBox(height: AppUIConstants.spacingMd),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$available seats available',
                      style: AppUIConstants.headingMd.copyWith(
                        color: availabilityColor,
                      ),
                    ),
                    Text(
                      'out of $total total seats',
                      style: AppUIConstants.bodySm,
                    ),
                  ],
                ),
              ),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: availabilityColor.withValues(alpha: 0.1),
                ),
                child: Center(
                  child: Text(
                    '${(percentage * 100).round()}%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: availabilityColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppUIConstants.spacingMd),
          LinearProgressIndicator(
            value: percentage,
            backgroundColor: AppUIConstants.divider,
            valueColor: AlwaysStoppedAnimation(availabilityColor),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Facilities Card
// =============================================================================

class _FacilitiesCard extends StatelessWidget {
  const _FacilitiesCard({required this.facilities});

  final List<LibraryFacility> facilities;

  IconData _getIcon(LibraryFacility facility) {
    switch (facility) {
      case LibraryFacility.wifi:
        return Icons.wifi;
      case LibraryFacility.ac:
        return Icons.ac_unit;
      case LibraryFacility.powerBackup:
        return Icons.power;
      case LibraryFacility.washroom:
        return Icons.wc;
      case LibraryFacility.drinkingWater:
        return Icons.water_drop;
      case LibraryFacility.cctv:
        return Icons.videocam;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppUIConstants.spacingLg),
      padding: const EdgeInsets.all(AppUIConstants.spacingLg),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        boxShadow: [AppUIConstants.shadowSm],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: AppUIConstants.success,
                size: 20,
              ),
              const SizedBox(width: AppUIConstants.spacingSm),
              Text('Facilities', style: AppUIConstants.headingSm),
            ],
          ),
          const SizedBox(height: AppUIConstants.spacingMd),
          Wrap(
            spacing: AppUIConstants.spacingSm,
            runSpacing: AppUIConstants.spacingSm,
            children: facilities.map((facility) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppUIConstants.spacingMd,
                  vertical: AppUIConstants.spacingSm,
                ),
                decoration: BoxDecoration(
                  color: AppUIConstants.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(
                    AppUIConstants.radiusFull,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getIcon(facility),
                      size: 16,
                      color: AppUIConstants.success,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      facility.displayName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppUIConstants.success,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Address Card
// =============================================================================

Future<void> _openMaps(BuildContext context, Library library) async {
  final lat = library.latitude!;
  final lng = library.longitude!;
  try {
    final opened = await launchMapsAt(
      latitude: lat,
      longitude: lng,
      label: library.fullAddress,
    );
    if (!context.mounted) return;
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Maps')),
      );
    }
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open Maps')),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.library});

  final Library library;

  @override
  Widget build(BuildContext context) {
    if (library.fullAddress == null || library.fullAddress!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppUIConstants.spacingLg),
      padding: const EdgeInsets.all(AppUIConstants.spacingLg),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        boxShadow: [AppUIConstants.shadowSm],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                color: AppUIConstants.primary,
                size: 20,
              ),
              const SizedBox(width: AppUIConstants.spacingSm),
              Text('Address', style: AppUIConstants.headingSm),
            ],
          ),
          const SizedBox(height: AppUIConstants.spacingMd),
          Text(library.fullAddress!, style: AppUIConstants.bodyMd),
          if (library.latitude != null && library.longitude != null) ...[
            const SizedBox(height: AppUIConstants.spacingMd),
            Material(
              color: AppUIConstants.background,
              borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
              child: InkWell(
                onTap: () => _openMaps(context, library),
                borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppUIConstants.spacingMd,
                    vertical: AppUIConstants.spacingLg,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
                    border: Border.all(color: AppUIConstants.border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.map_outlined,
                        color: AppUIConstants.primary,
                        size: 28,
                      ),
                      const SizedBox(width: AppUIConstants.spacingMd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Open in Maps',
                              style: AppUIConstants.bodyMd.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Apple Maps or Google Maps',
                              style: AppUIConstants.bodySm.copyWith(
                                color: AppUIConstants.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.open_in_new,
                        size: 18,
                        color: AppUIConstants.textTertiary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
