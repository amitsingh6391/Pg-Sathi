import 'package:equatable/equatable.dart';

import '../../../domain/core/failure.dart';
import '../../../domain/entities/library.dart';
import '../../../domain/entities/library_stats.dart';

/// State for OwnerLibraryBloc.
final class OwnerLibraryState extends Equatable {
  const OwnerLibraryState({
    this.status = OwnerLibraryStatus.initial,
    this.library,
    this.stats = const LibraryStats.empty(),
    this.failure,
    this.formStatus = FormStatus.idle,
  });

  final OwnerLibraryStatus status;
  final Library? library;
  final LibraryStats stats;
  final Failure? failure;
  final FormStatus formStatus;

  /// Whether owner has a library.
  bool get hasLibrary => library != null;

  /// Whether data is loading.
  bool get isLoading => status == OwnerLibraryStatus.loading;

  /// Whether form is submitting.
  bool get isSubmitting => formStatus == FormStatus.submitting;

  /// Dashboard card values.
  int get totalSeats => stats.totalSeats;
  int get occupiedSeats => stats.occupiedSeats;
  int get availableSeats => stats.availableSeats;

  OwnerLibraryState copyWith({
    OwnerLibraryStatus? status,
    Library? library,
    LibraryStats? stats,
    Failure? failure,
    FormStatus? formStatus,
    bool clearLibrary = false,
    bool clearFailure = false,
  }) {
    return OwnerLibraryState(
      status: status ?? this.status,
      library: clearLibrary ? null : (library ?? this.library),
      stats: stats ?? this.stats,
      failure: clearFailure ? null : (failure ?? this.failure),
      formStatus: formStatus ?? this.formStatus,
    );
  }

  @override
  List<Object?> get props => [status, library, stats, failure, formStatus];
}

/// Status of the owner library screen.
enum OwnerLibraryStatus {
  /// Initial state before any loading.
  initial,

  /// Loading library data.
  loading,

  /// Library loaded (may or may not exist).
  loaded,

  /// Error occurred while loading.
  error,
}

/// Status of form submission (create/update).
enum FormStatus {
  /// No form action in progress.
  idle,

  /// Form is being submitted.
  submitting,

  /// Form submission succeeded.
  success,

  /// Form submission failed.
  failure,
}
