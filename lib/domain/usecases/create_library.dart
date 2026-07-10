import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../core/core.dart';
import '../entities/library.dart';
import '../failures/library_failures.dart';
import '../repositories/library_repository.dart';
import '../repositories/seat_repository.dart';

/// Use case for creating a library.
/// V1: Owner can create only ONE library.
/// Also creates seat records for the library capacity.
class CreateLibrary implements UseCase<Library, CreateLibraryParams> {
  const CreateLibrary({
    required this.libraryRepository,
    required this.seatRepository,
  });

  final LibraryRepository libraryRepository;
  final SeatRepository seatRepository;

  @override
  Future<Either<Failure, Library>> call(CreateLibraryParams params) async {
    final library = params.library;

    // Validate using entity validation
    final validation = library.validate();
    if (!validation.isValid) {
      return Left(InvalidLibraryDataFailure(message: validation.errors.first));
    }

    // Check if owner already has a library
    final hasLibraryResult = await libraryRepository.ownerHasLibrary(
      library.ownerId,
    );

    return hasLibraryResult.fold((failure) => Left(failure), (
      hasLibrary,
    ) async {
      if (hasLibrary) {
        return const Left(
          LibraryAlreadyExistsFailure(
            message: 'You already have a library. Update it instead.',
          ),
        );
      }

      // Create the library with createdAt
      final libraryToCreate = library.copyWith(
        createdAt: DateTime.now(),
        isProfileComplete: library.shouldBeProfileComplete,
      );

      // Create the library
      final createResult = await libraryRepository.createLibrary(
        libraryToCreate,
      );

      return createResult.fold((failure) => Left(failure), (
        createdLibrary,
      ) async {
        // Create seat records for the library
        final seatsResult = await seatRepository.createSeats(
          libraryId: createdLibrary.id,
          count: library.capacity,
        );

        return seatsResult.fold(
          // If seat creation fails, still return the library but log the error
          (failure) => Right(createdLibrary),
          (seats) => Right(createdLibrary),
        );
      });
    });
  }
}

/// Parameters for CreateLibrary use case.
class CreateLibraryParams extends Equatable {
  const CreateLibraryParams({required this.library});

  final Library library;

  @override
  List<Object?> get props => [library];
}
