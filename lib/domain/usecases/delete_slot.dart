import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../core/core.dart';
import '../entities/membership.dart';
import '../failures/library_failures.dart';
import '../repositories/membership_repository.dart';
import '../repositories/slot_repository.dart';

/// Use case for deleting a custom slot.
/// Checks if slot is in use before deletion.
class DeleteSlot implements UseCase<void, DeleteSlotParams> {
  const DeleteSlot({
    required this.slotRepository,
    required this.membershipRepository,
  });

  final SlotRepository slotRepository;
  final MembershipRepository membershipRepository;

  @override
  Future<Either<Failure, void>> call(DeleteSlotParams params) async {
    // Check if slot exists
    final slotResult = await slotRepository.getSlotById(
      params.libraryId,
      params.slotId,
    );

    return slotResult.fold((failure) => Left(failure), (slot) async {
      if (slot == null) {
        return const Left(InvalidLibraryDataFailure(message: 'Slot not found'));
      }

      // Check if slot is in use by any active memberships
      // Note: This is a simplified check. In production, you might want
      // to check for pendingPayment memberships as well.
      final membershipsResult = await membershipRepository
          .getMembershipsByLibraryId(params.libraryId);

      return membershipsResult.fold((failure) => Left(failure), (memberships) {
        final slotInUse = memberships.any(
          (m) =>
              m.slotId == params.slotId &&
              (m.status == MembershipStatus.active ||
                  m.status == MembershipStatus.pendingPayment),
        );

        if (slotInUse) {
          return const Left(
            InvalidLibraryDataFailure(
              message:
                  'Cannot delete slot: it is currently in use by active or pending memberships',
            ),
          );
        }

        // Delete the slot
        return slotRepository.deleteSlot(params.libraryId, params.slotId);
      });
    });
  }
}

/// Parameters for DeleteSlot use case.
class DeleteSlotParams extends Equatable {
  const DeleteSlotParams({required this.libraryId, required this.slotId});

  final String libraryId;
  final String slotId;

  @override
  List<Object?> get props => [libraryId, slotId];
}
