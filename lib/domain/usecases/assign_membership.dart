import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../core/core.dart';
import '../entities/membership.dart';
import '../entities/payment.dart';
import '../entities/slot.dart';
import '../failures/membership_failures.dart';
import '../failures/seat_failures.dart';
import '../repositories/membership_repository.dart';
import '../repositories/user_repository.dart';

/// Use case for assigning a bed to a tenant.
/// Supports both registered users and unregistered members (phone-only).
/// A bed can have only one active or pending stay.
class AssignMembership implements UseCase<Membership, AssignMembershipParams> {
  const AssignMembership({
    required this.membershipRepository,
    required this.userRepository,
  });

  final MembershipRepository membershipRepository;
  final UserRepository userRepository;

  @override
  Future<Either<Failure, Membership>> call(
    AssignMembershipParams params,
  ) async {
    // Validate input
    final validationError = _validate(params);
    if (validationError != null) {
      return Left(validationError);
    }

    // Try to find existing student by phone (optional - can assign without login)
    final studentResult = await userRepository.getUserByPhone(
      params.studentPhone,
    );

    String? userId;
    if (studentResult.isRight()) {
      final student = studentResult.getOrElse(() => null);
      userId = student?.id;
    }

    // Check for existing memberships by phone number (works for both registered and unregistered)
    final existingByPhoneResult = await membershipRepository
        .getMembershipsByPhoneNumber(params.studentPhone);

    return existingByPhoneResult.fold((failure) => Left(failure), (
      existingMemberships,
    ) async {
      // Removed validation: Allow same phone number to have multiple seats in the same slot
      // This enables siblings sharing a phone number to have separate seats

      // Check if bed is already occupied/reserved.
      final seatResult = await membershipRepository.isSeatSlotOccupied(
        libraryId: params.libraryId,
        seatId: params.seatId,
        slot: params.slot,
      );

      return seatResult.fold((failure) => Left(failure), (isOccupied) async {
        if (isOccupied) {
          return Left(
            SeatAlreadyOccupiedFailure(message: 'This bed is already occupied'),
          );
        }

        // Calculate start date (use provided or default to now)
        final effectiveStartDate = params.startDate ?? DateTime.now();

        // Check if membership is already expired (end date has passed)
        final now = DateTime.now();
        final todayOnly = DateTime(now.year, now.month, now.day);
        final endDateOnly = DateTime(
          params.expiryDate.year,
          params.expiryDate.month,
          params.expiryDate.day,
        );
        final isAlreadyExpired = todayOnly.isAfter(endDateOnly);

        // Determine payment status and membership status
        final paymentStatus = params.markCashReceived
            ? MembershipPaymentStatus.markedPaid
            : MembershipPaymentStatus.pending;

        // If membership is already expired, mark as expired immediately
        // This prevents expired memberships from showing as occupied
        final membershipStatus = isAlreadyExpired
            ? MembershipStatus.expired
            : (params.markCashReceived
                  ? MembershipStatus.active
                  : MembershipStatus.pendingPayment);

        // Create membership - supports both registered and unregistered users
        final membership = Membership(
          id: params.membershipId,
          userId: userId, // null for unregistered members
          studentName: userId == null
              ? params.studentName
              : null, // Only store name for unregistered
          libraryId: params.libraryId,
          plan: params.plan,
          startDate: effectiveStartDate,
          endDate: params.expiryDate,
          status: membershipStatus,
          phoneNumber: params.studentPhone,
          assignedSeatId: params.seatId,
          slot: params.slot,
          createdAt: DateTime.now(),
          paymentMethod: params.paymentMethod,
          paymentStatus: paymentStatus,
          assignedByOwner: userId == null, // true if student not registered
          customDurationDays: params.customDurationDays,
          customDurationMonths: params.customDurationMonths,
        );

        return membershipRepository.createMembership(membership);
      });
    });
  }

  Failure? _validate(AssignMembershipParams params) {
    if (params.studentPhone.trim().isEmpty) {
      return const InvalidMembershipDataFailure(
        message: 'Student phone number is required',
      );
    }
    if (params.seatId.trim().isEmpty) {
      return const InvalidMembershipDataFailure(
        message: 'Seat must be selected',
      );
    }
    // Validate expiry date relative to start date
    final effectiveStartDate = params.startDate ?? DateTime.now();
    if (params.expiryDate.isBefore(effectiveStartDate)) {
      return const InvalidExpiryDateFailure(
        message: 'Expiry date must be after start date',
      );
    }
    return null;
  }
}

/// Parameters for AssignMembership use case.
class AssignMembershipParams extends Equatable {
  const AssignMembershipParams({
    required this.membershipId,
    required this.libraryId,
    required this.studentPhone,
    required this.seatId,
    required this.slot,
    required this.expiryDate,
    required this.plan,
    this.studentName,
    this.paymentMethod,
    this.markCashReceived = false,
    this.startDate,
    this.customDurationDays,
    this.customDurationMonths,
  });

  final String membershipId;
  final String libraryId;
  final String studentPhone;
  final String? studentName;
  final String seatId;
  final Slot slot;
  final DateTime expiryDate;
  final MembershipPlan plan;

  /// Custom start date (optional, defaults to current date if not provided).
  /// Allows past dates for retroactive memberships.
  final DateTime? startDate;

  /// Custom duration in days (optional, overrides plan duration if set).
  final int? customDurationDays;

  /// Custom duration in months (optional, overrides plan duration if set).
  final int? customDurationMonths;

  /// Payment method chosen during assignment (cash/upi).
  final PaymentMode? paymentMethod;

  /// Whether cash payment is marked as received immediately.
  /// If true, membership becomes active immediately.
  final bool markCashReceived;

  @override
  List<Object?> get props => [
    membershipId,
    libraryId,
    studentPhone,
    studentName,
    seatId,
    slot,
    expiryDate,
    plan,
    paymentMethod,
    markCashReceived,
    startDate,
    customDurationDays,
    customDurationMonths,
  ];
}
