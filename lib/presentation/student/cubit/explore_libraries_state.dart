import 'package:equatable/equatable.dart';

import '../../../domain/core/failure.dart';
import '../../../domain/entities/library.dart';
import '../../../domain/usecases/get_all_libraries.dart';

/// State for explore libraries cubit.
class ExploreLibrariesState extends Equatable {
  const ExploreLibrariesState({
    this.status = ExploreLibrariesStatus.initial,
    this.libraries = const [],
    this.failure,
    this.userLatitude,
    this.userLongitude,
    this.hasLocationPermission = false,
    this.searchQuery = '',
    this.selectedFilters = const {},
    this.sortBy = SortOption.distance,
  });

  final ExploreLibrariesStatus status;
  final List<LibraryWithStats> libraries;
  final Failure? failure;
  final double? userLatitude;
  final double? userLongitude;
  final bool hasLocationPermission;
  final String searchQuery;
  final Set<LibraryFacility> selectedFilters;
  final SortOption sortBy;

  bool get isLoading => status == ExploreLibrariesStatus.loading;
  bool get isLoaded => status == ExploreLibrariesStatus.loaded;
  bool get isError => status == ExploreLibrariesStatus.error;
  bool get isEmpty => filteredLibraries.isEmpty && isLoaded;

  /// Filtered and sorted libraries based on search and filters.
  List<LibraryWithStats> get filteredLibraries {
    // Start with a copy of the libraries list
    var result = List<LibraryWithStats>.from(libraries);

    // Apply search filter
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      result = result.where((lib) {
        final name = lib.library.name.toLowerCase();
        final area = lib.library.area?.toLowerCase() ?? '';
        return name.contains(query) || area.contains(query);
      }).toList();
    }

    // Apply facility filters
    if (selectedFilters.isNotEmpty) {
      result = result.where((lib) {
        final facilities = lib.library.enabledFacilities.toSet();
        return selectedFilters.every((filter) => facilities.contains(filter));
      }).toList();
    }

    // Apply sorting - create a new sorted list
    final sortedResult = List<LibraryWithStats>.from(result);
    switch (sortBy) {
      case SortOption.distance:
        sortedResult.sort((a, b) {
          if (a.distanceKm == null && b.distanceKm == null) return 0;
          if (a.distanceKm == null) return 1;
          if (b.distanceKm == null) return -1;
          return a.distanceKm!.compareTo(b.distanceKm!);
        });
        break;
      case SortOption.name:
        sortedResult.sort((a, b) => a.library.name.compareTo(b.library.name));
        break;
    }

    return sortedResult;
  }

  ExploreLibrariesState copyWith({
    ExploreLibrariesStatus? status,
    List<LibraryWithStats>? libraries,
    Failure? failure,
    double? userLatitude,
    double? userLongitude,
    bool? hasLocationPermission,
    String? searchQuery,
    Set<LibraryFacility>? selectedFilters,
    SortOption? sortBy,
    bool clearFailure = false,
  }) {
    return ExploreLibrariesState(
      status: status ?? this.status,
      libraries: libraries ?? this.libraries,
      failure: clearFailure ? null : (failure ?? this.failure),
      userLatitude: userLatitude ?? this.userLatitude,
      userLongitude: userLongitude ?? this.userLongitude,
      hasLocationPermission:
          hasLocationPermission ?? this.hasLocationPermission,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedFilters: selectedFilters ?? this.selectedFilters,
      sortBy: sortBy ?? this.sortBy,
    );
  }

  @override
  List<Object?> get props => [
    status,
    libraries,
    failure,
    userLatitude,
    userLongitude,
    hasLocationPermission,
    searchQuery,
    selectedFilters,
    sortBy,
  ];
}

/// Status for explore libraries.
enum ExploreLibrariesStatus { initial, loading, loaded, error }

/// Sort options for libraries.
enum SortOption { distance, name }
