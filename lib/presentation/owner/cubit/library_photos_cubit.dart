import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/library.dart';
import '../../../domain/usecases/delete_library_photo.dart';
import '../../../domain/usecases/update_library_photos.dart';
import 'library_photos_state.dart';

/// Cubit for managing library photos upload and deletion.
class LibraryPhotosCubit extends Cubit<LibraryPhotosState> {
  LibraryPhotosCubit({
    required this.updateLibraryPhotos,
    required this.deleteLibraryPhoto,
  }) : super(const LibraryPhotosState());

  final UpdateLibraryPhotos updateLibraryPhotos;
  final DeleteLibraryPhoto deleteLibraryPhoto;

  /// Uploads new photos to the library.
  Future<void> uploadPhotos({
    required Library library,
    required List<File> photoFiles,
  }) async {
    if (photoFiles.isEmpty) return;

    emit(state.copyWith(status: LibraryPhotosStatus.uploading));

    final result = await updateLibraryPhotos(
      UpdateLibraryPhotosParams(library: library, newPhotos: photoFiles),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: LibraryPhotosStatus.error,
          errorMessage: failure.message,
        ),
      ),
      (updatedLibrary) => emit(
        state.copyWith(
          status: LibraryPhotosStatus.success,
          library: updatedLibrary,
        ),
      ),
    );
  }

  /// Deletes a photo from the library.
  Future<void> deletePhoto({
    required Library library,
    required String photoUrl,
  }) async {
    emit(state.copyWith(status: LibraryPhotosStatus.deleting));

    final result = await deleteLibraryPhoto(
      DeleteLibraryPhotoParams(library: library, photoUrl: photoUrl),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: LibraryPhotosStatus.error,
          errorMessage: failure.message,
        ),
      ),
      (updatedLibrary) => emit(
        state.copyWith(
          status: LibraryPhotosStatus.success,
          library: updatedLibrary,
        ),
      ),
    );
  }

  /// Resets the state to initial.
  void reset() {
    emit(const LibraryPhotosState());
  }
}
