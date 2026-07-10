import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/analytics_service.dart';
import '../../../domain/entities/membership.dart';
import '../../../domain/entities/payment.dart';
import '../../../domain/entities/payment_breakdown.dart';
import '../../../domain/repositories/membership_repository.dart';
import '../../../domain/usecases/assign_membership.dart';
import '../../../domain/usecases/assign_membership_with_custom_slot.dart';
import '../../../domain/usecases/get_slots_by_library.dart';
import '../../../domain/usecases/update_membership.dart';
import '../../../domain/usecases/validate_seat_limit.dart';
import 'membership_assignment_state.dart';

/// Cubit for membership assignment flow with slot awareness.
/// Handles bed group selection, bed assignment, and updates.
/// Supports both legacy slots (morning/evening) and custom slots.
class MembershipAssignmentCubit extends Cubit<MembershipAssignmentState> {
  MembershipAssignmentCubit({
    required this.assignMembership,
    required this.assignMembershipWithCustomSlot,
    required this.updateMembership,
    required this.membershipRepository,
    required this.getSlotsByLibrary,
    required this.analyticsService,
    required this.validateSeatLimit,
  }) : super(const MembershipAssignmentState());

  final AssignMembership assignMembership;
  final AssignMembershipWithCustomSlot assignMembershipWithCustomSlot;
  final UpdateMembership updateMembership;
  final MembershipRepository membershipRepository;
  final ValidateSeatLimit validateSeatLimit;
  final GetSlotsByLibrary getSlotsByLibrary;
  final AnalyticsService analyticsService;

  String? _libraryId;
  String? _ownerId;

  /// Loads active and reserved memberships for the library.
  /// This includes both occupied seats (active) and reserved seats (pending payment).
  /// Also loads custom slots for the library.
  Future<void> loadMemberships({
    required String libraryId,
    required String ownerId,
  }) async {
    _libraryId = libraryId;
    _ownerId = ownerId;
    emit(state.copyWith(status: MembershipAssignmentStatus.loading));

    // Load memberships and custom slots in parallel
    final membershipResult = await membershipRepository
        .getActiveAndReservedMembershipsForLibrary(libraryId);
    final slotsResult = await getSlotsByLibrary(
      GetSlotsByLibraryParams(libraryId: libraryId),
    );

    membershipResult.fold(
      (failure) => emit(
        state.copyWith(
          status: MembershipAssignmentStatus.error,
          failure: failure,
        ),
      ),
      (memberships) {
        slotsResult.fold(
          (failure) => emit(
            state.copyWith(
              status: MembershipAssignmentStatus.error,
              failure: failure,
            ),
          ),
          (customSlots) => emit(
            state.copyWith(
              status: MembershipAssignmentStatus.loaded,
              memberships: memberships,
              customSlots: customSlots,
            ),
          ),
        );
      },
    );
  }

  /// Selects a seat for assignment.
  void selectSeat(String seatId, {bool clearCustomSlot = false}) {
    emit(
      state.copyWith(
        selectedSeatId: seatId,
        clearSelectedCustomSlot: clearCustomSlot,
        clearFailure: true,
      ),
    );
  }

  /// Selects a custom slot for assignment.
  void selectCustomSlot(String slotId) {
    emit(state.copyWith(selectedCustomSlotId: slotId, clearFailure: true));
  }

  /// Clears the selection.
  void clearSelection() {
    emit(
      state.copyWith(clearSelectedSeat: true, clearSelectedCustomSlot: true),
    );
  }

  /// Assigns a membership to a student with slot.
  /// Supports both legacy slots and custom slots.
  /// Supports partial payments via paymentBreakdown.
  /// Supports custom start date and duration.
  Future<void> assign({
    required String studentPhone,
    String? studentName,
    required DateTime expiryDate,
    required MembershipPlan plan,
    PaymentMode? paymentMethod,
    bool markCashReceived = false,
    PaymentBreakdown? paymentBreakdown,
    DateTime? startDate,
    int? customDurationDays,
    int? customDurationMonths,
    String? excludeMembershipId,
    DateTime? paymentReceivedDate,
  }) async {
    if (_libraryId == null ||
        state.selectedSeatId == null ||
        _ownerId == null) {
      return;
    }

    // Must have custom slot selected
    if (state.selectedCustomSlotId == null) {
      return;
    }

    emit(
      state.copyWith(
        status: MembershipAssignmentStatus.submitting,
        clearFailure: true,
      ),
    );

    // Validate seat limit before assignment
    final seatLimitResult = await validateSeatLimit(
      ValidateSeatLimitParams(ownerId: _ownerId!),
    );

    if (seatLimitResult.isLeft()) {
      emit(
        state.copyWith(
          status: MembershipAssignmentStatus.error,
          failure: seatLimitResult.fold((f) => f, (_) => null),
        ),
      );
      return;
    }

    final membershipId = DateTime.now().millisecondsSinceEpoch.toString();

    // Use custom slot assignment
    final result = await assignMembershipWithCustomSlot(
      AssignMembershipWithCustomSlotParams(
        membershipId: membershipId,
        libraryId: _libraryId!,
        studentPhone: studentPhone,
        studentName: studentName,
        seatId: state.selectedSeatId!,
        slotId: state.selectedCustomSlotId!,
        expiryDate: expiryDate,
        plan: plan,
        paymentMethod: paymentMethod,
        paymentBreakdown: paymentBreakdown,
        markCashReceived: markCashReceived,
        startDate: startDate,
        customDurationDays: customDurationDays,
        customDurationMonths: customDurationMonths,
        excludeMembershipId: excludeMembershipId,
        paymentReceivedDate: paymentReceivedDate,
      ),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: MembershipAssignmentStatus.error,
          failure: failure,
        ),
      ),
      (membership) {
        // Track successful membership creation
        _trackMembershipCreated(membership, plan);

        // Add new membership to list
        final updatedList = [...state.memberships, membership];
        emit(
          state.copyWith(
            status: MembershipAssignmentStatus.success,
            memberships: updatedList,
            savedMembership: membership,
            clearSelectedSeat: true,
            clearSelectedCustomSlot: true,
          ),
        );
      },
    );
  }

  /// Updates an existing membership (seat or custom slot change).
  Future<void> update({
    required String membershipId,
    String? newSeatId,
    String? newCustomSlotId,
    DateTime? newExpiryDate,
  }) async {
    emit(
      state.copyWith(
        status: MembershipAssignmentStatus.submitting,
        clearFailure: true,
      ),
    );

    final result = await updateMembership(
      UpdateMembershipParams(
        membershipId: membershipId,
        newSeatId: newSeatId,
        newSlot: null, // Legacy slot - not used anymore
        newExpiryDate: newExpiryDate,
      ),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: MembershipAssignmentStatus.error,
          failure: failure,
        ),
      ),
      (membership) {
        // Update membership in list
        final updatedList = state.memberships.map((m) {
          return m.id == membership.id ? membership : m;
        }).toList();

        emit(
          state.copyWith(
            status: MembershipAssignmentStatus.success,
            memberships: updatedList,
            savedMembership: membership,
          ),
        );
      },
    );
  }

  /// Checks if a bed is occupied, regardless of bed group.
  bool isSeatCustomSlotOccupied(String seatId, String slotId) {
    return state.memberships.any(
      (m) => m.assignedSeatId == seatId && m.status == MembershipStatus.active,
    );
  }

  /// Resets to loaded state (for form reset).
  void resetForm() {
    emit(
      state.copyWith(
        status: MembershipAssignmentStatus.loaded,
        clearSelectedSeat: true,
        clearSelectedCustomSlot: true,
        clearFailure: true,
        clearSavedMembership: true,
      ),
    );
  }

  /// Tracks membership creation event.
  void _trackMembershipCreated(Membership membership, MembershipPlan plan) {
    // Calculate amount from payment breakdown or use 0 as placeholder
    final amount = membership.paymentBreakdown?.totalAmount ?? 0.0;

    analyticsService.trackMembershipCreated(
      membershipId: membership.id,
      planType: plan.name,
      duration: _calculateDuration(membership),
      amount: amount,
      additionalParams: {
        'seat_id': membership.assignedSeatId ?? 'none',
        'slot_id': membership.slotId ?? 'none',
        'payment_method': membership.paymentMethod?.name ?? 'none',
        'is_partial_payment': membership.paymentBreakdown != null
            ? 'true'
            : 'false',
        'has_payment_breakdown': membership.paymentBreakdown != null
            ? 'true'
            : 'false',
      },
    );
  }

  /// Calculates membership duration in days.
  String _calculateDuration(Membership membership) {
    final duration = membership.endDate.difference(membership.startDate).inDays;
    return '${duration}d';
  }
}
