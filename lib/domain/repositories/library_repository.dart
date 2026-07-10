import 'package:dartz/dartz.dart';

import '../core/failure.dart';
import '../entities/library.dart';

/// Repository interface for Library aggregate.
/// V1: One library per owner.
abstract class LibraryRepository {
  /// Creates a new library.
  Future<Either<Failure, Library>> createLibrary(Library library);

  /// Updates an existing library.
  Future<Either<Failure, Library>> updateLibrary(Library library);

  /// Gets a library by its ID.
  Future<Either<Failure, Library?>> getLibraryById(String libraryId);

  /// Gets the library owned by the given owner.
  /// Returns null if owner has no library.
  Future<Either<Failure, Library?>> getLibraryByOwnerId(String ownerId);

  /// Checks if owner already has a library.
  Future<Either<Failure, bool>> ownerHasLibrary(String ownerId);

  /// Gets all libraries with completed profiles.
  /// Used by students to explore available libraries.
  Future<Either<Failure, List<Library>>> getAllCompletedLibraries();

  /// Gets all libraries (regardless of profile completion).
  /// Used by admin screens to build owner-to-library mappings in a single read
  /// instead of N individual getLibraryByOwnerId calls.
  Future<Either<Failure, List<Library>>> getAllLibraries();
}
