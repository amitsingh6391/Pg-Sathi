import 'package:dartz/dartz.dart';

import '../core/core.dart';
import '../entities/library.dart';
import '../failures/library_failures.dart';
import '../repositories/library_repository.dart';
import '../services/storage_service.dart';

/// Use case for removing a PG's UPI QR code image.
/// Clears the QR URL on the PG first, then best-effort deletes the image
/// from storage (the PG update is authoritative).
///
/// With [RemoveLibraryUpiQrParams.persist] false (first-time onboarding) only
/// the entity is updated; nothing is written to Firestore yet.
class RemoveLibraryUpiQr implements UseCase<Library, RemoveLibraryUpiQrParams> {
  const RemoveLibraryUpiQr({
    required this.libraryRepository,
    required this.storageService,
  });

  final LibraryRepository libraryRepository;
  final StorageService storageService;

  @override
  Future<Either<Failure, Library>> call(RemoveLibraryUpiQrParams params) async {
    try {
      final qrUrl = params.library.ownerUpiQrUrl;
      if (qrUrl == null || qrUrl.isEmpty) {
        return Right(params.library);
      }

      final updatedLibrary = params.library.copyWith(
        ownerUpiQrUrl: null,
        updatedAt: DateTime.now(),
      );

      if (!params.persist) {
        storageService.deleteImage(qrUrl).ignore();
        return Right(updatedLibrary);
      }

      final result = await libraryRepository.updateLibrary(updatedLibrary);

      return await result.fold((failure) => Left(failure), (library) {
        // Best-effort storage cleanup - the QR is already removed from the PG,
        // so a storage failure should not fail the operation.
        storageService.deleteImage(qrUrl).ignore();
        return Right(library);
      });
    } catch (e) {
      return Left(
        LibraryUpiQrDeleteFailure(
          message: 'Unexpected error removing UPI QR code: ${e.toString()}',
        ),
      );
    }
  }
}

/// Parameters for [RemoveLibraryUpiQr] use case.
class RemoveLibraryUpiQrParams {
  const RemoveLibraryUpiQrParams({required this.library, this.persist = true});

  final Library library;

  /// Whether to write the change to Firestore immediately.
  final bool persist;
}
