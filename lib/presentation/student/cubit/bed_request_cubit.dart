import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/services/membership_notification_service.dart';
import '../../../domain/entities/custom_slot.dart';
import '../../../domain/entities/library.dart';
import '../../../domain/entities/membership.dart';
import '../../../domain/entities/payment.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/repositories/membership_repository.dart';
import '../../../domain/usecases/assign_membership_with_custom_slot.dart';
import '../../../domain/usecases/get_slots_by_library.dart';
import 'bed_request_state.dart';

/// Resident flow for requesting a bed in a PG. Creates a membership with
/// [MembershipStatus.pendingApproval] that the owner approves or rejects.
class BedRequestCubit extends Cubit<BedRequestState> {
  BedRequestCubit({
    required this.assignMembershipWithCustomSlot,
    required this.getSlotsByLibrary,
    required this.membershipRepository,
    required this.notificationService,
  }) : super(const BedRequestState());

  final AssignMembershipWithCustomSlot assignMembershipWithCustomSlot;
  final GetSlotsByLibrary getSlotsByLibrary;
  final MembershipRepository membershipRepository;
  final MembershipNotificationService notificationService;

  late Library _library;
  late User _user;

  /// Allowed stay lengths, in months.
  static const List<int> monthOptions = [1, 3, 6, 12];

  /// Pass [prefetched] when the caller already loaded rooms, beds and the
  /// resident's open request (the QR invite screen) to skip a second round.
  Future<void> load({
    required Library library,
    required User user,
    String? preselectSlotId,
    BedRequestPrefetch? prefetched,
  }) async {
    _library = library;
    _user = user;

    final today = DateTime.now();
    if (prefetched != null) {
      emit(
        BedRequestState(
          status: BedRequestStatus.ready,
          slots: prefetched.slots,
          occupied: prefetched.occupied,
          startDate: DateTime(today.year, today.month, today.day),
          selectedSlotId: preselectSlotId,
          existingRequest: prefetched.existingRequest,
        ),
      );
      return;
    }

    emit(const BedRequestState());

    final slotsFuture = getSlotsByLibrary(
      GetSlotsByLibraryParams(libraryId: library.id, activeOnly: true),
    );
    final occupiedFuture = membershipRepository
        .getActiveAndReservedMembershipsForLibrary(library.id);
    final mineFuture = membershipRepository.getMembershipsByUserId(user.id);

    final slotsResult = await slotsFuture;
    final occupiedResult = await occupiedFuture;
    final mine = (await mineFuture).getOrElse(() => <Membership>[]);
    if (isClosed) return;

    if (slotsResult.isLeft() || occupiedResult.isLeft()) {
      emit(
        const BedRequestState(
          status: BedRequestStatus.error,
          errorMessage: 'Could not load room types. Please try again.',
        ),
      );
      return;
    }

    Membership? existing;
    for (final m in mine) {
      if (m.libraryId == library.id && m.isPendingApproval) {
        existing = m;
        break;
      }
    }

    emit(
      BedRequestState(
        status: BedRequestStatus.ready,
        slots: slotsResult.getOrElse(() => []),
        occupied: occupiedResult.getOrElse(() => []),
        startDate: DateTime(today.year, today.month, today.day),
        selectedSlotId: preselectSlotId,
        existingRequest: existing,
      ),
    );
  }

  void selectSlot(String slotId) {
    if (slotId == state.selectedSlotId) return;
    emit(
      state.copyWith(
        selectedSlotId: slotId,
        clearSelectedBed: true,
        clearError: true,
      ),
    );
  }

  void selectBed(String bed) =>
      emit(state.copyWith(selectedBed: bed, clearError: true));

  void setMonths(int months) => emit(state.copyWith(months: months));

  void setStartDate(DateTime date) => emit(
    state.copyWith(startDate: DateTime(date.year, date.month, date.day)),
  );

  /// [paymentMethod] is how the resident will pay (cash at the PG or UPI to
  /// the owner); [upiTransactionId] is the optional UTR after a UPI payment.
  Future<void> submit({
    required String name,
    required String phone,
    PaymentMode paymentMethod = PaymentMode.cash,
    String? upiTransactionId,
  }) async {
    final slot = state.selectedSlot;
    final bed = state.selectedBed;
    final start = state.startDate;
    if (slot == null || bed == null || start == null) return;
    if (state.status == BedRequestStatus.submitting) return;

    emit(state.copyWith(status: BedRequestStatus.submitting, clearError: true));

    final months = state.months;
    final plan = switch (months) {
      3 => MembershipPlan.quarterly,
      12 => MembershipPlan.yearly,
      _ => MembershipPlan.monthly,
    };
    final end = start.add(
      Duration(days: months == 12 ? 365 : (months == 3 ? 90 : months * 30)),
    );
    final membershipId = DateTime.now().millisecondsSinceEpoch.toString();

    final result = await assignMembershipWithCustomSlot(
      AssignMembershipWithCustomSlotParams(
        membershipId: membershipId,
        libraryId: _library.id,
        studentPhone: phone,
        studentName: name,
        seatId: bed,
        slotId: slot.id,
        expiryDate: end,
        plan: plan,
        startDate: start,
        customDurationMonths: (months == 1 || months == 3 || months == 12)
            ? null
            : months,
        statusOverride: MembershipStatus.pendingApproval,
        paymentMethod: paymentMethod,
        upiTransactionId:
            paymentMethod == PaymentMode.upi &&
                (upiTransactionId?.trim().isNotEmpty ?? false)
            ? upiTransactionId!.trim()
            : null,
      ),
    );
    if (isClosed) return;

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: BedRequestStatus.ready,
          errorMessage: failure.message ?? 'Could not submit your request.',
        ),
      ),
      (membership) {
        emit(state.copyWith(status: BedRequestStatus.submitted));
        notificationService.notifyOwnerSeatRequestSubmitted(
          ownerId: _library.ownerId,
          studentName: name.isNotEmpty ? name : _user.name,
          libraryName: _library.name,
          seatId: bed,
          slotName: slot.name,
          membershipId: membership.id,
        );
      },
    );
  }
}

/// Rooms, occupied beds and the resident's open request, already loaded by
/// the screen that opens the bed request flow.
class BedRequestPrefetch {
  const BedRequestPrefetch({
    required this.slots,
    required this.occupied,
    this.existingRequest,
  });

  final List<CustomSlot> slots;
  final List<Membership> occupied;
  final Membership? existingRequest;
}
