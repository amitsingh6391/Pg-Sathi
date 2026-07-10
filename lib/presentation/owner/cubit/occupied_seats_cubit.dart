import 'package:flutter/services.dart' show Rect;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/services/member_export_service.dart';
import '../../../domain/entities/slot.dart';
import '../../../domain/usecases/cancel_membership.dart';
import '../../../domain/usecases/deactivate_membership.dart';
import '../../../domain/usecases/get_occupied_seats.dart';
import '../../../domain/usecases/get_expired_seats.dart';
import '../../../domain/usecases/reassign_seat.dart';
import '../../../domain/usecases/update_membership.dart';
import '../../../core/utils/file_download_helper.dart';
import 'occupied_seats_state.dart';

/// Cubit for managing occupied seats list and actions with slot awareness.
///
/// Using Cubit (not Bloc) because:
/// - Simple linear state flow: load → display → action → refresh
/// - No complex event transformations needed
/// - Actions are straightforward CRUD-like operations
class OccupiedSeatsCubit extends Cubit<OccupiedSeatsState> {
  OccupiedSeatsCubit({
    required this.getOccupiedSeats,
    required this.getExpiredSeats,
    required this.reassignSeat,
    required this.deactivateMembership,
    required this.cancelMembership,
    required this.updateMembership,
    required this.memberExportService,
  }) : super(const OccupiedSeatsState());

  final GetOccupiedSeats getOccupiedSeats;
  final GetExpiredSeats getExpiredSeats;
  final ReassignSeat reassignSeat;
  final DeactivateMembership deactivateMembership;
  final CancelMembership cancelMembership;
  final UpdateMembership updateMembership;
  final MemberExportService memberExportService;

  String? _libraryId;
  int? _libraryCapacity;

  /// Loads occupied seats and expired seats for a library.
  Future<void> load({
    required String libraryId,
    required int libraryCapacity,
  }) async {
    _libraryId = libraryId;
    _libraryCapacity = libraryCapacity;

    if (isClosed) return;
    emit(
      state.copyWith(status: OccupiedSeatsStatus.loading, clearFailure: true),
    );

    // Fetch occupied seats first (reads active + reserved memberships).
    final occupiedResult = await getOccupiedSeats(
      GetOccupiedSeatsParams(libraryId: libraryId),
    );

    if (isClosed) return;

    await occupiedResult.fold<Future<void>>(
      (failure) async {
        emit(
          state.copyWith(status: OccupiedSeatsStatus.error, failure: failure),
        );
      },
      (occupiedSeats) async {
        final expiredResult = await getExpiredSeats(
          GetExpiredSeatsParams(
            libraryId: libraryId,
            currentDate: DateTime.now(),
          ),
        );

        if (isClosed) return;

        expiredResult.fold(
          (failure) => emit(
            state.copyWith(
              status: OccupiedSeatsStatus.loaded,
              occupiedSeats: occupiedSeats,
              expiredSeats: const [],
            ),
          ),
          (expiredSeats) => emit(
            state.copyWith(
              status: OccupiedSeatsStatus.loaded,
              occupiedSeats: occupiedSeats,
              expiredSeats: expiredSeats,
            ),
          ),
        );
      },
    );
  }

  /// Reassigns a membership to a new seat and/or slot.
  Future<void> reassign({
    required String membershipId,
    required String newSeatId,
    Slot? newSlot,
  }) async {
    if (isClosed) return;
    emit(
      state.copyWith(
        actionStatus: ActionStatus.inProgress,
        clearActionMessage: true,
      ),
    );

    final result = await reassignSeat(
      ReassignSeatParams(
        membershipId: membershipId,
        newSeatId: newSeatId,
        newSlot: newSlot,
      ),
    );

    if (isClosed) return;
    result.fold(
      (failure) => emit(
        state.copyWith(
          actionStatus: ActionStatus.failure,
          actionMessage: failure.message,
        ),
      ),
      (membership) {
        emit(
          state.copyWith(
            actionStatus: ActionStatus.success,
            actionMessage: 'Membership updated successfully',
          ),
        );
        // Refresh list
        _refreshList();
      },
    );
  }

  /// Cancels a membership (early exit, frees seat immediately).
  Future<void> cancel({required String membershipId}) async {
    if (isClosed) return;
    emit(
      state.copyWith(
        actionStatus: ActionStatus.inProgress,
        clearActionMessage: true,
      ),
    );

    final result = await cancelMembership(
      CancelMembershipParams(membershipId: membershipId),
    );

    if (isClosed) return;
    result.fold(
      (failure) => emit(
        state.copyWith(
          actionStatus: ActionStatus.failure,
          actionMessage: failure.message,
        ),
      ),
      (membership) {
        emit(
          state.copyWith(
            actionStatus: ActionStatus.success,
            actionMessage: 'Membership cancelled successfully',
          ),
        );
        // Refresh list
        _refreshList();
      },
    );
  }

  /// Deactivates a membership (legacy, use cancel for early exit).
  Future<void> deactivate({required String membershipId}) async {
    if (isClosed) return;
    emit(
      state.copyWith(
        actionStatus: ActionStatus.inProgress,
        clearActionMessage: true,
      ),
    );

    final result = await deactivateMembership(
      DeactivateMembershipParams(membershipId: membershipId),
    );

    if (isClosed) return;
    result.fold(
      (failure) => emit(
        state.copyWith(
          actionStatus: ActionStatus.failure,
          actionMessage: failure.message,
        ),
      ),
      (membership) {
        emit(
          state.copyWith(
            actionStatus: ActionStatus.success,
            actionMessage: 'Membership deactivated successfully',
          ),
        );
        // Refresh list
        _refreshList();
      },
    );
  }

  /// Updates membership details (seat, start date, end date, student name).
  Future<void> updateMembershipDetails({
    required String membershipId,
    String? newSeatId,
    DateTime? newStartDate,
    DateTime? newEndDate,
    String? newStudentName,
  }) async {
    if (isClosed) return;
    emit(
      state.copyWith(
        actionStatus: ActionStatus.inProgress,
        clearActionMessage: true,
      ),
    );

    final result = await updateMembership(
      UpdateMembershipParams(
        membershipId: membershipId,
        newSeatId: newSeatId,
        newStartDate: newStartDate,
        newExpiryDate: newEndDate,
        newStudentName: newStudentName,
      ),
    );

    if (isClosed) return;
    result.fold(
      (failure) => emit(
        state.copyWith(
          actionStatus: ActionStatus.failure,
          actionMessage: failure.message,
        ),
      ),
      (membership) {
        emit(
          state.copyWith(
            actionStatus: ActionStatus.success,
            actionMessage: 'Membership updated successfully',
          ),
        );
        // Refresh list
        _refreshList();
      },
    );
  }

  /// Refreshes the occupied seats list.
  Future<void> refresh() async {
    if (_libraryId != null && _libraryCapacity != null) {
      await load(libraryId: _libraryId!, libraryCapacity: _libraryCapacity!);
    }
  }

  /// Resets action status (after showing snackbar).
  void resetActionStatus() {
    if (isClosed) return;
    emit(
      state.copyWith(actionStatus: ActionStatus.idle, clearActionMessage: true),
    );
  }

  /// Changes the sort order for occupied seats.
  void setSortBy(SortBy sortBy) {
    if (isClosed) return;
    emit(state.copyWith(sortBy: sortBy));
  }

  /// Filters seats by slot (AM/PM/BOTH).
  void filterBySlot(Slot? slot) {
    if (isClosed) return;
    emit(
      state.copyWith(selectedSlotFilter: slot, clearSlotFilter: slot == null),
    );
  }

  /// Updates search query for filtering students.
  /// Search is performed across name, phone, and seat ID.
  void updateSearchQuery(String query) {
    if (isClosed) return;
    emit(state.copyWith(searchQuery: query));
  }

  /// Clears the current search query.
  void clearSearch() {
    if (isClosed) return;
    emit(state.copyWith(clearSearch: true));
  }

  /// Gets available seats for reassignment (all slots).
  List<String> getAvailableSeats() {
    if (_libraryCapacity == null) return [];

    final occupiedSeatIds = state.occupiedSeats.map((s) => s.seatId).toSet();

    return List.generate(_libraryCapacity!, (i) {
      final seatId = 'B${i + 1}';
      return seatId;
    }).where((seatId) => !occupiedSeatIds.contains(seatId)).toList();
  }

  /// Gets available beds.
  /// Excludes both occupied (active) AND reserved (pendingPayment) beds.
  List<String> getAvailableSeatsForSlot(Slot slot) {
    if (_libraryCapacity == null) return [];

    final takenSeatIds = state.occupiedSeats.map((s) => s.seatId).toSet();

    return List.generate(_libraryCapacity!, (i) {
      final seatId = 'B${i + 1}';
      return seatId;
    }).where((seatId) => !takenSeatIds.contains(seatId)).toList();
  }

  /// Generates and shares an Excel file with all member data for audit purposes.
  /// Includes both active and expired seats.
  Future<void> exportMemberData({
    required String libraryName,
    Rect? sharePositionOrigin,
  }) async {
    if (isClosed) return;
    emit(state.copyWith(isExporting: true));

    try {
      final allSeats = [...state.occupiedSeats, ...state.expiredSeats];
      final bytes = memberExportService.generateMemberExcel(
        seats: allSeats,
        libraryName: libraryName,
      );

      final sanitized = libraryName.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
      final fileName = '${sanitized}_members.xlsx';

      await FileDownloadHelper.downloadFile(
        bytes: bytes,
        fileName: fileName,
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        sharePositionOrigin: sharePositionOrigin,
      );

      if (isClosed) return;
      emit(
        state.copyWith(
          isExporting: false,
          actionStatus: ActionStatus.success,
          actionMessage: 'Member data exported successfully',
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isExporting: false,
          actionStatus: ActionStatus.failure,
          actionMessage: 'Export failed: ${e.toString()}',
        ),
      );
    }
  }

  void _refreshList() {
    if (_libraryId != null && _libraryCapacity != null) {
      load(libraryId: _libraryId!, libraryCapacity: _libraryCapacity!);
    }
  }
}
