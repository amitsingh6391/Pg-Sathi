import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../core/core.dart';
import '../entities/membership.dart';
import '../entities/slot.dart';
import '../failures/membership_failures.dart';
import '../failures/seat_failures.dart';
import '../repositories/invoice_repository.dart';
import '../repositories/membership_repository.dart';
import '../repositories/slot_repository.dart';

/// Use case for updating membership (bed or stay details).
/// Validates bed availability before update.
/// Also updates associated invoices when dates or seat change.
class UpdateMembership implements UseCase<Membership, UpdateMembershipParams> {
  const UpdateMembership({
    required this.membershipRepository,
    required this.invoiceRepository,
    required this.slotRepository,
  });

  final MembershipRepository membershipRepository;
  final InvoiceRepository invoiceRepository;
  final SlotRepository slotRepository;

  @override
  Future<Either<Failure, Membership>> call(
    UpdateMembershipParams params,
  ) async {
    // Validate input
    final validationError = _validate(params);
    if (validationError != null) {
      return Left(validationError);
    }

    // Get existing membership
    final existingResult = await membershipRepository.getMembershipById(
      params.membershipId,
    );

    return existingResult.fold((failure) => Left(failure), (existing) async {
      if (!existing.isEditable) {
        return Left(
          MembershipNotActiveFailure(
            message: _notEditableMessage(existing.status),
          ),
        );
      }

      final newSeatId = params.newSeatId ?? existing.assignedSeatId;
      final newSlot = params.newSlot ?? existing.slot;

      // If bed is changing, check availability regardless of slot/time.
      if (newSeatId != existing.assignedSeatId && newSeatId != null) {
        final seatResult = await membershipRepository.getMembershipsBySeatId(
          libraryId: existing.libraryId,
          seatId: newSeatId,
        );

        if (seatResult.isLeft()) {
          return Left(seatResult.fold((l) => l, (r) => throw Error()));
        }

        final isOccupied = seatResult
            .getOrElse(() => const [])
            .any((m) => m.id != existing.id);

        if (isOccupied) {
          return Left(
            SeatAlreadyOccupiedFailure(
              message: 'Bed is already occupied by another tenant',
            ),
          );
        }
      }

      // Validate dates if both are being updated
      final newStartDate = params.newStartDate ?? existing.startDate;
      final newEndDate = params.newExpiryDate ?? existing.endDate;

      if (newEndDate.isBefore(newStartDate)) {
        return const Left(
          InvalidExpiryDateFailure(
            message: 'End date must be after start date',
          ),
        );
      }

      // Update membership
      final updated = Membership(
        id: existing.id,
        userId: existing.userId,
        studentName: params.newStudentName ?? existing.studentName,
        libraryId: existing.libraryId,
        plan: existing.plan,
        startDate: newStartDate,
        endDate: newEndDate,
        status: existing.status,
        phoneNumber: existing.phoneNumber,
        assignedSeatId: newSeatId,
        slot: newSlot,
        slotId: existing.slotId, // Preserve custom slot ID
        createdAt: existing.createdAt,
        paymentMethod: existing.paymentMethod,
        paymentStatus: existing.paymentStatus,
        paymentBreakdown:
            existing.paymentBreakdown, // Preserve payment breakdown
        assignedByOwner: existing.assignedByOwner,
        customDurationDays: existing.customDurationDays,
        customDurationMonths: existing.customDurationMonths,
      );

      final updateResult = await membershipRepository.updateMembership(updated);

      // Update associated invoices if dates or seat changed
      final datesChanged =
          newEndDate != existing.endDate || newStartDate != existing.startDate;
      final seatChanged = newSeatId != existing.assignedSeatId;

      if ((datesChanged || seatChanged) && updateResult.isRight()) {
        // Update invoices asynchronously (don't block on failures)
        _updateAssociatedInvoices(
          membershipId: existing.id,
          newEndDate: newEndDate,
          newSeatId: newSeatId,
          slotId: existing.slotId,
          legacySlot: newSlot,
          libraryId: existing.libraryId,
        ).catchError((_) {
          // Silently handle errors - invoice update is not critical
        });
      }

      return updateResult;
    });
  }

  /// Updates all invoices associated with a membership when dates or seat change.
  Future<void> _updateAssociatedInvoices({
    required String membershipId,
    required DateTime newEndDate,
    required String? newSeatId,
    required String? slotId,
    required Slot? legacySlot,
    required String libraryId,
  }) async {
    // Get all invoices for this membership
    final invoicesResult = await invoiceRepository.getInvoicesByMembershipIds([
      membershipId,
    ]);

    return invoicesResult.fold(
      (_) async {
        // Silently fail - invoice update is not critical for membership update
      },
      (invoices) async {
        if (invoices.isEmpty) return;

        // Get session timing if slot info is available
        String? sessionTiming;
        if (slotId != null && slotId.isNotEmpty) {
          final slotResult = await slotRepository.getSlotById(
            libraryId,
            slotId,
          );
          slotResult.fold((_) {}, (slot) {
            if (slot != null) {
              sessionTiming = slot.displayTime;
            }
          });
        } else if (legacySlot != null) {
          switch (legacySlot) {
            case Slot.morning:
              sessionTiming = '6:00 AM – 2:00 PM';
              break;
            case Slot.evening:
              sessionTiming = '2:00 PM – 10:00 PM';
              break;
          }
        }

        // Update each invoice
        for (final invoice in invoices) {
          final updatedInvoice = invoice.copyWith(
            expiryDate: newEndDate,
            seatNumber: newSeatId ?? invoice.seatNumber,
            sessionTiming: sessionTiming ?? invoice.sessionTiming,
          );

          // Update invoice (failures are logged but don't block membership update)
          await invoiceRepository.updateInvoice(updatedInvoice);
        }
      },
    );
  }

  /// Builds a user-facing message describing why the membership can't be
  /// edited. Speaks in terms the owner understands rather than the generic
  /// "inactive" label, which previously confused owners trying to edit
  /// memberships still awaiting payment approval.
  String _notEditableMessage(MembershipStatus status) {
    switch (status) {
      case MembershipStatus.expired:
        return 'Cannot edit an expired membership. Renew it instead.';
      case MembershipStatus.cancelled:
        return 'Cannot edit a cancelled membership.';
      case MembershipStatus.suspended:
        return 'Cannot edit a suspended membership.';
      case MembershipStatus.active:
      case MembershipStatus.pendingPayment:
        // Defensive: editable states should never reach this branch.
        return 'Cannot edit this membership.';
    }
  }

  Failure? _validate(UpdateMembershipParams params) {
    if (params.membershipId.trim().isEmpty) {
      return const InvalidMembershipDataFailure(
        message: 'Membership ID is required',
      );
    }
    if (params.newStartDate != null &&
        params.newStartDate!.isBefore(DateTime(2020))) {
      return const InvalidMembershipDataFailure(
        message: 'Start date must be valid',
      );
    }
    if (params.newExpiryDate != null &&
        params.newStartDate != null &&
        params.newExpiryDate!.isBefore(params.newStartDate!)) {
      return const InvalidExpiryDateFailure(
        message: 'End date must be after start date',
      );
    }
    return null;
  }
}

/// Parameters for UpdateMembership use case.
class UpdateMembershipParams extends Equatable {
  const UpdateMembershipParams({
    required this.membershipId,
    this.newSeatId,
    this.newSlot,
    this.newStartDate,
    this.newExpiryDate,
    this.newStudentName,
  });

  final String membershipId;
  final String? newSeatId;
  final Slot? newSlot;
  final DateTime? newStartDate;
  final DateTime? newExpiryDate;
  final String? newStudentName;

  @override
  List<Object?> get props => [
    membershipId,
    newSeatId,
    newSlot,
    newStartDate,
    newExpiryDate,
    newStudentName,
  ];
}
