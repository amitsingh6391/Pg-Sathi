import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/services/owner_branch_selection_service.dart';
import '../../../domain/entities/library.dart';
import '../../../domain/entities/library_stats.dart';
import '../../../domain/usecases/create_library.dart';
import '../../../domain/usecases/get_library_stats.dart';
import '../../../domain/usecases/get_owner_libraries.dart';
import '../../../domain/usecases/update_library.dart';
import 'owner_library_event.dart';
import 'owner_library_state.dart';

/// BLoC for owner library management.
/// Supports multi-branch: loads all libraries, tracks selected index.
class OwnerLibraryBloc extends Bloc<OwnerLibraryEvent, OwnerLibraryState> {
  OwnerLibraryBloc({
    required this.getOwnerLibraries,
    required this.getLibraryStats,
    required this.createLibrary,
    required this.updateLibrary,
    required this.branchSelectionService,
  }) : super(const OwnerLibraryState()) {
    on<LoadOwnerLibrary>(_onLoadOwnerLibrary);
    on<SelectLibrary>(_onSelectLibrary);
    on<CreateLibraryRequested>(_onCreateLibrary);
    on<UpdateLibraryRequested>(_onUpdateLibrary);
    on<RefreshLibraryStats>(_onRefreshStats);
  }

  final GetOwnerLibraries getOwnerLibraries;
  final GetLibraryStats getLibraryStats;
  final CreateLibrary createLibrary;
  final UpdateLibrary updateLibrary;
  final OwnerBranchSelectionService branchSelectionService;

  String? _ownerId;
  List<String>? _managedLibraryIds;
  String? _selectedLibraryId;

  Future<void> _onLoadOwnerLibrary(
    LoadOwnerLibrary event,
    Emitter<OwnerLibraryState> emit,
  ) async {
    _ownerId = event.ownerId;
    _managedLibraryIds = event.managedLibraryIds;
    emit(
      state.copyWith(status: OwnerLibraryStatus.loading, clearFailure: true),
    );

    final librariesResult = await getOwnerLibraries(
      GetOwnerLibrariesParams(
        ownerId: event.ownerId,
        onlyLibraryIds: event.managedLibraryIds,
      ),
    );

    await librariesResult.fold(
      (failure) async {
        emit(
          state.copyWith(status: OwnerLibraryStatus.error, failure: failure),
        );
      },
      (libraries) async {
        if (libraries.isEmpty) {
          emit(
            state.copyWith(
              status: OwnerLibraryStatus.loaded,
              clearLibrary: true,
              stats: const LibraryStats.empty(),
            ),
          );
        } else {
          // Restore previously selected library if still in the list.
          // Prefer the persisted selection (survives app restarts), then fall
          // back to the in-memory selection, then the first branch.
          var selectedIndex = 0;
          final persistedId = branchSelectionService.getSelectedLibraryId(
            event.ownerId,
          );
          final savedId = persistedId ?? _selectedLibraryId;
          if (savedId != null) {
            final savedIndex = libraries.indexWhere((l) => l.id == savedId);
            if (savedIndex >= 0) {
              selectedIndex = savedIndex;
            }
          }
          _selectedLibraryId = libraries[selectedIndex].id;
          final selected = libraries[selectedIndex];

          final statsResult = await getLibraryStats(
            GetLibraryStatsParams(
              libraryId: selected.id,
              totalSeatCapacity: selected.totalSeatCapacity,
            ),
          );

          statsResult.fold(
            (failure) {
              emit(
                state.copyWith(
                  status: OwnerLibraryStatus.loaded,
                  libraries: libraries,
                  selectedLibraryIndex: selectedIndex,
                  stats: const LibraryStats.empty(),
                ),
              );
            },
            (stats) {
              emit(
                state.copyWith(
                  status: OwnerLibraryStatus.loaded,
                  libraries: libraries,
                  selectedLibraryIndex: selectedIndex,
                  stats: stats,
                ),
              );
            },
          );
        }
      },
    );
  }

  Future<void> _onSelectLibrary(
    SelectLibrary event,
    Emitter<OwnerLibraryState> emit,
  ) async {
    if (event.index < 0 || event.index >= state.libraries.length) return;

    _selectedLibraryId = state.libraries[event.index].id;

    // Remember which branch the owner opened so the next app session resumes
    // on the same branch instead of resetting to the first one.
    if (_ownerId != null) {
      await branchSelectionService.setSelectedLibraryId(
        _ownerId!,
        _selectedLibraryId!,
      );
    }

    emit(
      state.copyWith(status: OwnerLibraryStatus.loading, clearFailure: true),
    );

    final selected = state.libraries[event.index];
    final statsResult = await getLibraryStats(
      GetLibraryStatsParams(
        libraryId: selected.id,
        totalSeatCapacity: selected.totalSeatCapacity,
      ),
    );

    statsResult.fold(
      (failure) {
        emit(
          state.copyWith(
            status: OwnerLibraryStatus.loaded,
            selectedLibraryIndex: event.index,
            stats: const LibraryStats.empty(),
          ),
        );
      },
      (stats) {
        emit(
          state.copyWith(
            status: OwnerLibraryStatus.loaded,
            selectedLibraryIndex: event.index,
            stats: stats,
          ),
        );
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

    final libraryToCreate = Library(
      id: libraryId,
      ownerId: _ownerId!,
      name: event.name,
      fullAddress: event.location,
      area: event.location,
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
        // Reload libraries to include the new one
        add(
          LoadOwnerLibrary(
            ownerId: _ownerId!,
            managedLibraryIds: _managedLibraryIds,
          ),
        );
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
        // Update the library in the list
        final updatedLibraries = List<Library>.from(state.libraries);
        final idx = updatedLibraries.indexWhere((l) => l.id == library.id);
        if (idx >= 0) {
          updatedLibraries[idx] = library;
        }
        emit(
          state.copyWith(
            formStatus: FormStatus.success,
            libraries: updatedLibraries,
          ),
        );
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

    statsResult.fold((failure) {}, (stats) {
      emit(state.copyWith(stats: stats));
    });
  }
}
