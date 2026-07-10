import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../core/core.dart';
import '../entities/custom_slot.dart';
import '../failures/library_failures.dart';
import '../repositories/slot_repository.dart';

/// Use case for updating a custom slot.
/// Validates slot times only. Overlapping slots are allowed to support
/// different slot types (e.g., premium vs normal slots at the same time).
class UpdateSlot implements UseCase<CustomSlot, UpdateSlotParams> {
  const UpdateSlot({required this.slotRepository});

  final SlotRepository slotRepository;

  @override
  Future<Either<Failure, CustomSlot>> call(UpdateSlotParams params) async {
    // Validate slot times
    // Note: Allows overnight slots (endTime < startTime means slot spans to next day)
    if (!params.slot.isValid) {
      return const Left(
        InvalidLibraryDataFailure(
          message: 'Invalid slot times: times must be between 0-1440 minutes and start/end cannot be equal',
        ),
      );
    }

    // Get existing slot to verify it exists
    final existingResult = await slotRepository.getSlotById(
      params.slot.libraryId,
      params.slot.id,
    );

    return existingResult.fold((failure) => Left(failure), (
      existingSlot,
    ) async {
      if (existingSlot == null) {
        return const Left(InvalidLibraryDataFailure(message: 'Slot not found'));
      }

      // Update the slot (overlapping slots are allowed)
      return slotRepository.updateSlot(params.slot);
    });
  }
}

/// Parameters for UpdateSlot use case.
class UpdateSlotParams extends Equatable {
  const UpdateSlotParams({required this.slot});

  final CustomSlot slot;

  @override
  List<Object?> get props => [slot];
}
