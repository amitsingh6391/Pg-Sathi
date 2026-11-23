import 'package:equatable/equatable.dart';

import '../../../domain/entities/custom_slot.dart';
import '../../../domain/entities/membership.dart';
import 'bed_availability.dart';

enum BedRequestStatus { loading, ready, submitting, submitted, error }

class BedRequestState extends Equatable {
  const BedRequestState({
    this.status = BedRequestStatus.loading,
    this.slots = const [],
    this.occupied = const [],
    this.selectedSlotId,
    this.selectedBed,
    this.months = 1,
    this.startDate,
    this.existingRequest,
    this.errorMessage,
  });

  final BedRequestStatus status;
  final List<CustomSlot> slots;

  /// Active/reserved stays used to work out which beds are free.
  final List<Membership> occupied;
  final String? selectedSlotId;
  final String? selectedBed;
  final int months;
  final DateTime? startDate;

  /// Resident's open request at this PG (blocks a duplicate request).
  final Membership? existingRequest;
  final String? errorMessage;

  CustomSlot? get selectedSlot {
    for (final s in slots) {
      if (s.id == selectedSlotId) return s;
    }
    return null;
  }

  List<String> freeBedsFor(CustomSlot slot) =>
      BedAvailability.freeBeds(slot, occupied);

  /// Estimated rent for the chosen room type and stay length.
  double? get estimatedRent {
    final slot = selectedSlot;
    return slot == null ? null : slot.price * months;
  }

  bool get canSubmit =>
      selectedSlot != null && selectedBed != null && startDate != null;

  BedRequestState copyWith({
    BedRequestStatus? status,
    List<CustomSlot>? slots,
    List<Membership>? occupied,
    String? selectedSlotId,
    String? selectedBed,
    bool clearSelectedBed = false,
    int? months,
    DateTime? startDate,
    Membership? existingRequest,
    String? errorMessage,
    bool clearError = false,
  }) {
    return BedRequestState(
      status: status ?? this.status,
      slots: slots ?? this.slots,
      occupied: occupied ?? this.occupied,
      selectedSlotId: selectedSlotId ?? this.selectedSlotId,
      selectedBed: clearSelectedBed ? null : (selectedBed ?? this.selectedBed),
      months: months ?? this.months,
      startDate: startDate ?? this.startDate,
      existingRequest: existingRequest ?? this.existingRequest,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    status,
    slots,
    occupied,
    selectedSlotId,
    selectedBed,
    months,
    startDate,
    existingRequest,
    errorMessage,
  ];
}
