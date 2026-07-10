import 'package:equatable/equatable.dart';

import '../../../domain/core/failure.dart';
import '../../../domain/entities/slot.dart';
import '../../../domain/usecases/get_occupied_seats.dart';

/// Sorting options for occupied seats.
enum SortBy {
  seatNumber,
  dateExpiring,
  status,
  name,
  daysRemaining,
  addedDate,
}

/// State for occupied seats cubit.
/// Using Cubit: Simple linear flow - load list, perform action, refresh.
class OccupiedSeatsState extends Equatable {
  const OccupiedSeatsState({
    this.status = OccupiedSeatsStatus.initial,
    this.occupiedSeats = const [],
    this.expiredSeats = const [],
    this.failure,
    this.actionStatus = ActionStatus.idle,
    this.actionMessage,
    this.selectedSlotFilter,
    this.searchQuery = '',
    this.sortBy = SortBy.seatNumber,
    this.isExporting = false,
  });

  final OccupiedSeatsStatus status;
  final List<OccupiedSeatInfo> occupiedSeats;
  final List<OccupiedSeatInfo> expiredSeats;
  final Failure? failure;
  final ActionStatus actionStatus;
  final String? actionMessage;
  final Slot? selectedSlotFilter;

  /// Current search query for filtering students.
  final String searchQuery;

  /// Current sort preference.
  final SortBy sortBy;

  /// Whether an Excel export is in progress.
  final bool isExporting;

  bool get isLoading => status == OccupiedSeatsStatus.loading;
  bool get isActionInProgress => actionStatus == ActionStatus.inProgress;

  /// Whether a search is currently active.
  bool get hasActiveSearch => searchQuery.trim().isNotEmpty;

  /// Filtered seats based on selected slot filter.
  List<OccupiedSeatInfo> get filteredSeats {
    if (selectedSlotFilter == null) {
      return occupiedSeats;
    }
    return occupiedSeats.where((seat) {
      // Check legacy slot
      if (seat.membership.slot == selectedSlotFilter) {
        return true;
      }
      // For custom slots, check if it matches the time range
      // Morning: 6 AM - 2 PM, Evening: 2 PM - 10 PM
      if (seat.membership.slotId != null && seat.membership.slot == null) {
        // This would require fetching custom slot details
        // For now, we'll filter by legacy slot only
        return false;
      }
      return false;
    }).toList();
  }

  /// Searches seats by student name, phone number, or seat ID.
  /// Returns all seats if query is empty.
  List<OccupiedSeatInfo> searchSeats(List<OccupiedSeatInfo> seats) {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return seats;

    return seats.where((seat) {
      // Search by student name
      final name = seat.studentName?.toLowerCase() ?? '';
      if (name.contains(query)) return true;

      // Search by phone number (normalized: remove +91, spaces, etc.)
      final phone = seat.studentPhone?.replaceAll(RegExp(r'[+\s-]'), '') ?? '';
      final normalizedQuery = query.replaceAll(RegExp(r'[+\s-]'), '');
      if (phone.contains(normalizedQuery)) return true;

      // Search by membership phone (fallback)
      final membershipPhone = seat.membership.phoneNumber.replaceAll(
        RegExp(r'[+\s-]'),
        '',
      );
      if (membershipPhone.contains(normalizedQuery)) return true;

      // Search by seat ID (e.g., "S01", "01", "1")
      final seatId = seat.seatId.toLowerCase();
      if (seatId.contains(query)) return true;

      // Also match seat number directly (e.g., "1" matches "S01")
      final seatNumber = seat.seatNumber.toString();
      if (seatNumber == query || seatNumber.contains(query)) return true;

      return false;
    }).toList();
  }

  OccupiedSeatsState copyWith({
    OccupiedSeatsStatus? status,
    List<OccupiedSeatInfo>? occupiedSeats,
    List<OccupiedSeatInfo>? expiredSeats,
    Failure? failure,
    ActionStatus? actionStatus,
    String? actionMessage,
    Slot? selectedSlotFilter,
    String? searchQuery,
    SortBy? sortBy,
    bool? isExporting,
    bool clearFailure = false,
    bool clearActionMessage = false,
    bool clearSlotFilter = false,
    bool clearSearch = false,
  }) {
    return OccupiedSeatsState(
      status: status ?? this.status,
      occupiedSeats: occupiedSeats ?? this.occupiedSeats,
      expiredSeats: expiredSeats ?? this.expiredSeats,
      failure: clearFailure ? null : (failure ?? this.failure),
      actionStatus: actionStatus ?? this.actionStatus,
      actionMessage: clearActionMessage
          ? null
          : (actionMessage ?? this.actionMessage),
      selectedSlotFilter: clearSlotFilter
          ? null
          : (selectedSlotFilter ?? this.selectedSlotFilter),
      searchQuery: clearSearch ? '' : (searchQuery ?? this.searchQuery),
      sortBy: sortBy ?? this.sortBy,
      isExporting: isExporting ?? this.isExporting,
    );
  }

  @override
  List<Object?> get props => [
    status,
    occupiedSeats,
    expiredSeats,
    failure,
    actionStatus,
    actionMessage,
    selectedSlotFilter,
    searchQuery,
    sortBy,
    isExporting,
  ];
}

enum OccupiedSeatsStatus { initial, loading, loaded, error }

enum ActionStatus { idle, inProgress, success, failure }
