import 'dart:math' as math;

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/core/usecase.dart';
import '../../../domain/entities/library.dart';
import '../../../domain/services/location_service.dart';
import '../../../domain/usecases/get_all_libraries.dart';
import 'explore_libraries_state.dart';

/// Cubit for exploring available libraries.
/// Read-only: no booking or payment from this flow.
class ExploreLibrariesCubit extends Cubit<ExploreLibrariesState> {
  ExploreLibrariesCubit({
    required this.getAllLibraries,
    this.locationService,
  }) : super(const ExploreLibrariesState());

  final GetAllLibraries getAllLibraries;
  final LocationService? locationService;

  /// Loads all available libraries.
  /// Optimized: Loads libraries first, then fetches location in background.
  Future<void> loadLibraries() async {
    emit(
      state.copyWith(
        status: ExploreLibrariesStatus.loading,
        clearFailure: true,
      ),
    );

    // Start location fetch in background (non-blocking)
    if (locationService != null && 
        state.userLatitude == null && 
        state.userLongitude == null) {
      _fetchUserLocation(); // Don't await - run in background
    }

    // Load libraries immediately (don't wait for location)
    final result = await getAllLibraries(const NoParams());

    result.fold(
      (failure) => emit(
        state.copyWith(status: ExploreLibrariesStatus.error, failure: failure),
      ),
      (libraries) {
        // Calculate distances if user location is already available
        final librariesWithDistance = _calculateDistances(libraries, shouldSort: false);

        emit(
          state.copyWith(
            status: ExploreLibrariesStatus.loaded,
            libraries: librariesWithDistance,
          ),
        );
      },
    );
  }

  /// Fetches user's current location in background.
  /// Updates distances when location is available.
  Future<void> _fetchUserLocation() async {
    if (locationService == null) return;

    try {
      final locationResult = await locationService!.getCurrentLocation();

      locationResult.fold(
        (failure) {
          // Location permission denied or service disabled - continue without location
          setLocationPermission(false);
        },
        (userLocation) {
          // Update location and recalculate distances for existing libraries
          updateUserLocation(userLocation.latitude, userLocation.longitude);
        },
      );
    } catch (e) {
      // Silently fail - location is optional
      setLocationPermission(false);
    }
  }

  /// Refreshes the library list.
  Future<void> refresh() => loadLibraries();

  /// Updates search query.
  void updateSearch(String query) {
    emit(state.copyWith(searchQuery: query));
  }

  /// Toggles a facility filter.
  void toggleFilter(LibraryFacility facility) {
    final filters = Set<LibraryFacility>.from(state.selectedFilters);
    if (filters.contains(facility)) {
      filters.remove(facility);
    } else {
      filters.add(facility);
    }
    emit(state.copyWith(selectedFilters: filters));
  }

  /// Updates sort option.
  void updateSort(SortOption sortBy) {
    emit(state.copyWith(sortBy: sortBy));
  }

  /// Updates user location for distance calculation.
  void updateUserLocation(double latitude, double longitude) {
    final currentLibraries = state.libraries;
    
    emit(
      state.copyWith(
        userLatitude: latitude,
        userLongitude: longitude,
        hasLocationPermission: true,
      ),
    );

    // Recalculate distances with new location
    if (currentLibraries.isNotEmpty) {
      final librariesWithDistance = _calculateDistances(currentLibraries, shouldSort: false);
      emit(state.copyWith(libraries: librariesWithDistance));
    }
  }

  /// Sets location permission status.
  void setLocationPermission(bool granted) {
    emit(state.copyWith(hasLocationPermission: granted));
  }

  /// Calculates distances for each library from user location.
  List<LibraryWithStats> _calculateDistances(
    List<LibraryWithStats> libraries, {
    bool shouldSort = false,
  }) {
    if (state.userLatitude == null || state.userLongitude == null) {
      return libraries;
    }

    final result = libraries.map((lib) {
      if (lib.library.latitude != null && lib.library.longitude != null) {
        final distance = _haversineDistance(
          state.userLatitude!,
          state.userLongitude!,
          lib.library.latitude!,
          lib.library.longitude!,
        );
        return lib.copyWithDistance(distance);
      }
      return lib;
    }).toList();

    // Only sort if explicitly requested (not when loading, sorting happens in filteredLibraries)
    if (shouldSort) {
      result.sort((a, b) {
        if (a.distanceKm == null && b.distanceKm == null) return 0;
        if (a.distanceKm == null) return 1;
        if (b.distanceKm == null) return -1;
        return a.distanceKm!.compareTo(b.distanceKm!);
      });
    }

    return result;
  }

  /// Calculates distance between two coordinates using Haversine formula.
  double _haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371.0; // km

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * math.pi / 180;
}
