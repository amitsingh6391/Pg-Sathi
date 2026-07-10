import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../core/services/analytics_service.dart';
import '../../data/services/membership_notification_service.dart';
import '../core/core.dart';
import '../entities/membership.dart';
import '../entities/slot.dart';
import '../failures/membership_failures.dart';
import '../failures/seat_failures.dart';
import '../repositories/library_repository.dart';
import '../repositories/membership_repository.dart';
import '../repositories/seat_repository.dart';
import '../repositories/slot_repository.dart';

/// Use case for reassigning a membership to a different bed.
/// Validates new bed availability before reassignment.
/// Sends push notification to student when seat is changed.
class ReassignSeat implements UseCase<Membership, ReassignSeatParams> {
  const ReassignSeat({
    required this.membershipRepository,
    required this.libraryRepository,
    required this.seatRepository,
    required this.slotRepository,
    required this.analyticsService,
    this.notificationService,
  });

  final MembershipRepository membershipRepository;
  final LibraryRepository libraryRepository;
  final SeatRepository seatRepository;
  final SlotRepository slotRepository;
  final AnalyticsService analyticsService;
  final MembershipNotificationService? notificationService;

  @override
  Future<Either<Failure, Membership>> call(ReassignSeatParams params) async {
    // Validate input
    if (params.membershipId.trim().isEmpty) {
      return const Left(
        InvalidMembershipDataFailure(message: 'Membership ID is required'),
      );
    }
    if (params.newSeatId.trim().isEmpty) {
      return const Left(
        InvalidMembershipDataFailure(message: 'New seat must be selected'),
      );
    }

    // Get existing membership
    final existingResult = await membershipRepository.getMembershipById(
      params.membershipId,
    );

    return existingResult.fold((failure) => Left(failure), (existing) async {
      // Verify membership is active
      if (existing.status != MembershipStatus.active) {
        return const Left(
          MembershipNotActiveFailure(
            message: 'Cannot reassign an inactive membership',
          ),
        );
      }

      final newSlot = params.newSlot ?? existing.slot;

      // Check if same bed and slot
      if (existing.assignedSeatId == params.newSeatId &&
          existing.slot == newSlot) {
        return Right(existing); // No change needed
      }

      // Check if new bed is available regardless of slot/time.
      if (existing.assignedSeatId != params.newSeatId) {
        final seatResult = await membershipRepository.getMembershipsBySeatId(
          libraryId: existing.libraryId,
          seatId: params.newSeatId,
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

      // Store old seat ID for notification
      final oldSeatId = existing.assignedSeatId;

      // Update membership with new seat and slot
      final updated = Membership(
        id: existing.id,
        userId: existing.userId,
        libraryId: existing.libraryId,
        plan: existing.plan,
        startDate: existing.startDate,
        endDate: existing.endDate,
        status: existing.status,
        phoneNumber: existing.phoneNumber,
        assignedSeatId: params.newSeatId,
        slot: newSlot,
        createdAt: existing.createdAt,
        paymentMethod: existing.paymentMethod,
        paymentStatus: existing.paymentStatus,
        assignedByOwner: existing.assignedByOwner,
      );

      final updateResult = await membershipRepository.updateMembership(updated);

      // Track seat analytics
      if (updateResult.isRight() && oldSeatId != params.newSeatId) {
        // Get seat numbers for analytics
        final oldSeatResult = oldSeatId != null
            ? await seatRepository.getSeatById(oldSeatId)
            : null;
        final newSeatResult = await seatRepository.getSeatById(
          params.newSeatId,
        );

        final oldSeatNumber =
            oldSeatResult?.fold((l) => null, (seat) => seat.seatNumber) ??
            'Unknown';
        final newSeatNumber = newSeatResult.fold(
          (l) => 'Unknown',
          (seat) => seat.seatNumber,
        );

        // Track unassignment from old seat
        if (oldSeatId != null && updated.userId != null) {
          await analyticsService.trackSeatUnassigned(
            seatNumber: oldSeatNumber,
            studentId: updated.userId!,
          );
        }

        // Track assignment to new seat
        if (updated.userId != null) {
          await analyticsService.trackSeatAssigned(
            seatNumber: newSeatNumber,
            studentId: updated.userId!,
          );
        }
      }

      // Send notification to student (fire-and-forget)
      if (updateResult.isRight() &&
          notificationService != null &&
          existing.userId != null &&
          oldSeatId != params.newSeatId) {
        _sendStudentNotification(
          updateResult.getOrElse(() => throw Error()),
          oldSeatId,
          newSlot,
        );
      }

      return updateResult;
    });
  }

  /// Sends notification to student about seat change.
  Future<void> _sendStudentNotification(
    Membership membership,
    String? oldSeatId,
    Slot? slot,
  ) async {
    try {
      if (membership.userId == null) return;

      // Get library name
      final libraryResult = await libraryRepository.getLibraryById(
        membership.libraryId,
      );
      if (libraryResult.isLeft()) return;

      final library = libraryResult.getOrElse(() => null);
      if (library == null) return;

      // Get old seat number
      String oldSeatNumber = 'Unknown';
      if (oldSeatId != null) {
        final oldSeatResult = await seatRepository.getSeatById(oldSeatId);
        oldSeatResult.fold((_) {}, (seat) {
          oldSeatNumber = seat.seatNumber;
        });
      }

      // Get new seat number
      String newSeatNumber = 'Unknown';
      if (membership.assignedSeatId != null) {
        final newSeatResult = await seatRepository.getSeatById(
          membership.assignedSeatId!,
        );
        newSeatResult.fold((_) {}, (seat) {
          newSeatNumber = seat.seatNumber;
        });
      }

      // Get slot name
      String slotName = slot?.displayName ?? 'Unknown';
      if (membership.slotId != null) {
        final slotResult = await slotRepository.getSlotById(
          membership.libraryId,
          membership.slotId!,
        );
        slotResult.fold((_) {}, (customSlot) {
          if (customSlot != null) {
            slotName = customSlot.name;
          }
        });
      }

      await notificationService?.notifyStudentSeatChanged(
        studentId: membership.userId!,
        libraryName: library.name,
        oldSeatNumber: oldSeatNumber,
        newSeatNumber: newSeatNumber,
        slotName: slotName,
        membershipId: membership.id,
      );
    } catch (_) {
      // Silent failure - notification is non-critical
    }
  }
}

/// Parameters for ReassignSeat use case.
class ReassignSeatParams extends Equatable {
  const ReassignSeatParams({
    required this.membershipId,
    required this.newSeatId,
    this.newSlot,
  });

  final String membershipId;
  final String newSeatId;
  final Slot? newSlot; // If null, keeps existing slot

  @override
  List<Object?> get props => [membershipId, newSeatId, newSlot];
}
