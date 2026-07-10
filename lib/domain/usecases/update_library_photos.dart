import 'dart:io';

import 'package:dartz/dartz.dart';

import '../core/core.dart';
import '../entities/library.dart';
import '../failures/library_failures.dart';
import '../repositories/library_repository.dart';
import '../services/storage_service.dart';

/// Use case for updating library photos.
/// Handles uploading new images and updating the library's photo list.
class UpdateLibraryPhotos
    implements UseCase<Library, UpdateLibraryPhotosParams> {
  const UpdateLibraryPhotos({
    required this.libraryRepository,
    required this.storageService,
  });

  final LibraryRepository libraryRepository;
  final StorageService storageService;

  @override
  Future<Either<Failure, Library>> call(
    UpdateLibraryPhotosParams params,
  ) async {
    try {
      // Validate photo count
      final currentPhotos = params.library.photos;
      final newPhotosCount = params.newPhotos.length;
      final totalPhotos = currentPhotos.length + newPhotosCount;

      if (totalPhotos > 5) {
        return Left(
          LibraryPhotoLimitExceededFailure(
            message:
                'Maximum 5 photos allowed. Currently have ${currentPhotos.length}, trying to add $newPhotosCount',
          ),
        );
      }

      // Upload new photos
      final uploadedUrls = <String>[];
      final storagePath = 'pg_photos/${params.library.id}/';

      for (final photoFile in params.newPhotos) {
        try {
          final url = await storageService.uploadImage(
            file: photoFile,
            path: storagePath,
          );
          uploadedUrls.add(url);
        } catch (e) {
          // If upload fails, delete already uploaded photos
          if (uploadedUrls.isNotEmpty) {
            await storageService.deleteImages(uploadedUrls);
          }
          return Left(
            LibraryPhotoUploadFailure(
              message: 'Failed to upload photo: ${e.toString()}',
            ),
          );
        }
      }

      // Update library with new photo URLs
      final updatedPhotos = [...currentPhotos, ...uploadedUrls];
      final updatedLibrary = params.library.copyWith(
        photos: updatedPhotos,
        updatedAt: DateTime.now(),
      );

      final result = await libraryRepository.updateLibrary(updatedLibrary);

      return result.fold((failure) {
        // If Firestore update fails, delete uploaded photos
        if (uploadedUrls.isNotEmpty) {
          storageService.deleteImages(uploadedUrls);
        }
        return Left(failure);
      }, (library) => Right(library));
    } catch (e) {
      return Left(
        LibraryPhotoUploadFailure(
          message: 'Unexpected error updating library photos: ${e.toString()}',
        ),
      );
    }
  }
}

/// Parameters for UpdateLibraryPhotos use case.
class UpdateLibraryPhotosParams {
  const UpdateLibraryPhotosParams({
    required this.library,
    required this.newPhotos,
  });

  final Library library;
  final List<File> newPhotos;
}
