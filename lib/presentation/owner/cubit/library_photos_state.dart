import 'package:equatable/equatable.dart';

import '../../../domain/entities/library.dart';

/// State for library photos cubit.
class LibraryPhotosState extends Equatable {
  const LibraryPhotosState({
    this.status = LibraryPhotosStatus.initial,
    this.library,
    this.errorMessage,
  });

  final LibraryPhotosStatus status;
  final Library? library;
  final String? errorMessage;

  bool get isUploading => status == LibraryPhotosStatus.uploading;
  bool get isDeleting => status == LibraryPhotosStatus.deleting;
  bool get isSuccess => status == LibraryPhotosStatus.success;
  bool get isError => status == LibraryPhotosStatus.error;

  LibraryPhotosState copyWith({
    LibraryPhotosStatus? status,
    Library? library,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LibraryPhotosState(
      status: status ?? this.status,
      library: library ?? this.library,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, library, errorMessage];
}

/// Status for library photos operations.
enum LibraryPhotosStatus { initial, uploading, deleting, success, error }
