import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/manager_access.dart';
import '../../../domain/usecases/get_owner_libraries.dart';
import '../../../domain/usecases/manager_usecases.dart';
import 'managers_state.dart';

/// Owner's list of PG managers, and inviting or revoking them.
class ManagersCubit extends Cubit<ManagersState> {
  ManagersCubit({
    required this.getOwnerLibraries,
    required this.getManagers,
    required this.inviteManager,
    required this.revokeManager,
  }) : super(const ManagersState());

  final GetOwnerLibraries getOwnerLibraries;
  final GetManagers getManagers;
  final InviteManager inviteManager;
  final RevokeManager revokeManager;

  Future<void> load(String ownerId) async {
    emit(state.copyWith(status: ManagersStatus.loading));
    final libraries = await getOwnerLibraries(
      GetOwnerLibrariesParams(ownerId: ownerId),
    );
    final managers = await getManagers(ownerId);

    final failure = libraries.fold(
      (f) => f,
      (_) => managers.fold((f) => f, (_) => null),
    );
    if (failure != null) {
      emit(
        state.copyWith(
          status: ManagersStatus.error,
          errorMessage: failure.message,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: ManagersStatus.loaded,
        libraries: libraries.getOrElse(() => const []),
        managers: managers.getOrElse(() => const []),
      ),
    );
  }

  Future<void> invite({
    required String ownerId,
    required String? libraryId,
    required String mobile,
  }) async {
    if (libraryId == null) {
      emit(
        state.copyWith(
          status: ManagersStatus.error,
          errorMessage: 'Create your PG before adding a manager.',
        ),
      );
      return;
    }
    emit(state.copyWith(status: ManagersStatus.saving));
    final result = await inviteManager(
      InviteManagerParams(
        ownerId: ownerId,
        libraryId: libraryId,
        mobile: mobile,
      ),
    );
    await result.fold(
      (failure) async => emit(
        state.copyWith(
          status: ManagersStatus.error,
          errorMessage: failure.message,
        ),
      ),
      (_) => load(ownerId),
    );
  }

  Future<void> revoke({
    required String ownerId,
    required ManagerAccess access,
  }) async {
    emit(state.copyWith(status: ManagersStatus.saving));
    final result = await revokeManager(access);
    await result.fold(
      (failure) async => emit(
        state.copyWith(
          status: ManagersStatus.error,
          errorMessage: failure.message,
        ),
      ),
      (_) => load(ownerId),
    );
  }
}
