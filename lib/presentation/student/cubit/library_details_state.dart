import 'package:equatable/equatable.dart';

import '../../../domain/core/failure.dart';
import '../../../domain/entities/custom_slot.dart';
import '../../../domain/entities/library.dart';
import '../../../domain/entities/library_stats.dart';

/// State for library details cubit.
class LibraryDetailsState extends Equatable {
  const LibraryDetailsState({
    this.status = LibraryDetailsStatus.initial,
    this.library,
    this.stats,
    this.failure,
    this.hasActiveMembership = false,
    this.customSlots = const [],
  });

  final LibraryDetailsStatus status;
  final Library? library;
  final LibraryStats? stats;
  final Failure? failure;

  /// Whether the student already has an active membership in this library.
  final bool hasActiveMembership;

  /// Custom slots defined by the library.
  final List<CustomSlot> customSlots;

  bool get isLoading => status == LibraryDetailsStatus.loading;
  bool get isLoaded => status == LibraryDetailsStatus.loaded;
  bool get isError => status == LibraryDetailsStatus.error;

  LibraryDetailsState copyWith({
    LibraryDetailsStatus? status,
    Library? library,
    LibraryStats? stats,
    Failure? failure,
    bool? hasActiveMembership,
    List<CustomSlot>? customSlots,
    bool clearFailure = false,
  }) {
    return LibraryDetailsState(
      status: status ?? this.status,
      library: library ?? this.library,
      stats: stats ?? this.stats,
      failure: clearFailure ? null : (failure ?? this.failure),
      hasActiveMembership: hasActiveMembership ?? this.hasActiveMembership,
      customSlots: customSlots ?? this.customSlots,
    );
  }

  @override
  List<Object?> get props => [
    status,
    library,
    stats,
    failure,
    hasActiveMembership,
    customSlots,
  ];
}

/// Status for library details.
enum LibraryDetailsStatus { initial, loading, loaded, error }
