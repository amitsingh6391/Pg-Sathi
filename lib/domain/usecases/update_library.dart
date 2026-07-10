import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../core/core.dart';
import '../entities/library.dart';
import '../failures/library_failures.dart';
import '../repositories/library_repository.dart';
import '../repositories/seat_repository.dart';

/// Use case for updating a library.
/// Also syncs seat count when capacity changes.
class UpdateLibrary implements UseCase<Library, UpdateLibraryParams> {
  const UpdateLibrary({
    required this.libraryRepository,
    required this.seatRepository,
  });

  final LibraryRepository libraryRepository;
  final SeatRepository seatRepository;

  @override
  Future<Either<Failure, Library>> call(UpdateLibraryParams params) async {
    final library = params.library;

    // Validate using entity validation
    final validation = library.validate();
    if (!validation.isValid) {
      return Left(InvalidLibraryDataFailure(message: validation.errors.first));
    }

    // Get existing library to check capacity change
    final existingResult = await libraryRepository.getLibraryByOwnerId(
      library.ownerId,
    );

    return existingResult.fold((failure) => Left(failure), (
      existingLibrary,
    ) async {
      if (existingLibrary == null) {
        return const Left(
          LibraryNotFoundFailure(message: 'No library found to update'),
        );
      }

      // Update the library with new data
      final libraryToUpdate = library.copyWith(
        updatedAt: DateTime.now(),
        isProfileComplete: library.shouldBeProfileComplete,
      );

      // Update the library
      final updateResult = await libraryRepository.updateLibrary(
        libraryToUpdate,
      );

      return updateResult.fold((failure) => Left(failure), (
        savedLibrary,
      ) async {
        // Sync seat count if capacity changed
        if (existingLibrary.capacity != library.capacity) {
          await _syncSeats(savedLibrary.id, library.capacity);
        }
        return Right(savedLibrary);
      });
    });
  }

  Future<void> _syncSeats(String libraryId, int newCapacity) async {
    // Get current seats
    final seatsResult = await seatRepository.getSeatsByLibraryId(libraryId);

    seatsResult.fold(
      (failure) {
        // If we can't get seats, try to create them
        seatRepository.createSeats(libraryId: libraryId, count: newCapacity);
      },
      (currentSeats) async {
        final currentCount = currentSeats.length;

        if (currentCount == 0) {
          // No seats exist, create them
          await seatRepository.createSeats(
            libraryId: libraryId,
            count: newCapacity,
          );
        } else if (newCapacity > currentCount) {
          // Need to add more seats
          final seatsToAdd = newCapacity - currentCount;
          await seatRepository.createSeats(
            libraryId: libraryId,
            count: seatsToAdd,
          );
        } else if (newCapacity < currentCount) {
          // Need to remove seats (keep first N)
          await seatRepository.deleteSeatsForLibrary(
            libraryId,
            keepCount: newCapacity,
          );
        }
      },
    );
  }
}

/// Parameters for UpdateLibrary use case.
class UpdateLibraryParams extends Equatable {
  const UpdateLibraryParams({required this.library});

  final Library library;

  @override
  List<Object?> get props => [library];
}
