import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/custom_slot.dart';
import '../../../domain/entities/library_stats.dart';
import '../../../domain/repositories/library_repository.dart';
import '../../../domain/repositories/membership_repository.dart';
import '../../../domain/usecases/get_slots_by_library.dart';
import 'library_details_state.dart';

/// Cubit for viewing library details.
/// Read-only: no booking or payment from this flow.
class LibraryDetailsCubit extends Cubit<LibraryDetailsState> {
  LibraryDetailsCubit({
    required this.libraryRepository,
    required this.membershipRepository,
    required this.getSlotsByLibrary,
  }) : super(const LibraryDetailsState());

  final LibraryRepository libraryRepository;
  final MembershipRepository membershipRepository;
  final GetSlotsByLibrary getSlotsByLibrary;

  /// Loads library details and checks membership status.
  Future<void> loadLibrary({
    required String libraryId,
    required String userId,
  }) async {
    emit(
      state.copyWith(status: LibraryDetailsStatus.loading, clearFailure: true),
    );

    // Fetch library details
    final libraryResult = await libraryRepository.getLibraryById(libraryId);

    await libraryResult.fold(
      (failure) async => emit(
        state.copyWith(status: LibraryDetailsStatus.error, failure: failure),
      ),
      (library) async {
        if (library == null) {
          emit(state.copyWith(status: LibraryDetailsStatus.error));
          return;
        }

        // Check if student has active membership at this specific library
        bool hasActiveMembership = false;
        final membershipResult = await membershipRepository
            .getActiveMembershipByUserAndLibrary(
          userId: userId,
          libraryId: libraryId,
        );
        membershipResult.fold(
          (_) {},
          (membership) => hasActiveMembership = membership != null,
        );

        // Load custom slots
        final slotsResult = await getSlotsByLibrary(
          GetSlotsByLibraryParams(libraryId: libraryId),
        );

        final customSlots = slotsResult.fold(
          (_) => <CustomSlot>[],
          (slots) => slots,
        );

        // Calculate stats based on capacity
        final stats = LibraryStats(
          totalSeats: library.totalSeatCapacity ?? library.capacity,
          occupiedSeats: 0,
          reservedSeats: 0,
        );

        emit(
          state.copyWith(
            status: LibraryDetailsStatus.loaded,
            library: library,
            stats: stats,
            hasActiveMembership: hasActiveMembership,
            customSlots: customSlots,
          ),
        );
      },
    );
  }
}
