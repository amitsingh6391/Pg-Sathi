import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/library.dart';
import '../../../domain/usecases/remove_library_upi_qr.dart';
import '../../../domain/usecases/update_library_upi_qr.dart';
import 'library_upi_qr_state.dart';

/// Cubit for managing a PG's UPI QR code image (upload / remove).
class LibraryUpiQrCubit extends Cubit<LibraryUpiQrState> {
  LibraryUpiQrCubit({
    required this.updateLibraryUpiQr,
    required this.removeLibraryUpiQr,
  }) : super(const LibraryUpiQrState());

  final UpdateLibraryUpiQr updateLibraryUpiQr;
  final RemoveLibraryUpiQr removeLibraryUpiQr;

  /// Uploads (or replaces) the UPI QR code image for [library].
  /// Pass [persist] false while the PG is not saved yet (onboarding).
  Future<void> uploadQr({
    required Library library,
    required File qrImage,
    bool persist = true,
  }) async {
    emit(
      state.copyWith(status: LibraryUpiQrStatus.uploading, clearError: true),
    );

    final result = await updateLibraryUpiQr(
      UpdateLibraryUpiQrParams(
        library: library,
        qrImage: qrImage,
        persist: persist,
      ),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: LibraryUpiQrStatus.error,
          errorMessage: failure.message,
        ),
      ),
      (updatedLibrary) => emit(
        state.copyWith(
          status: LibraryUpiQrStatus.success,
          library: updatedLibrary,
        ),
      ),
    );
  }

  /// Removes the UPI QR code image from [library].
  /// Pass [persist] false while the PG is not saved yet (onboarding).
  Future<void> removeQr({required Library library, bool persist = true}) async {
    emit(state.copyWith(status: LibraryUpiQrStatus.removing, clearError: true));

    final result = await removeLibraryUpiQr(
      RemoveLibraryUpiQrParams(library: library, persist: persist),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: LibraryUpiQrStatus.error,
          errorMessage: failure.message,
        ),
      ),
      (updatedLibrary) => emit(
        state.copyWith(
          status: LibraryUpiQrStatus.success,
          library: updatedLibrary,
        ),
      ),
    );
  }

  /// Resets the state to initial.
  void reset() {
    emit(const LibraryUpiQrState());
  }
}
