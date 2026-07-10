import 'dart:developer';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../data/services/membership_notification_service.dart';
import '../core/core.dart';
import '../entities/custom_slot.dart';
import '../entities/membership.dart';
import '../entities/payment.dart';
import '../entities/payment_breakdown.dart';
import '../failures/membership_failures.dart';
import '../failures/seat_failures.dart';
import '../repositories/library_repository.dart';
import '../repositories/membership_repository.dart';
import '../repositories/payment_repository.dart';
import '../repositories/seat_repository.dart';
import '../repositories/slot_repository.dart';
import '../repositories/user_repository.dart';
import 'generate_invoice.dart';
import '../repositories/whatsapp_notification_repository.dart';

/// Use case for assigning a membership with custom slot support and partial payments.
/// Supports both registered users and unregistered members (phone-only).
/// A bed can have only one active or pending stay.
/// When markCashReceived is true, creates payment record and generates invoice.
/// Sends push notification to student when seat is assigned.
class AssignMembershipWithCustomSlot
    implements UseCase<Membership, AssignMembershipWithCustomSlotParams> {
  const AssignMembershipWithCustomSlot({
    required this.membershipRepository,
    required this.slotRepository,
    required this.userRepository,
    required this.libraryRepository,
    required this.paymentRepository,
    required this.seatRepository,
    this.generateInvoice,
    this.notificationService,
    this.whatsAppNotificationRepository,
  });

  final MembershipRepository membershipRepository;
  final SlotRepository slotRepository;
  final UserRepository userRepository;
  final LibraryRepository libraryRepository;
  final PaymentRepository paymentRepository;
  final SeatRepository seatRepository;
  final GenerateInvoice? generateInvoice;
  final MembershipNotificationService? notificationService;
  final WhatsAppNotificationRepository? whatsAppNotificationRepository;

  @override
  Future<Either<Failure, Membership>> call(
    AssignMembershipWithCustomSlotParams params,
  ) async {
    // Validate input
    final validationError = _validate(params);
    if (validationError != null) {
      return Left(validationError);
    }

    // Verify custom slot exists and is active
    final slotResult = await slotRepository.getSlotById(
      params.libraryId,
      params.slotId,
    );

    return slotResult.fold((failure) => Left(failure), (slot) async {
      if (slot == null) {
        return const Left(
          InvalidMembershipDataFailure(message: 'Custom slot not found'),
        );
      }

      if (!slot.isActive) {
        return const Left(
          InvalidMembershipDataFailure(message: 'Custom slot is not active'),
        );
      }

      // Try to find existing student by phone
      final studentResult = await userRepository.getUserByPhone(
        params.studentPhone,
      );

      String? userId;
      if (studentResult.isRight()) {
        final student = studentResult.getOrElse(() => null);
        userId = student?.id;
      }

      // Check for existing memberships by phone number
      final existingByPhoneResult = await membershipRepository
          .getMembershipsByPhoneNumber(params.studentPhone);

      return existingByPhoneResult.fold((failure) => Left(failure), (
        existingMemberships,
      ) async {
        // Removed validation: Allow same phone number to have multiple seats in the same slot
        // This enables siblings sharing a phone number to have separate seats
        // Calculate effective start date for new membership
        final effectiveStartDate = params.startDate ?? DateTime.now();

        // Check if bed is already occupied/reserved.
        // Use getActiveAndReservedMembershipsForLibrary to exclude expired memberships
        final libraryMembershipsResult = await membershipRepository
            .getActiveAndReservedMembershipsForLibrary(params.libraryId);

        return libraryMembershipsResult.fold((failure) => Left(failure), (
          libraryMemberships,
        ) async {
          // Allow extension if new start date is after current membership's end date
          final conflictingSeatMembership = libraryMemberships.firstWhere(
            (m) =>
                m.assignedSeatId == params.seatId &&
                (m.status == MembershipStatus.active ||
                    m.status == MembershipStatus.pendingPayment) &&
                effectiveStartDate.isBefore(m.endDate),
            orElse: () => Membership(
              id: '',
              libraryId: '',
              plan: MembershipPlan.monthly,
              startDate: DateTime.now(),
              endDate: DateTime.now(),
              status: MembershipStatus.expired,
              phoneNumber: '',
            ),
          );

          if (conflictingSeatMembership.id.isNotEmpty) {
            final endDateStr = conflictingSeatMembership.endDate
                .toString()
                .split(' ')[0];
            return Left(
              SeatAlreadyOccupiedFailure(
                message:
                    'This bed is already occupied until $endDateStr. Please select a different bed or set a start date after the current stay ends.',
              ),
            );
          }

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
          // For partial payments: membership becomes active immediately since partial payment is recorded
          // The paymentStatus remains pending if there's remaining balance
          final hasPartialPayment =
              params.paymentBreakdown != null &&
              params.paymentBreakdown!.amountPaid > 0;
          final hasRemainingBalance =
              params.paymentBreakdown != null &&
              params.paymentBreakdown!.amountRemaining > 0;

          final paymentStatus = params.markCashReceived
              ? MembershipPaymentStatus.markedPaid
              : (hasPartialPayment && hasRemainingBalance
                    ? MembershipPaymentStatus
                          .pending // Partial payment with remaining balance
                    : (hasPartialPayment
                          ? MembershipPaymentStatus
                                .markedPaid // Partial payment covering full amount
                          : MembershipPaymentStatus.pending)); // No payment yet

          // If membership is already expired, mark as expired immediately
          // This prevents expired memberships from showing as occupied
          // For partial payments, activate membership immediately since payment is being recorded
          final membershipStatus = isAlreadyExpired
              ? MembershipStatus.expired
              : (params.markCashReceived || hasPartialPayment
                    ? MembershipStatus.active
                    : MembershipStatus.pendingPayment);

          // Create membership with custom slot and payment breakdown
          // Use effectiveStartDate calculated above
          final membership = Membership(
            id: params.membershipId,
            userId: userId,
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
            slot: null, // No legacy slot enum
            slotId: params.slotId,
            createdAt: DateTime.now(),
            paymentMethod: params.paymentMethod,
            paymentStatus: paymentStatus,
            paymentBreakdown: params.paymentBreakdown,
            assignedByOwner: userId == null,
            customDurationDays: params.customDurationDays,
            customDurationMonths: params.customDurationMonths,
          );

          final createMembershipResult = await membershipRepository
              .createMembership(membership);

          return createMembershipResult.fold((failure) => Left(failure), (
            savedMembership,
          ) async {
            // If reassigning from an expired membership, clear the old one's seat
            // so it no longer appears in the Expired tab.
            if (params.excludeMembershipId != null) {
              final oldResult = await membershipRepository.getMembershipById(
                params.excludeMembershipId!,
              );
              oldResult.fold((_) {}, (oldMembership) async {
                if (oldMembership.status == MembershipStatus.expired ||
                    oldMembership.status == MembershipStatus.cancelled) {
                  final cleared = oldMembership.clearSeat();
                  await membershipRepository.updateMembership(cleared);
                }
              });
            }

            // Check if we need to create payment record and invoice
            // This happens in two cases:
            // 1. Payment is marked as received (markCashReceived = true)
            // 2. Partial payment is marked (paymentBreakdown exists with amountPaid > 0)
            //    For partial payments, create approved payment record immediately
            //    so it shows in revenue/transactions but NOT in pending approvals
            final hasPartialPayment =
                params.paymentBreakdown != null &&
                params.paymentBreakdown!.amountPaid > 0;
            final shouldCreatePayment =
                (params.markCashReceived &&
                    (params.paymentMethod == PaymentMode.cash ||
                        params.paymentMethod == PaymentMode.upi)) ||
                hasPartialPayment;

            if (shouldCreatePayment) {
              // Get library to get ownerId
              final libraryResult = await libraryRepository.getLibraryById(
                params.libraryId,
              );

              return libraryResult.fold((failure) => Left(failure), (
                library,
              ) async {
                if (library == null) {
                  return const Left(
                    InvalidMembershipDataFailure(message: 'Library not found'),
                  );
                }

                // Calculate payment amount for this transaction
                // For partial payments, use amountPaid (not totalAmount)
                // This ensures invoice and payment record reflect actual amount paid
                // IMPORTANT: When markCashReceived is true with discount but no partial payment,
                // the amountPaid in paymentBreakdown will be 0, but we need to use the full
                // discounted amount (totalAmount) for the invoice
                final paymentAmount = params.paymentBreakdown != null
                    ? (params.markCashReceived &&
                              params.paymentBreakdown!.amountPaid == 0
                          ? params
                                .paymentBreakdown!
                                .totalAmount // Full discounted amount
                          : params
                                .paymentBreakdown!
                                .amountPaid) // Partial payment amount
                    : _calculateFullPaymentAmount(savedMembership, slot.price);

                // Create and approve payment record
                // Payment amount should reflect actual amount paid in this transaction
                final createdPayment = params.paymentMethod == PaymentMode.upi
                    ? Payment.createUpiPayment(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        membershipId: savedMembership.id,
                        userId: userId ?? '',
                        libraryId: params.libraryId,
                        amount: paymentAmount,
                        createdAt: params.paymentReceivedDate,
                      )
                    : Payment.createCashPayment(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        membershipId: savedMembership.id,
                        userId: userId ?? '',
                        libraryId: params.libraryId,
                        amount: paymentAmount,
                        createdAt: params.paymentReceivedDate,
                      );

                // Approve payment if markCashReceived is true OR if it's a partial payment
                // For partial payments without activation, approve immediately so it shows
                // in revenue/transactions but NOT in pending approvals (since it's already approved)
                final payment = (params.markCashReceived || hasPartialPayment)
                    ? (params.paymentMethod == PaymentMode.upi
                          ? createdPayment.approveUpiPayment(
                              library.ownerId,
                              approvalDate: params.paymentReceivedDate,
                            )
                          : createdPayment.approveCashPayment(
                              library.ownerId,
                              approvalDate: params.paymentReceivedDate,
                            ))
                    : createdPayment;

                // Save payment record
                final savePaymentResult = await paymentRepository.createPayment(
                  payment,
                );

                if (savePaymentResult.isLeft()) {
                  // Log error but don't fail membership creation
                  log(
                    'AssignMembershipWithCustomSlot: Failed to create payment record - ${savePaymentResult.fold((l) => l.message, (r) => '')}',
                  );
                } else {
                  final savedPayment = savePaymentResult.getOrElse(
                    () => throw Error(),
                  );

                  // Generate invoice for the payment
                  if (generateInvoice != null && paymentAmount > 0) {
                    log(
                      'AssignMembershipWithCustomSlot: Generating invoice for ${hasPartialPayment ? "partial" : "full"} payment (amount: ₹$paymentAmount)...',
                    );
                    final invoiceResult = await generateInvoice!(
                      GenerateInvoiceParams(
                        membershipId: savedMembership.id,
                        paymentId: savedPayment.id,
                        paymentDate:
                            params.paymentReceivedDate ?? DateTime.now(),
                        amountPaid: paymentAmount,
                        currency: payment.currency,
                      ),
                    );
                    invoiceResult.fold(
                      (failure) => log(
                        'AssignMembershipWithCustomSlot: Invoice generation failed - ${failure.message}',
                      ),
                      (inv) {
                        log(
                          'AssignMembershipWithCustomSlot: Invoice generated: ${inv.invoiceNumber} for amount: ₹$paymentAmount',
                        );
                        if (whatsAppNotificationRepository != null) {
                          whatsAppNotificationRepository!.sendInvoiceWhatsApp(inv);
                        }
                      },
                    );
                  }
                }

                // Send notification to student (fire-and-forget)
                if (userId != null && notificationService != null) {
                  _sendStudentNotification(savedMembership, library.name, slot);
                }

                return Right(savedMembership);
              });
            }

            // If not creating payment/invoice, just return the membership
            // Send notification to student (fire-and-forget)
            if (userId != null && notificationService != null) {
              _sendStudentNotificationSimple(
                savedMembership,
                params.libraryId,
                slot,
              );
            }

            return Right(savedMembership);
          });
        });
      });
    });
  }

  /// Sends notification to student about seat assignment (when library is already loaded).
  Future<void> _sendStudentNotification(
    Membership membership,
    String libraryName,
    CustomSlot slot,
  ) async {
    try {
      if (membership.userId == null) return;

      // assignedSeatId stores the seat NUMBER (e.g., "S01"), not Firestore doc ID
      // So we can use it directly as the seat number
      final seatNumber = membership.assignedSeatId ?? 'Unknown';

      await notificationService?.notifyStudentSeatAssigned(
        studentId: membership.userId!,
        libraryName: libraryName,
        seatNumber: seatNumber,
        slotName: slot.name,
        membershipId: membership.id,
        isActive: membership.status == MembershipStatus.active,
      );
    } catch (_) {
      // Silent failure - notification is non-critical
    }
  }

  /// Sends notification to student about seat assignment (needs to load library).
  Future<void> _sendStudentNotificationSimple(
    Membership membership,
    String libraryId,
    CustomSlot slot,
  ) async {
    try {
      if (membership.userId == null) return;

      // Get library name
      final libraryResult = await libraryRepository.getLibraryById(libraryId);
      if (libraryResult.isLeft()) return;

      final library = libraryResult.getOrElse(() => null);
      if (library == null) return;

      await _sendStudentNotification(membership, library.name, slot);
    } catch (_) {
      // Silent failure - notification is non-critical
    }
  }

  Failure? _validate(AssignMembershipWithCustomSlotParams params) {
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
    if (params.slotId.trim().isEmpty) {
      return const InvalidMembershipDataFailure(
        message: 'Slot must be selected',
      );
    }
    // Validate expiry date relative to start date
    final effectiveStartDate = params.startDate ?? DateTime.now();
    if (params.expiryDate.isBefore(effectiveStartDate)) {
      return const InvalidExpiryDateFailure(
        message: 'Expiry date must be after start date',
      );
    }
    if (params.paymentBreakdown != null) {
      if (params.paymentBreakdown!.amountPaid < 0 ||
          params.paymentBreakdown!.amountRemaining < 0) {
        return const InvalidMembershipDataFailure(
          message: 'Payment amounts cannot be negative',
        );
      }
      final total =
          params.paymentBreakdown!.amountPaid +
          params.paymentBreakdown!.amountRemaining;
      if (total <= 0) {
        return const InvalidMembershipDataFailure(
          message: 'Total payment amount must be greater than zero',
        );
      }
    }
    return null;
  }

  /// Calculate full payment amount based on membership plan and slot price.
  double _calculateFullPaymentAmount(Membership membership, double slotPrice) {
    // Use effective duration (custom or plan-based)
    final durationInDays = membership.effectiveDurationInDays;
    final months = durationInDays / 30.0;
    return slotPrice * months;
  }
}

/// Parameters for AssignMembershipWithCustomSlot use case.
class AssignMembershipWithCustomSlotParams extends Equatable {
  const AssignMembershipWithCustomSlotParams({
    required this.membershipId,
    required this.libraryId,
    required this.studentPhone,
    required this.seatId,
    required this.slotId,
    required this.expiryDate,
    required this.plan,
    this.studentName,
    this.paymentMethod,
    this.paymentBreakdown,
    this.markCashReceived = false,
    this.startDate,
    this.customDurationDays,
    this.customDurationMonths,
    this.excludeMembershipId,
    this.paymentReceivedDate,
  });

  final String membershipId;
  final String libraryId;
  final String studentPhone;
  final String? studentName;
  final String seatId;
  final String slotId;
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

  /// Payment breakdown for partial payments.
  /// If null, full payment is expected.
  final PaymentBreakdown? paymentBreakdown;

  /// Whether cash payment is marked as received immediately.
  /// If true, membership becomes active immediately.
  final bool markCashReceived;

  /// Optional membership ID to exclude from conflict check.
  /// Used when reassigning/extending from an expired membership.
  final String? excludeMembershipId;

  /// Date when payment was received (optional, defaults to current date).
  /// Allows setting past dates for revenue tracking accuracy.
  final DateTime? paymentReceivedDate;

  @override
  List<Object?> get props => [
    membershipId,
    libraryId,
    studentPhone,
    studentName,
    seatId,
    slotId,
    expiryDate,
    plan,
    paymentMethod,
    paymentBreakdown,
    markCashReceived,
    startDate,
    customDurationDays,
    customDurationMonths,
    excludeMembershipId,
    paymentReceivedDate,
  ];
}
