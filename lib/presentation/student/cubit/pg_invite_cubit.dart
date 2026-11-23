import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/custom_slot.dart';
import '../../../domain/entities/membership.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/repositories/library_repository.dart';
import '../../../domain/repositories/membership_repository.dart';
import '../../../domain/usecases/get_slots_by_library.dart';
import 'bed_availability.dart';
import 'pg_invite_state.dart';

/// Resolves the PG behind a QR invite link, plus login state, room options,
/// bed availability and any open request by this resident.
class PgInviteCubit extends Cubit<PgInviteState> {
  PgInviteCubit({
    required this.libraryRepository,
    required this.authRepository,
    required this.membershipRepository,
    required this.getSlotsByLibrary,
  }) : super(const PgInviteState());

  final LibraryRepository libraryRepository;
  final AuthRepository authRepository;
  final MembershipRepository membershipRepository;
  final GetSlotsByLibrary getSlotsByLibrary;

  /// Set [silent] to refresh in place without showing the loading spinner
  /// (e.g. after the resident sends a request).
  Future<void> load(String pgId, {bool silent = false}) async {
    if (!silent) emit(const PgInviteState());

    final user = (await authRepository.getCurrentUser()).fold(
      (_) => null,
      (u) => u,
    );
    if (isClosed) return;
    if (user == null) {
      emit(const PgInviteState(status: PgInviteStatus.needsLogin));
      return;
    }

    // Everything below depends only on pgId + user, so fetch it in one
    // parallel round instead of waiting for the PG before starting the rest.
    final libraryFuture = libraryRepository.getLibraryById(pgId);
    final slotsFuture = getSlotsByLibrary(
      GetSlotsByLibraryParams(libraryId: pgId, activeOnly: true),
    );
    final occupiedFuture = membershipRepository
        .getActiveAndReservedMembershipsForLibrary(pgId);
    final mineFuture = membershipRepository.getMembershipsByUserId(user.id);

    final libraryResult = await libraryFuture;
    final slotsResult = await slotsFuture;
    final occupiedResult = await occupiedFuture;
    final mineResult = await mineFuture;
    if (isClosed) return;

    final library = libraryResult.fold((_) => null, (l) => l);
    if (libraryResult.isLeft()) {
      emit(const PgInviteState(status: PgInviteStatus.error));
      return;
    }
    if (library == null) {
      emit(const PgInviteState(status: PgInviteStatus.notFound));
      return;
    }

    final slots = slotsResult
        .getOrElse(() => <CustomSlot>[])
        .where((slot) => slot.isActive)
        .toList();
    final occupied = occupiedResult.getOrElse(() => <Membership>[]);
    final mine = mineResult.getOrElse(() => <Membership>[]);

    Membership? pending;
    for (final m in mine) {
      if (m.libraryId == pgId && m.isPendingApproval) {
        pending = m;
        break;
      }
    }

    emit(
      PgInviteState(
        status: PgInviteStatus.ready,
        library: library,
        user: user,
        slots: slots,
        freeBedsBySlot: {
          for (final s in slots)
            s.id: BedAvailability.freeBeds(s, occupied).length,
        },
        occupied: occupiedResult.isRight() && slotsResult.isRight()
            ? occupied
            : null,
        pendingRequest: pending,
      ),
    );
  }
}
