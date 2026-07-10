import 'package:equatable/equatable.dart';

import 'slot.dart';

/// Represents a seat within a library.
/// Seat occupancy is tracked per slot (morning/evening).
class Seat extends Equatable {
  const Seat({
    required this.id,
    required this.libraryId,
    required this.seatNumber,
    this.isActive = true,
  });

  final String id;
  final String libraryId;
  final String seatNumber;
  final bool isActive;

  @override
  List<Object?> get props => [id, libraryId, seatNumber, isActive];

  Seat copyWith({
    String? id,
    String? libraryId,
    String? seatNumber,
    bool? isActive,
  }) {
    return Seat(
      id: id ?? this.id,
      libraryId: libraryId ?? this.libraryId,
      seatNumber: seatNumber ?? this.seatNumber,
      isActive: isActive ?? this.isActive,
    );
  }

  Seat deactivate() => copyWith(isActive: false);
  Seat activate() => copyWith(isActive: true);
}

/// Status of a seat slot.
enum SlotStatus {
  /// Seat is available for assignment.
  available,

  /// Seat has been reserved (payment pending).
  reserved,

  /// Seat is occupied (active membership).
  occupied,
}

/// Information about a membership assigned to a slot.
class SlotMembershipInfo extends Equatable {
  const SlotMembershipInfo({
    required this.membershipId,
    required this.status,
    this.userId,
  });

  final String membershipId;
  final SlotStatus status;
  final String? userId;

  bool get isReserved => status == SlotStatus.reserved;
  bool get isOccupied => status == SlotStatus.occupied;

  @override
  List<Object?> get props => [membershipId, status, userId];
}

/// Represents slot-wise occupancy status for a seat.
/// Now tracks both reserved (pendingPayment) and occupied (active) states.
class SeatOccupancy extends Equatable {
  const SeatOccupancy({required this.seat, this.morningInfo, this.eveningInfo});

  final Seat seat;
  final SlotMembershipInfo? morningInfo;
  final SlotMembershipInfo? eveningInfo;

  // Status getters for morning slot
  SlotStatus get morningStatus => morningInfo?.status ?? SlotStatus.available;
  bool get isMorningAvailable => morningStatus == SlotStatus.available;
  bool get isMorningReserved => morningStatus == SlotStatus.reserved;
  bool get isMorningOccupied => morningStatus == SlotStatus.occupied;

  // Status getters for evening slot
  SlotStatus get eveningStatus => eveningInfo?.status ?? SlotStatus.available;
  bool get isEveningAvailable => eveningStatus == SlotStatus.available;
  bool get isEveningReserved => eveningStatus == SlotStatus.reserved;
  bool get isEveningOccupied => eveningStatus == SlotStatus.occupied;

  // Combined status checks
  bool get isFullyOccupied => isMorningOccupied && isEveningOccupied;
  bool get isFullyAvailable => isMorningAvailable && isEveningAvailable;
  bool get hasAnyReservation => isMorningReserved || isEveningReserved;
  bool get hasAnyOccupancy => isMorningOccupied || isEveningOccupied;

  /// Check if slot is occupied or reserved (not available).
  bool isSlotTaken(Slot slot) {
    final status = slot == Slot.morning ? morningStatus : eveningStatus;
    return status != SlotStatus.available;
  }

  /// Get status for a specific slot.
  SlotStatus getSlotStatus(Slot slot) {
    return slot == Slot.morning ? morningStatus : eveningStatus;
  }

  /// Get membership info for a specific slot.
  SlotMembershipInfo? getMembershipInfo(Slot slot) {
    return slot == Slot.morning ? morningInfo : eveningInfo;
  }

  /// Legacy compatibility: Get membership ID for slot (occupied only).
  String? getMembershipIdForSlot(Slot slot) {
    final info = getMembershipInfo(slot);
    return info?.isOccupied == true ? info?.membershipId : null;
  }

  /// Get membership ID for slot (reserved or occupied).
  String? getAnyMembershipIdForSlot(Slot slot) {
    return getMembershipInfo(slot)?.membershipId;
  }

  @override
  List<Object?> get props => [seat, morningInfo, eveningInfo];
}

/// Summary of seat occupancy for a library.
/// Now includes reserved counts separately.
class SeatOccupancySummary extends Equatable {
  const SeatOccupancySummary({
    required this.totalSeats,
    required this.morningOccupied,
    required this.morningReserved,
    required this.morningAvailable,
    required this.eveningOccupied,
    required this.eveningReserved,
    required this.eveningAvailable,
    required this.seatOccupancies,
  });

  const SeatOccupancySummary.empty()
    : totalSeats = 0,
      morningOccupied = 0,
      morningReserved = 0,
      morningAvailable = 0,
      eveningOccupied = 0,
      eveningReserved = 0,
      eveningAvailable = 0,
      seatOccupancies = const [];

  final int totalSeats;
  final int morningOccupied;
  final int morningReserved;
  final int morningAvailable;
  final int eveningOccupied;
  final int eveningReserved;
  final int eveningAvailable;
  final List<SeatOccupancy> seatOccupancies;

  /// Total occupied slots (morning + evening) - active memberships only.
  int get totalOccupiedSlots => morningOccupied + eveningOccupied;

  /// Total reserved slots (morning + evening) - pending payment.
  int get totalReservedSlots => morningReserved + eveningReserved;

  /// Total available slots (morning + evening) - truly free.
  int get totalAvailableSlots => morningAvailable + eveningAvailable;

  /// Total possible slots (seats * 2 for both slots).
  int get totalSlots => totalSeats * 2;

  @override
  List<Object?> get props => [
    totalSeats,
    morningOccupied,
    morningReserved,
    morningAvailable,
    eveningOccupied,
    eveningReserved,
    eveningAvailable,
    seatOccupancies,
  ];
}
