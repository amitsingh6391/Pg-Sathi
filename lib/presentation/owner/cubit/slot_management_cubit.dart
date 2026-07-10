import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/custom_slot.dart';
import '../../../domain/entities/library.dart';
import '../../../domain/repositories/library_repository.dart';
import '../../../domain/usecases/create_slot.dart';
import '../../../domain/usecases/delete_slot.dart';
import '../../../domain/usecases/get_slots_by_library.dart';
import '../../../domain/usecases/update_slot.dart';
import 'slot_management_state.dart';

/// Cubit for managing custom slots for a library.
class SlotManagementCubit extends Cubit<SlotManagementState> {
  SlotManagementCubit({
    required this.createSlot,
    required this.updateSlot,
    required this.deleteSlot,
    required this.getSlotsByLibrary,
    required this.libraryRepository,
  }) : super(const SlotManagementState());

  final CreateSlot createSlot;
  final UpdateSlot updateSlot;
  final DeleteSlot deleteSlot;
  final GetSlotsByLibrary getSlotsByLibrary;
  final LibraryRepository libraryRepository;

  String? _libraryId;

  /// Loads all slots for a library.
  Future<void> loadSlots(String libraryId) async {
    _libraryId = libraryId;
    emit(state.copyWith(status: SlotManagementStatus.loading));

    final result = await getSlotsByLibrary(
      GetSlotsByLibraryParams(libraryId: libraryId, activeOnly: false),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(status: SlotManagementStatus.error, failure: failure),
      ),
      (slots) => emit(
        state.copyWith(status: SlotManagementStatus.loaded, slots: slots),
      ),
    );
  }

  /// Creates a new slot.
  Future<void> createSlotForLibrary({
    required String name,
    required int startTime,
    required int endTime,
    required double price,
    required int capacity,
    String? seatPrefix,
    int? seatStartNumber,
  }) async {
    if (_libraryId == null) return;

    emit(state.copyWith(status: SlotManagementStatus.submitting));

    final slotId = DateTime.now().millisecondsSinceEpoch.toString();
    final slot = CustomSlot(
      id: slotId,
      libraryId: _libraryId!,
      name: name,
      startTime: startTime,
      endTime: endTime,
      price: price,
      capacity: capacity,
      isActive: true,
      seatPrefix: seatPrefix,
      seatStartNumber: seatStartNumber,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final result = await createSlot(CreateSlotParams(slot: slot));

    result.fold(
      (failure) => emit(
        state.copyWith(status: SlotManagementStatus.error, failure: failure),
      ),
      (createdSlot) {
        final updatedSlots = [...state.slots, createdSlot];
        emit(
          state.copyWith(
            status: SlotManagementStatus.success,
            slots: updatedSlots,
            successMessage: 'Slot created successfully',
          ),
        );
      },
    );
  }

  /// Updates an existing slot.
  Future<void> updateSlotForLibrary(CustomSlot slot) async {
    emit(state.copyWith(status: SlotManagementStatus.submitting));

    final updatedSlot = slot.copyWith(updatedAt: DateTime.now());
    final result = await updateSlot(UpdateSlotParams(slot: updatedSlot));

    result.fold(
      (failure) => emit(
        state.copyWith(status: SlotManagementStatus.error, failure: failure),
      ),
      (updated) {
        final updatedSlots = state.slots.map((s) {
          return s.id == updated.id ? updated : s;
        }).toList();
        emit(
          state.copyWith(
            status: SlotManagementStatus.success,
            slots: updatedSlots,
            successMessage: 'Slot updated successfully',
          ),
        );
      },
    );
  }

  /// Deletes a slot.
  Future<void> deleteSlotForLibrary(String slotId) async {
    if (_libraryId == null) return;

    emit(state.copyWith(status: SlotManagementStatus.submitting));

    final result = await deleteSlot(
      DeleteSlotParams(libraryId: _libraryId!, slotId: slotId),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(status: SlotManagementStatus.error, failure: failure),
      ),
      (_) {
        final updatedSlots = state.slots.where((s) => s.id != slotId).toList();
        emit(
          state.copyWith(
            status: SlotManagementStatus.success,
            slots: updatedSlots,
            successMessage: 'Slot deleted successfully',
          ),
        );
      },
    );
  }

  /// Toggles slot active status.
  Future<void> toggleSlotActive(CustomSlot slot) async {
    final updatedSlot = slot.isActive ? slot.deactivate() : slot.activate();
    await updateSlotForLibrary(updatedSlot);
  }

  /// Resets error state.
  void resetError() {
    emit(
      state.copyWith(
        status: SlotManagementStatus.loaded,
        clearFailure: true,
        clearSuccessMessage: true,
      ),
    );
  }

  Future<void> updateTotalSeatCapacity(Library library, int? capacity) async {
    final updated = library.copyWith(
      totalSeatCapacity: capacity,
      updatedAt: DateTime.now(),
    );
    await libraryRepository.updateLibrary(updated);
  }
}
