import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../core/core.dart';
import '../entities/custom_slot.dart';
import '../failures/library_failures.dart';
import '../repositories/slot_repository.dart';

/// Use case for creating a custom slot for a library.
/// Validates slot times only. Overlapping slots are allowed to support
/// different slot types (e.g., premium vs normal slots at the same time).
class CreateSlot implements UseCase<CustomSlot, CreateSlotParams> {
  const CreateSlot({required this.slotRepository});

  final SlotRepository slotRepository;

  @override
  Future<Either<Failure, CustomSlot>> call(CreateSlotParams params) async {
    // Validate slot times
    // Note: Allows overnight slots (endTime < startTime means slot spans to next day)
    if (!params.slot.isValid) {
      return const Left(
        InvalidLibraryDataFailure(
          message: 'Invalid slot times: times must be between 0-1440 minutes and start/end cannot be equal',
        ),
      );
    }

    // Create the slot (overlapping slots are allowed)
    return slotRepository.createSlot(params.slot);
  }
}

/// Parameters for CreateSlot use case.
class CreateSlotParams extends Equatable {
  const CreateSlotParams({required this.slot});

  final CustomSlot slot;

  @override
  List<Object?> get props => [slot];
}
