import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/failures/user_failures.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/repositories/membership_repository.dart';
import '../../../domain/repositories/user_repository.dart';
import '../../../domain/usecases/get_student_documents.dart';
import '../../../domain/usecases/get_student_memberships.dart';
import '../../../domain/usecases/sync_memberships_on_login.dart';
import '../../../domain/usecases/validate_daily_presence.dart';
import 'student_home_state.dart';

/// Cubit for student home screen.
/// Delegates all business logic to use cases.
class StudentHomeCubit extends Cubit<StudentHomeState> {
  StudentHomeCubit({
    required this.getStudentMemberships,
    required this.validateDailyPresence,
    required this.syncMembershipsOnLogin,
    required this.membershipRepository,
    required this.authRepository,
    required this.userRepository,
    required this.getStudentDocuments,
  }) : super(const StudentHomeState());

  final GetStudentMemberships getStudentMemberships;
  final ValidateDailyPresence validateDailyPresence;
  final SyncMembershipsOnLogin syncMembershipsOnLogin;
  final MembershipRepository membershipRepository;
  final AuthRepository authRepository;
  final UserRepository userRepository;
  final GetStudentDocuments getStudentDocuments;

  /// Loads student dashboard data with all memberships.
  /// Also checks for unregistered memberships that can be synced.
  Future<void> loadDashboard({required String userId}) async {
    emit(state.copyWith(status: StudentHomeStatus.loading, clearFailure: true));

    // Fire everything we can with userId known immediately — all 3 in parallel
    final documentsFuture = getStudentDocuments(
      GetStudentDocumentsParams(studentId: userId),
    );
    final membershipsFuture = getStudentMemberships(
      GetStudentMembershipsParams(userId: userId),
    );
    final userFuture = authRepository.getCurrentUser();

    final userResult = await userFuture;
    User? currentUser;
    userResult.fold((_) => {}, (user) => currentUser = user);

    if (currentUser == null) {
      emit(
        state.copyWith(
          status: StudentHomeStatus.failure,
          failure: const UserNotFoundFailure(message: 'User not found'),
        ),
      );
      return;
    }

    final phoneNumber = currentUser!.phone;
    if (phoneNumber.isEmpty) {
      emit(
        state.copyWith(
          status: StudentHomeStatus.failure,
          failure: const InvalidUserDataFailure(
            message: 'Phone number not found',
          ),
        ),
      );
      return;
    }

    // Start unregistered check now that we have phoneNumber.
    // memberships are already in flight — await both together.
    final unregisteredFuture = _checkUnregisteredMemberships(phoneNumber);

    final membershipsResult = await membershipsFuture;
    final hasUnregisteredMemberships = await unregisteredFuture;

    membershipsResult.fold(
      (failure) => emit(
        state.copyWith(
          status: StudentHomeStatus.failure,
          failure: failure,
          user: currentUser,
          hasUnregisteredMemberships: hasUnregisteredMemberships,
        ),
      ),
      (memberships) async {
        // exploreCheck needs memberships — starts now; documents already in flight
        final exploreFuture = _checkExploreLibrariesVisibility(memberships);

        final canShowExploreLibraries = await exploreFuture;
        final documentsResult = await documentsFuture;
        final documentStatus = documentsResult.fold(
          (_) => DocumentVerificationStatus.none,
          (documents) {
            if (documents.isEmpty) return DocumentVerificationStatus.none;
            if (documents.every((doc) => doc.isApproved)) {
              return DocumentVerificationStatus.verified;
            }
            return DocumentVerificationStatus.pending;
          },
        );

        emit(
          state.copyWith(
            status: StudentHomeStatus.success,
            memberships: memberships,
            user: currentUser,
            canShowExploreLibraries: canShowExploreLibraries,
            hasUnregisteredMemberships: hasUnregisteredMemberships,
            documentStatus: documentStatus,
          ),
        );
      },
    );
  }

  /// Checks if there are unregistered memberships for this phone number.
  Future<bool> _checkUnregisteredMemberships(String phoneNumber) async {
    final result = await membershipRepository.getUnregisteredMembershipsByPhone(
      phoneNumber,
    );
    return result.fold((_) => false, (memberships) => memberships.isNotEmpty);
  }

  /// Syncs unregistered memberships to the current user.
  Future<void> syncMemberships({
    required String userId,
    required String phoneNumber,
  }) async {
    emit(state.copyWith(status: StudentHomeStatus.loading, clearFailure: true));

    final result = await syncMembershipsOnLogin(
      SyncMembershipsOnLoginParams(userId: userId, phoneNumber: phoneNumber),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(status: StudentHomeStatus.failure, failure: failure),
      ),
      (_) {
        // Reload dashboard after successful sync
        loadDashboard(userId: userId);
      },
    );
  }

  /// Checks if explore libraries tile should be shown.
  /// Returns false if any active membership's owner has showOtherLibraries=false.
  Future<bool> _checkExploreLibrariesVisibility(
    List<StudentMembershipInfo> memberships,
  ) async {
    // If no active memberships, always show (default behavior)
    final activeMemberships = memberships.where((m) => m.isActive).toList();
    if (activeMemberships.isEmpty) {
      return true;
    }

    // Get unique owner IDs from active memberships
    final ownerIds = activeMemberships
        .where((m) => m.library != null)
        .map((m) => m.library!.ownerId)
        .toSet()
        .toList();

    if (ownerIds.isEmpty) {
      return true; // No library info, default to showing
    }

    // Fetch owner settings
    final ownersResult = await userRepository.getUsersByIds(ownerIds);

    return ownersResult.fold(
      (failure) => true, // On error, default to showing (fail-safe)
      (ownersMap) {
        // Check if any owner has showOtherLibraries=false
        for (final ownerId in ownerIds) {
          final owner = ownersMap[ownerId];
          if (owner != null && !owner.showOtherLibraries) {
            return false; // Hide if any owner has it disabled
          }
        }
        return true; // Show if all owners allow it or not found (default true)
      },
    );
  }

  /// Dismisses the profile completion prompt.
  void dismissProfilePrompt() {
    emit(state.copyWith(isProfilePromptDismissed: true));
  }

  /// Dismisses the sync banner.
  void dismissSyncBanner() {
    emit(state.copyWith(isSyncBannerDismissed: true));
  }

  /// Updates user in state after profile completion.
  void updateUser(User user) {
    emit(state.copyWith(user: user));
  }

  /// Records daily check-in.
  Future<void> checkIn({
    required String presenceId,
    required String userId,
    required String libraryId,
  }) async {
    emit(state.copyWith(status: StudentHomeStatus.loading));

    final result = await validateDailyPresence(
      ValidateDailyPresenceParams(
        presenceId: presenceId,
        userId: userId,
        libraryId: libraryId,
        checkInTime: DateTime.now(),
      ),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(status: StudentHomeStatus.failure, failure: failure),
      ),
      (presence) => emit(
        state.copyWith(
          status: StudentHomeStatus.success,
          todayPresence: presence,
          isCheckedIn: true,
        ),
      ),
    );
  }
}
