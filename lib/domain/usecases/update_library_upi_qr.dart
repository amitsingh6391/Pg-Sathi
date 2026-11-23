import 'dart:io';

import 'package:dartz/dartz.dart';

import '../core/core.dart';
import '../entities/library.dart';
import '../failures/library_failures.dart';
import '../repositories/library_repository.dart';
import '../services/storage_service.dart';

/// Use case for uploading (or replacing) a PG's UPI QR code image.
/// Uploads the new image, updates the PG, then best-effort deletes the
/// previous QR image so orphaned files are not left in storage.
///
/// When [UpdateLibraryUpiQrParams.persist] is false (first-time onboarding,
/// where the PG document is only created at the final step) the image is
/// uploaded and the updated entity returned without a Firestore write; the
/// URL is saved together with the rest of the profile.
class UpdateLibraryUpiQr implements UseCase<Library, UpdateLibraryUpiQrParams> {
  const UpdateLibraryUpiQr({
    required this.libraryRepository,
    required this.storageService,
  });

  final LibraryRepository libraryRepository;
  final StorageService storageService;

  @override
  Future<Either<Failure, Library>> call(UpdateLibraryUpiQrParams params) async {
    try {
      final previousQrUrl = params.library.ownerUpiQrUrl;
      final storagePath = 'library_upi_qr/${params.library.id}/';

      final String uploadedUrl;
      try {
        uploadedUrl = await storageService.uploadImage(
          file: params.qrImage,
          path: storagePath,
        );
      } catch (e) {
        return Left(
          LibraryUpiQrUploadFailure(
            message: 'Failed to upload UPI QR code: ${e.toString()}',
          ),
        );
      }

      final updatedLibrary = params.library.copyWith(
        ownerUpiQrUrl: uploadedUrl,
        updatedAt: DateTime.now(),
      );

      void cleanupPrevious() {
        if (previousQrUrl != null && previousQrUrl.isNotEmpty) {
          storageService.deleteImage(previousQrUrl).ignore();
        }
      }

      if (!params.persist) {
        cleanupPrevious();
        return Right(updatedLibrary);
      }

      final result = await libraryRepository.updateLibrary(updatedLibrary);

      return await result.fold(
        (failure) {
          // Roll back the just-uploaded image if the Firestore write failed.
          storageService.deleteImage(uploadedUrl).ignore();
          return Left(failure);
        },
        (library) {
          cleanupPrevious();
          return Right(library);
        },
      );
    } catch (e) {
      return Left(
        LibraryUpiQrUploadFailure(
          message: 'Unexpected error updating UPI QR code: ${e.toString()}',
        ),
      );
    }
  }
}

/// Parameters for [UpdateLibraryUpiQr] use case.
class UpdateLibraryUpiQrParams {
  const UpdateLibraryUpiQrParams({
    required this.library,
    required this.qrImage,
    this.persist = true,
  });

  final Library library;
  final File qrImage;

  /// Whether to write the new URL to Firestore immediately.
  final bool persist;
}
