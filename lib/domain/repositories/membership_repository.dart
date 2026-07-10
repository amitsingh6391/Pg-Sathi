import 'package:dartz/dartz.dart';

import '../core/failure.dart';
import '../entities/membership.dart';
import '../entities/slot.dart';

/// Repository interface for Membership aggregate.
abstract class MembershipRepository {
  /// Creates a new membership.
  Future<Either<Failure, Membership>> createMembership(Membership membership);

  /// Retrieves a membership by ID.
  Future<Either<Failure, Membership>> getMembershipById(String membershipId);

  /// Retrieves active or pending membership for a user in a library.
  Future<Either<Failure, Membership?>> getActiveMembershipByUserAndLibrary({
    required String userId,
    required String libraryId,
  });

  /// Retrieves active membership for a user in a library for a specific slot.
  /// Used for attendance check-in/check-out validation.
  Future<Either<Failure, Membership?>> getActiveMembershipByUserLibraryAndSlot({
    required String userId,
    required String libraryId,
    required Slot slot,
  });

  /// Retrieves all active memberships for a user in a library (both slots).
  Future<Either<Failure, List<Membership>>>
  getActiveMembershipsByUserAndLibrary({
    required String userId,
    required String libraryId,
  });

  /// Retrieves all memberships for a user.
  Future<Either<Failure, List<Membership>>> getMembershipsByUserId(
    String userId,
  );

  /// Retrieves all memberships for a library.
  Future<Either<Failure, List<Membership>>> getMembershipsByLibraryId(
    String libraryId,
  );

  /// Retrieves all active memberships for a library.
  Future<Either<Failure, List<Membership>>> getActiveMembershipsForLibrary(
    String libraryId,
  );

  /// Retrieves all active AND reserved (pendingPayment) memberships for a library.
  /// Used for owner dashboard to show complete seat status.
  Future<Either<Failure, List<Membership>>>
  getActiveAndReservedMembershipsForLibrary(String libraryId);

  /// Retrieves expired memberships for a library that still have assigned seats.
  /// Used to show expired seats that can be reassigned.
  Future<Either<Failure, List<Membership>>>
  getExpiredMembershipsWithSeatsForLibrary({
    required String libraryId,
    required DateTime currentDate,
  });

  /// Checks if a bed is occupied or reserved.
  /// Returns true if there's an active OR pendingPayment membership.
  Future<Either<Failure, bool>> isSeatSlotOccupied({
    required String libraryId,
    required String seatId,
    required Slot slot,
  });

  /// Gets membership by seat ID and slot (if active or pending).
  Future<Either<Failure, Membership?>> getMembershipBySeatAndSlot({
    required String libraryId,
    required String seatId,
    required Slot slot,
  });

  /// Gets all active memberships for a specific seat (both slots).
  Future<Either<Failure, List<Membership>>> getMembershipsBySeatId({
    required String libraryId,
    required String seatId,
  });

  /// Updates membership information.
  Future<Either<Failure, Membership>> updateMembership(Membership membership);

  /// Retrieves all expired memberships that need status update.
  Future<Either<Failure, List<Membership>>> getExpiredMemberships(
    DateTime currentDate,
  );

  /// Retrieves all pending payment memberships that have expired reservations.
  Future<Either<Failure, List<Membership>>> getExpiredReservations(
    DateTime currentTime,
    Duration reservationDuration,
  );

  /// Batch updates membership statuses.
  Future<Either<Failure, void>> batchUpdateMembershipStatus(
    List<Membership> memberships,
  );

  /// Retrieves active memberships expiring within the specified threshold.
  /// Used for sending expiry reminders.
  Future<Either<Failure, List<Membership>>> getExpiringMemberships({
    required String libraryId,
    required DateTime currentDate,
    required int daysThreshold,
  });

  /// Retrieves all unregistered memberships (where userId is null) for a phone number.
  /// Used to sync memberships when student logs in.
  Future<Either<Failure, List<Membership>>> getUnregisteredMembershipsByPhone(
    String phoneNumber,
  );

  /// Retrieves all memberships (registered and unregistered) for a phone number.
  /// Used to find all memberships linked to a phone number.
  Future<Either<Failure, List<Membership>>> getMembershipsByPhoneNumber(
    String phoneNumber,
  );

  /// Retrieves all pending approval memberships for a library.
  /// These are memberships with pendingPayment status and paymentStatus = pending
  /// where paymentMethod is cash or upi.
  Future<Either<Failure, List<Membership>>> getPendingApprovalMemberships(
    String libraryId,
  );

  /// Batch updates memberships to link them to a user ID.
  /// Used when student logs in and unregistered memberships need to be linked.
  Future<Either<Failure, void>> batchLinkMembershipsToUser({
    required String phoneNumber,
    required String userId,
  });

  /// Deletes a membership by ID.
  /// Used for admin cleanup operations.
  Future<Either<Failure, void>> deleteMembership(String membershipId);

  /// Gets active membership counts per library in a single bulk query.
  /// Returns a map of libraryId → active membership count.
  /// Used by admin screens instead of N individual per-library queries.
  Future<Either<Failure, Map<String, int>>>
  getActiveMembershipCountsByLibrary();
}
