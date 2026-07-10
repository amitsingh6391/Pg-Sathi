import 'package:equatable/equatable.dart';

import '../../../domain/core/failure.dart';
import '../../../domain/entities/custom_slot.dart';
import '../../../domain/entities/membership.dart';

/// State for membership assignment cubit with slot awareness.
class MembershipAssignmentState extends Equatable {
  const MembershipAssignmentState({
    this.status = MembershipAssignmentStatus.initial,
    this.memberships = const [],
    this.customSlots = const [],
    this.selectedSeatId,
    this.selectedCustomSlotId,
    this.failure,
    this.savedMembership,
  });

  final MembershipAssignmentStatus status;
  final List<Membership> memberships;
  final List<CustomSlot> customSlots;
  final String? selectedSeatId;
  final String? selectedCustomSlotId;
  final Failure? failure;
  final Membership? savedMembership;

  bool _isSameSeat(Membership membership, String seatId) {
    return membership.assignedSeatId == seatId;
  }

  /// Check if a bed is occupied by an active stay.
  bool isSeatCustomSlotOccupied(String seatId, String slotId) {
    return memberships.any(
      (m) => m.status == MembershipStatus.active && _isSameSeat(m, seatId),
    );
  }

  /// Check if a bed is reserved by a pending payment.
  bool isSeatCustomSlotReserved(String seatId, String slotId) {
    return memberships.any(
      (m) =>
          m.status == MembershipStatus.pendingPayment && _isSameSeat(m, seatId),
    );
  }

  /// Returns the existing active/reserved stay for a bed, if any.
  Membership? existingMembershipForSeat(String seatId, String slotId) {
    try {
      return memberships.firstWhere(
        (m) =>
            (m.status == MembershipStatus.active ||
                m.status == MembershipStatus.pendingPayment) &&
            _isSameSeat(m, seatId),
      );
    } catch (_) {
      return null;
    }
  }

  /// Check if a bed is taken (either occupied or reserved).
  bool isSeatCustomSlotTaken(String seatId, String slotId) {
    return isSeatCustomSlotOccupied(seatId, slotId) ||
        isSeatCustomSlotReserved(seatId, slotId);
  }

  /// Check if a bed is available (not occupied or reserved).
  bool isSeatAvailable(String seatId) {
    return existingMembershipForSeat(seatId, selectedCustomSlotId ?? '') ==
        null;
  }

  int bookedCountForSlot(String slotId) {
    return memberships
        .where(
          (m) =>
              m.slotId == slotId &&
              (m.status == MembershipStatus.active ||
                  m.status == MembershipStatus.pendingPayment),
        )
        .length;
  }

  SeatLayoutStatus seatLayoutStatus(String seatId) {
    final isOccupied = isSeatCustomSlotOccupied(seatId, '');
    final isReserved = isSeatCustomSlotReserved(seatId, '');
    if (isOccupied) return SeatLayoutStatus.occupied;
    if (isReserved) return SeatLayoutStatus.reserved;
    return SeatLayoutStatus.available;
  }

  bool get isLoading => status == MembershipAssignmentStatus.loading;
  bool get isSubmitting => status == MembershipAssignmentStatus.submitting;
  bool get isSuccess => status == MembershipAssignmentStatus.success;
  bool get isError => status == MembershipAssignmentStatus.error;

  bool get canSubmit =>
      selectedSeatId != null && selectedCustomSlotId != null && !isSubmitting;

  /// Get selected custom slot if any.
  CustomSlot? get selectedCustomSlot {
    if (selectedCustomSlotId == null) return null;
    return customSlots.firstWhere(
      (s) => s.id == selectedCustomSlotId,
      orElse: () => const CustomSlot(
        id: '',
        libraryId: '',
        name: '',
        startTime: 0,
        endTime: 0,
        price: 0,
        capacity: 0,
      ),
    );
  }

  MembershipAssignmentState copyWith({
    MembershipAssignmentStatus? status,
    List<Membership>? memberships,
    List<CustomSlot>? customSlots,
    String? selectedSeatId,
    String? selectedCustomSlotId,
    Failure? failure,
    Membership? savedMembership,
    bool clearSelectedSeat = false,
    bool clearSelectedCustomSlot = false,
    bool clearFailure = false,
    bool clearSavedMembership = false,
  }) {
    return MembershipAssignmentState(
      status: status ?? this.status,
      memberships: memberships ?? this.memberships,
      customSlots: customSlots ?? this.customSlots,
      selectedSeatId: clearSelectedSeat
          ? null
          : (selectedSeatId ?? this.selectedSeatId),
      selectedCustomSlotId: clearSelectedCustomSlot
          ? null
          : (selectedCustomSlotId ?? this.selectedCustomSlotId),
      failure: clearFailure ? null : (failure ?? this.failure),
      savedMembership: clearSavedMembership
          ? null
          : (savedMembership ?? this.savedMembership),
    );
  }

  @override
  List<Object?> get props => [
    status,
    memberships,
    customSlots,
    selectedSeatId,
    selectedCustomSlotId,
    failure,
    savedMembership,
  ];
}

enum MembershipAssignmentStatus {
  initial,
  loading,
  loaded,
  submitting,
  success,
  error,
}

enum SeatLayoutStatus {
  available,
  partiallyAvailable,
  occupied,
  reserved,
}
