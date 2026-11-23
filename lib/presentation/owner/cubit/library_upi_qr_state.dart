import 'package:equatable/equatable.dart';

import '../../../domain/entities/library.dart';

/// State for the library UPI QR code cubit.
class LibraryUpiQrState extends Equatable {
  const LibraryUpiQrState({
    this.status = LibraryUpiQrStatus.initial,
    this.library,
    this.errorMessage,
  });

  final LibraryUpiQrStatus status;
  final Library? library;
  final String? errorMessage;

  bool get isUploading => status == LibraryUpiQrStatus.uploading;
  bool get isRemoving => status == LibraryUpiQrStatus.removing;
  bool get isSuccess => status == LibraryUpiQrStatus.success;
  bool get isError => status == LibraryUpiQrStatus.error;

  LibraryUpiQrState copyWith({
    LibraryUpiQrStatus? status,
    Library? library,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LibraryUpiQrState(
      status: status ?? this.status,
      library: library ?? this.library,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, library, errorMessage];
}

/// Status for library UPI QR operations.
enum LibraryUpiQrStatus { initial, uploading, removing, success, error }
