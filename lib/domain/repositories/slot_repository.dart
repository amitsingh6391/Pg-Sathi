import 'package:dartz/dartz.dart';

import '../core/failure.dart';
import '../entities/custom_slot.dart';

/// Repository interface for CustomSlot aggregate.
/// Slots belong to a library and are stored in subcollection.
abstract class SlotRepository {
  /// Creates a new slot for a library.
  Future<Either<Failure, CustomSlot>> createSlot(CustomSlot slot);

  /// Updates an existing slot.
  Future<Either<Failure, CustomSlot>> updateSlot(CustomSlot slot);

  /// Deletes a slot.
  Future<Either<Failure, void>> deleteSlot(String libraryId, String slotId);

  /// Gets a slot by its ID.
  Future<Either<Failure, CustomSlot?>> getSlotById(
    String libraryId,
    String slotId,
  );

  /// Gets all slots for a library.
  /// Optionally filter by active status.
  Future<Either<Failure, List<CustomSlot>>> getSlotsByLibraryId(
    String libraryId, {
    bool? activeOnly,
  });

  /// Gets all active slots for a library.
  /// Convenience method for common use case.
  Future<Either<Failure, List<CustomSlot>>> getActiveSlotsByLibraryId(
    String libraryId,
  );

  /// Checks if a slot overlaps with any existing active slots.
  Future<Either<Failure, bool>> hasOverlappingSlot(
    String libraryId,
    CustomSlot slot,
  );
}
