import 'package:flutter/material.dart';

import '../../../domain/entities/library.dart';
import '../../../domain/usecases/get_all_libraries.dart';
import '../../core/app_ui_constants.dart';

/// Library card widget for explore screen.
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
    final availableSeats = stats.availableSeats;
    final isFull = availableSeats <= 0;



    // Determine availability badge
    final availabilityBadge = _getAvailabilityBadge(availableSeats, library.capacity);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image with badges
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: library.photos.isNotEmpty
                        ? Image.network(
                            library.photos.first,
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              height: 180,
                              color: AppUIConstants.divider,
                            ),
                          )
                        : Container(
                            height: 180,
                            width: double.infinity,
                            color: AppUIConstants.divider,
                            child: Icon(Icons.image_outlined),
                          ),
                  ),
           
                  // Availability badge
                  if (availabilityBadge != null)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      right: 8,
                      child: availabilityBadge,
                    ),
                ],
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text(
                      library.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppUIConstants.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Location and distance
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: AppUIConstants.textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${library.area ?? 'Unknown'} • ${libraryWithStats.distanceKm != null ? '${libraryWithStats.distanceKm!.toStringAsFixed(1)} km' : ''}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppUIConstants.textSecondary,
                            ),
                          ),
                        ),
                       
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Amenities
                    _AmenitiesRow(facilities: library.enabledFacilities),
                    const SizedBox(height: 12),
                    // Action button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isFull ? null : onTap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFull ? AppUIConstants.disabled : AppUIConstants.primary,
                          foregroundColor: isFull ? AppUIConstants.textSecondary : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(
                          isFull ? 'Waitlist' : 'Book Now',
                          style: const TextStyle(fontWeight: FontWeight.w600),
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

  Widget? _getAvailabilityBadge(int available, int total) {
    if (available <= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppUIConstants.textSecondary.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'FULL FOR TODAY',
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    // Mock slot names for availability
    final slotName = available > 5 ? 'MORNING SLOT' : 'EVENING SLOT';
    final color = available > 5 ? AppUIConstants.success : AppUIConstants.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$available SEATS LEFT IN $slotName',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AmenitiesRow extends StatelessWidget {
  const _AmenitiesRow({required this.facilities});

  final List<LibraryFacility> facilities;

  @override
  Widget build(BuildContext context) {
    if (facilities.isEmpty) return const SizedBox.shrink();

    return Row(
      children: facilities.take(6).map((facility) {
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppUIConstants.divider,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getFacilityIcon(facility),
              size: 16,
              color: AppUIConstants.textSecondary,
            ),
          ),
        );
      }).toList(),
    );
  }

  IconData _getFacilityIcon(LibraryFacility facility) {
    switch (facility) {
      case LibraryFacility.ac:
        return Icons.ac_unit;
      case LibraryFacility.wifi:
        return Icons.wifi;
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
}
