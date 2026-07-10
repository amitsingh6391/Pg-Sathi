import 'dart:async';

import 'package:dartz/dartz.dart';

import '../core/core.dart';
import '../entities/library.dart';
import '../entities/library_stats.dart';
import '../entities/user.dart';
import '../repositories/library_repository.dart';
import '../repositories/user_repository.dart';

/// Use case for getting all libraries with completed profiles.
/// Used by students to explore available libraries.
/// Filters out libraries where owner's showMyLibraryInListing is false.
class GetAllLibraries implements UseCase<List<LibraryWithStats>, NoParams> {
  const GetAllLibraries({required this.libraryRepository, this.userRepository});

  final LibraryRepository libraryRepository;
  final UserRepository? userRepository;

  @override
  Future<Either<Failure, List<LibraryWithStats>>> call(NoParams params) async {
    final result = await libraryRepository.getAllCompletedLibraries();

    return result.fold((failure) => Left(failure), (libraries) async {
      // If userRepository is provided, filter by owner visibility settings
      if (userRepository != null && libraries.isNotEmpty) {
        // Get unique owner IDs
        final ownerIds = libraries.map((lib) => lib.ownerId).toSet().toList();

        // Fetch owner settings with timeout to avoid blocking
        try {
          final ownersResult = await userRepository!
              .getUsersByIds(ownerIds)
              .timeout(const Duration(seconds: 3), onTimeout: () {
            // If timeout, return empty map (show all libraries)
            return const Right(<String, User>{});
          });

          return ownersResult.fold((failure) {
            // On failure, show all libraries (fail open)
            return Right(_convertToLibraryWithStats(libraries));
          }, (ownersMap) {
            // Filter libraries where owner's showMyLibraryInListing is false
            final visibleLibraries = libraries.where((lib) {
              final owner = ownersMap[lib.ownerId];
              // If owner not found or setting is true, show library (default true)
              return owner == null || owner.showMyLibraryInListing;
            }).toList();

            return Right(_convertToLibraryWithStats(visibleLibraries));
          });
        } catch (e) {
          // On any error, show all libraries (fail open)
          return Right(_convertToLibraryWithStats(libraries));
        }
      }

      // No filtering if userRepository not provided (backward compatibility)
      return Right(_convertToLibraryWithStats(libraries));
    });
  }

  List<LibraryWithStats> _convertToLibraryWithStats(List<Library> libraries) {
    final librariesWithStats = libraries
        .map(
          (lib) => LibraryWithStats(
            library: lib,
            stats: LibraryStats(
              totalSeats: lib.totalSeatCapacity ?? lib.capacity,
              occupiedSeats: 0,
              reservedSeats: 0,
            ),
          ),
        )
        .toList();

    // Sort by name for consistent ordering
    librariesWithStats.sort((a, b) => a.library.name.compareTo(b.library.name));

    return librariesWithStats;
  }
}

/// Library with its current statistics.
class LibraryWithStats {
  LibraryWithStats({
    required this.library,
    required this.stats,
    this.distanceKm,
  });

  final Library library;
  final LibraryStats stats;

  /// Distance from user in km (calculated separately).
  double? distanceKm;

  /// Copy with distance.
  LibraryWithStats copyWithDistance(double? distance) {
    return LibraryWithStats(
      library: library,
      stats: stats,
      distanceKm: distance,
    );
  }
}
