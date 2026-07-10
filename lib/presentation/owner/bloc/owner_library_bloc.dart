import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/library.dart';
import '../../../domain/entities/library_stats.dart';
import '../../../domain/usecases/create_library.dart';
import '../../../domain/usecases/get_library_stats.dart';
import '../../../domain/usecases/get_owner_library.dart';
import '../../../domain/usecases/update_library.dart';
import 'owner_library_event.dart';
import 'owner_library_state.dart';

/// BLoC for owner library management.
/// Handles loading, creating, and updating the owner's library.
class OwnerLibraryBloc extends Bloc<OwnerLibraryEvent, OwnerLibraryState> {
  OwnerLibraryBloc({
    required this.getOwnerLibrary,
    required this.getLibraryStats,
    required this.createLibrary,
    required this.updateLibrary,
  }) : super(const OwnerLibraryState()) {
    on<LoadOwnerLibrary>(_onLoadOwnerLibrary);
    on<CreateLibraryRequested>(_onCreateLibrary);
    on<UpdateLibraryRequested>(_onUpdateLibrary);
    on<RefreshLibraryStats>(_onRefreshStats);
  }

  final GetOwnerLibrary getOwnerLibrary;
  final GetLibraryStats getLibraryStats;
  final CreateLibrary createLibrary;
  final UpdateLibrary updateLibrary;

  String? _ownerId;

  Future<void> _onLoadOwnerLibrary(
    LoadOwnerLibrary event,
    Emitter<OwnerLibraryState> emit,
  ) async {
    _ownerId = event.ownerId;
    emit(
      state.copyWith(status: OwnerLibraryStatus.loading, clearFailure: true),
    );

    final libraryResult = await getOwnerLibrary(
      GetOwnerLibraryParams(ownerId: event.ownerId),
    );

    await libraryResult.fold(
      (failure) async {
        emit(
          state.copyWith(status: OwnerLibraryStatus.error, failure: failure),
        );
      },
      (library) async {
        if (library == null) {
          // No library exists yet
          emit(
            state.copyWith(
              status: OwnerLibraryStatus.loaded,
              clearLibrary: true,
              stats: const LibraryStats.empty(),
            ),
          );
        } else {
          // Library exists, load stats (total seats calculated from active slots)
          final statsResult = await getLibraryStats(
            GetLibraryStatsParams(
              libraryId: library.id,
              totalSeatCapacity: library.totalSeatCapacity,
            ),
          );

          statsResult.fold(
            (failure) {
              // Fallback stats: empty (no slots means no seats)
              emit(
                state.copyWith(
                  status: OwnerLibraryStatus.loaded,
                  library: library,
                  stats: const LibraryStats.empty(),
                ),
              );
            },
            (stats) {
              emit(
                state.copyWith(
                  status: OwnerLibraryStatus.loaded,
                  library: library,
                  stats: stats,
                ),
              );
            },
          );
        }
      },
    );
  }

  Future<void> _onCreateLibrary(
    CreateLibraryRequested event,
    Emitter<OwnerLibraryState> emit,
  ) async {
    if (_ownerId == null) return;

    emit(state.copyWith(formStatus: FormStatus.submitting, clearFailure: true));

    final libraryId = DateTime.now().millisecondsSinceEpoch.toString();

    // Create library entity
    final libraryToCreate = Library(
      id: libraryId,
      ownerId: _ownerId!,
      name: event.name,
      fullAddress: event.location, // Legacy: use location as full address
      area: event.location, // Legacy: use location as area
      capacity: event.capacity,
    );

    final result = await createLibrary(
      CreateLibraryParams(library: libraryToCreate),
    );

    result.fold(
      (failure) {
        emit(state.copyWith(formStatus: FormStatus.failure, failure: failure));
      },
      (library) {
        emit(
          state.copyWith(
            formStatus: FormStatus.success,
            library: library,
            stats:
                const LibraryStats.empty(), // Will be updated when slots are created
          ),
        );
        // Reset form status after success
        emit(state.copyWith(formStatus: FormStatus.idle));
      },
    );
  }

  Future<void> _onUpdateLibrary(
    UpdateLibraryRequested event,
    Emitter<OwnerLibraryState> emit,
  ) async {
    if (_ownerId == null || state.library == null) return;

    emit(state.copyWith(formStatus: FormStatus.submitting, clearFailure: true));

    // Update existing library with new values
    final libraryToUpdate = state.library!.copyWith(
      name: event.name,
      fullAddress: event.location,
      area: event.location,
      capacity: event.capacity,
    );

    final result = await updateLibrary(
      UpdateLibraryParams(library: libraryToUpdate),
    );

    result.fold(
      (failure) {
        emit(state.copyWith(formStatus: FormStatus.failure, failure: failure));
      },
      (library) {
        // Refresh stats after library update (will recalculate from slots)
        // Don't update stats here, let user refresh or it will update on next load
        emit(state.copyWith(formStatus: FormStatus.success, library: library));
        // Reset form status after success
        emit(state.copyWith(formStatus: FormStatus.idle));
      },
    );
  }

  Future<void> _onRefreshStats(
    RefreshLibraryStats event,
    Emitter<OwnerLibraryState> emit,
  ) async {
    final library = state.library;
    if (library == null) return;

    final statsResult = await getLibraryStats(
      GetLibraryStatsParams(
        libraryId: library.id,
        totalSeatCapacity: library.totalSeatCapacity,
      ),
    );

    statsResult.fold(
      (failure) {
        // Keep existing stats on failure
      },
      (stats) {
        emit(state.copyWith(stats: stats));
      },
    );
  }
}
