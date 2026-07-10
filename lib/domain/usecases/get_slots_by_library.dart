import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../core/core.dart';
import '../entities/custom_slot.dart';
import '../repositories/slot_repository.dart';

/// Use case for getting all slots for a library.
class GetSlotsByLibrary
    implements UseCase<List<CustomSlot>, GetSlotsByLibraryParams> {
  const GetSlotsByLibrary({required this.slotRepository});

  final SlotRepository slotRepository;

  @override
  Future<Either<Failure, List<CustomSlot>>> call(
    GetSlotsByLibraryParams params,
  ) async {
    if (params.activeOnly == true) {
      return slotRepository.getActiveSlotsByLibraryId(params.libraryId);
    }
    return slotRepository.getSlotsByLibraryId(params.libraryId);
  }
}

/// Parameters for GetSlotsByLibrary use case.
class GetSlotsByLibraryParams extends Equatable {
  const GetSlotsByLibraryParams({
    required this.libraryId,
    this.activeOnly = false,
  });

  final String libraryId;
  final bool activeOnly;

  @override
  List<Object?> get props => [libraryId, activeOnly];
}
