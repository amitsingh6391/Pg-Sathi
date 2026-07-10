import 'package:dartz/dartz.dart';

import '../core/core.dart';
import '../entities/library.dart';
import '../failures/library_failures.dart';
import '../repositories/library_repository.dart';
import '../services/storage_service.dart';

/// Use case for deleting a library photo.
/// Removes the photo from storage and updates the library.
class DeleteLibraryPhoto implements UseCase<Library, DeleteLibraryPhotoParams> {
  const DeleteLibraryPhoto({
    required this.libraryRepository,
    required this.storageService,
  });

  final LibraryRepository libraryRepository;
  final StorageService storageService;

  @override
  Future<Either<Failure, Library>> call(DeleteLibraryPhotoParams params) async {
    try {
      // Remove photo URL from library
      final currentPhotos = params.library.photos;
      if (!currentPhotos.contains(params.photoUrl)) {
        return Left(
          const LibraryPhotoDeleteFailure(
            message: 'Photo not found in library',
          ),
        );
      }

      final updatedPhotos = currentPhotos
          .where((url) => url != params.photoUrl)
          .toList();
      final updatedLibrary = params.library.copyWith(
        photos: updatedPhotos,
        updatedAt: DateTime.now(),
      );

      // Update library first (optimistic update)
      final updateResult = await libraryRepository.updateLibrary(
        updatedLibrary,
      );

      return updateResult.fold((failure) => Left(failure), (library) async {
        // Delete from storage (best effort - don't fail if storage delete fails)
        try {
          await storageService.deleteImage(params.photoUrl);
        } catch (e) {
          // Log but don't fail - photo already removed from library
          // In production, you might want to log this to Crashlytics
        }
        return Right(library);
      });
    } catch (e) {
      return Left(
        LibraryPhotoDeleteFailure(
          message: 'Unexpected error deleting library photo: ${e.toString()}',
        ),
      );
    }
  }
}

/// Parameters for DeleteLibraryPhoto use case.
class DeleteLibraryPhotoParams {
  const DeleteLibraryPhotoParams({
    required this.library,
    required this.photoUrl,
  });

  final Library library;
  final String photoUrl;
}
