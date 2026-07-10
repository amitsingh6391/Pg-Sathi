import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../data/services/library_form_draft_service.dart';
import '../../../domain/entities/library.dart';
import '../../../domain/usecases/create_library.dart';
import '../../../domain/usecases/get_owner_library.dart';
import '../../../domain/usecases/get_slots_by_library.dart';
import '../../../domain/usecases/update_library.dart';
import 'library_form_state.dart';

/// Cubit for managing library add/edit form.
/// Handles sectioned form navigation and validation.
class LibraryFormCubit extends Cubit<LibraryFormState> {
  LibraryFormCubit({
    required this.getOwnerLibrary,
    required this.createLibrary,
    required this.updateLibrary,
    required this.getSlotsByLibrary,
    required this.draftService,
  }) : super(const LibraryFormState());

  final GetOwnerLibrary getOwnerLibrary;
  final CreateLibrary createLibrary;
  final UpdateLibrary updateLibrary;
  final GetSlotsByLibrary getSlotsByLibrary;
  final LibraryFormDraftService draftService;

  String? _ownerPhone;
  String? _ownerId;

  /// Loads existing library for editing or creates new one.
  Future<void> loadLibrary({
    required String ownerId,
    String? ownerPhone,
  }) async {
    _ownerPhone = ownerPhone;
    _ownerId = ownerId;

    emit(state.copyWith(status: LibraryFormStatus.loading));

    final result = await getOwnerLibrary(
      GetOwnerLibraryParams(ownerId: ownerId),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: LibraryFormStatus.error,
          errorMessage: failure.message,
        ),
      ),
      (library) {
        if (library != null) {
          // Editing existing library - clear any draft
          draftService.clearDraft();
          emit(
            state.copyWith(
              status: LibraryFormStatus.loaded,
              library: library,
              isEditing: true,
            ),
          );
        } else {
          // Creating new library - try to load draft
          final draft = draftService.loadDraft();
          if (draft != null && draft.ownerId == ownerId) {
            // Load from draft
            emit(
              state.copyWith(
                status: LibraryFormStatus.loaded,
                library: draft.library,
                currentSection: _validSection(draft.currentSection),
                isEditing: false,
              ),
            );
          } else {
            // Create new library
            final newLibrary = Library(
              id: const Uuid().v4(),
              ownerId: ownerId,
              name: '',
              capacity: 0,
              ownerPhone: ownerPhone,
            );
            emit(
              state.copyWith(
                status: LibraryFormStatus.loaded,
                library: newLibrary,
                isEditing: false,
              ),
            );
          }
        }
      },
    );
  }

  /// Navigates to next section.
  void nextSection() {
    if (!state.isLastSection) {
      final newSection = state.currentSection + 1;
      emit(state.copyWith(currentSection: newSection, clearError: true));
      _saveDraft(state.library, currentSection: newSection);
    }
  }

  /// Navigates to previous section.
  void previousSection() {
    if (!state.isFirstSection) {
      final newSection = state.currentSection - 1;
      emit(state.copyWith(currentSection: newSection, clearError: true));
      _saveDraft(state.library, currentSection: newSection);
    }
  }

  /// Navigates to specific section.
  void goToSection(int section) {
    if (section >= 0 && section < LibraryFormState.totalSections) {
      emit(state.copyWith(currentSection: section, clearError: true));
      _saveDraft(state.library, currentSection: section);
    }
  }

  int _validSection(int section) {
    return section.clamp(0, LibraryFormState.totalSections - 1);
  }

  // === BASIC INFO ===

  void updateName(String name) {
    if (state.library == null || _ownerId == null) return;
    final updated = state.library!.copyWith(name: name);
    emit(state.copyWith(library: updated));
    _saveDraft(updated);
  }

  // === LOCATION ===

  void updateFullAddress(String address) {
    if (state.library == null || _ownerId == null) return;
    final updated = state.library!.copyWith(fullAddress: address);
    emit(state.copyWith(library: updated));
    _saveDraft(updated);
  }

  void updateArea(String area) {
    if (state.library == null || _ownerId == null) return;
    final updated = state.library!.copyWith(area: area);
    emit(state.copyWith(library: updated));
    _saveDraft(updated);
  }

  void updateCoordinates(double? lat, double? lng) {
    if (state.library == null || _ownerId == null) return;
    final updated = state.library!.copyWith(latitude: lat, longitude: lng);
    emit(state.copyWith(library: updated));
    _saveDraft(updated);
  }

  // === FACILITIES ===

  void updateFacility({
    bool? hasWifi,
    bool? hasAC,
    bool? hasPowerBackup,
    bool? hasWashroom,
    bool? hasDrinkingWater,
    bool? hasCCTV,
  }) {
    if (state.library == null || _ownerId == null) return;
    final updated = state.library!.copyWith(
      hasWifi: hasWifi,
      hasAC: hasAC,
      hasPowerBackup: hasPowerBackup,
      hasWashroom: hasWashroom,
      hasDrinkingWater: hasDrinkingWater,
      hasCCTV: hasCCTV,
    );
    emit(state.copyWith(library: updated));
    _saveDraft(updated);
  }

  void toggleFacility(LibraryFacility facility) {
    if (state.library == null) return;
    final lib = state.library!;

    switch (facility) {
      case LibraryFacility.wifi:
        updateFacility(hasWifi: !lib.hasWifi);
      case LibraryFacility.ac:
        updateFacility(hasAC: !lib.hasAC);
      case LibraryFacility.powerBackup:
        updateFacility(hasPowerBackup: !lib.hasPowerBackup);
      case LibraryFacility.washroom:
        updateFacility(hasWashroom: !lib.hasWashroom);
      case LibraryFacility.drinkingWater:
        updateFacility(hasDrinkingWater: !lib.hasDrinkingWater);
      case LibraryFacility.cctv:
        updateFacility(hasCCTV: !lib.hasCCTV);
    }
  }

  // === PAYMENT SETTINGS ===

  void updateOwnerUpiId(String? upiId) {
    if (state.library == null || _ownerId == null) return;
    final updated = state.library!.copyWith(ownerUpiId: upiId);
    emit(state.copyWith(library: updated));
    _saveDraft(updated);
  }

  // === SAVE ===

  /// Validates and saves the library.
  Future<void> saveLibrary() async {
    if (state.library == null) return;

    emit(state.copyWith(status: LibraryFormStatus.saving));

    // Capacity is managed after PG profile creation through slots/rooms/beds.
    // New profiles should not be blocked from saving when capacity is still 0.
    int calculatedCapacity = 0;
    Library? savedLibrary;

    if (!state.isEditing) {
      // Create the PG profile first. Inventory can be added later.
      final createResult = await createLibrary(
        CreateLibraryParams(
          library: state.library!.copyWith(
            isProfileComplete: false, // Will update after final validation
            ownerPhone: _ownerPhone,
            capacity: state.library!.capacity,
            updatedAt: DateTime.now(),
          ),
        ),
      );

      final createSuccess = createResult.fold(
        (failure) {
          emit(
            state.copyWith(
              status: LibraryFormStatus.error,
              errorMessage: failure.message,
            ),
          );
          return false;
        },
        (library) {
          savedLibrary = library;
          return true;
        },
      );

      if (!createSuccess) return;
    } else {
      // For existing libraries, fetch slots and calculate capacity
      savedLibrary = state.library;
      final slotsResult = await getSlotsByLibrary(
        GetSlotsByLibraryParams(libraryId: savedLibrary!.id, activeOnly: false),
      );

      slotsResult.fold((_) => calculatedCapacity = savedLibrary!.capacity, (
        slots,
      ) {
        calculatedCapacity = slots.fold<int>(
          0,
          (sum, slot) => sum + slot.capacity,
        );
      });
    }

    // Update library with calculated capacity
    final libraryWithCapacity = savedLibrary!.copyWith(
      capacity: calculatedCapacity > 0
          ? calculatedCapacity
          : savedLibrary!.capacity,
      ownerPhone: _ownerPhone,
      updatedAt: DateTime.now(),
    );

    // Validate with the calculated capacity
    final validation = libraryWithCapacity.validate();
    if (!validation.isValid) {
      emit(
        state.copyWith(
          status: LibraryFormStatus.error,
          validationErrors: validation.errors,
          errorMessage: validation.errors.first,
        ),
      );
      return;
    }

    // Update library with calculated capacity and mark complete
    final libraryToSave = libraryWithCapacity.copyWith(isProfileComplete: true);

    if (state.isEditing) {
      final result = await updateLibrary(
        UpdateLibraryParams(library: libraryToSave),
      );
      result.fold(
        (failure) => emit(
          state.copyWith(
            status: LibraryFormStatus.error,
            errorMessage: failure.message,
          ),
        ),
        (updatedLibrary) {
          // Clear draft on successful save
          draftService.clearDraft();
          emit(
            state.copyWith(
              status: LibraryFormStatus.success,
              library: updatedLibrary,
            ),
          );
        },
      );
    } else {
      // For new libraries, already created above, just update with capacity
      final updateResult = await updateLibrary(
        UpdateLibraryParams(library: libraryToSave),
      );
      updateResult.fold(
        (failure) => emit(
          state.copyWith(
            status: LibraryFormStatus.error,
            errorMessage: failure.message,
          ),
        ),
        (updatedLibrary) {
          // Clear draft on successful save
          draftService.clearDraft();
          emit(
            state.copyWith(
              status: LibraryFormStatus.success,
              library: updatedLibrary,
            ),
          );
        },
      );
    }
  }

  /// Syncs the library state with updated library data (e.g., after photo updates).
  void syncLibraryState(Library library) {
    emit(state.copyWith(library: library));
  }

  /// Saves draft data.
  void _saveDraft(Library? library, {int? currentSection}) {
    if (library == null || _ownerId == null || state.isEditing) return;
    draftService.saveDraft(
      library: library,
      currentSection: currentSection ?? state.currentSection,
      ownerId: _ownerId!,
    );
  }
}
