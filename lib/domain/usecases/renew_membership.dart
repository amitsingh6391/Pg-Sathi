import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../core/services/analytics_service.dart';
import '../core/core.dart';
import '../entities/membership.dart';
import '../entities/payment.dart';
import '../entities/payment_breakdown.dart';
import '../entities/slot.dart';
import '../failures/membership_failures.dart';
import '../failures/seat_failures.dart';
import '../repositories/membership_repository.dart';
import '../repositories/payment_repository.dart';
import '../repositories/library_repository.dart';
import '../repositories/slot_repository.dart';
import '../repositories/seat_repository.dart';
import 'generate_invoice.dart';

/// Use case for renewing an expiring or expired membership.
/// Creates a new membership starting from the expiry date of the current one.
/// The new membership will be activated once payment is received.
class RenewMembership implements UseCase<RenewMembershipResult, RenewMembershipParams> {
  const RenewMembership({
    required this.membershipRepository,
    required this.paymentRepository,
    required this.libraryRepository,
    required this.slotRepository,
    required this.seatRepository,
    required this.analyticsService,
    this.generateInvoice,
  });

  final MembershipRepository membershipRepository;
  final PaymentRepository paymentRepository;
  final LibraryRepository libraryRepository;
  final SlotRepository slotRepository;
  final SeatRepository seatRepository;
  final AnalyticsService analyticsService;
  final GenerateInvoice? generateInvoice;

  @override
  Future<Either<Failure, RenewMembershipResult>> call(
    RenewMembershipParams params,
  ) async {
    // 1. Get current membership
    final membershipResult = await membershipRepository.getMembershipById(
      params.currentMembershipId,
    );

    return membershipResult.fold(
      (failure) => Left(failure),
      (currentMembership) async {
        // 2. Validate that membership can be renewed
        if (currentMembership.userId == null) {
          return const Left(
            InvalidMembershipDataFailure(
              message: 'Cannot renew unregistered membership',
            ),
          );
        }

        // 3. Calculate new membership dates
        // Start date = current membership end date (or today if already expired)
        final now = params.renewalDate ?? DateTime.now();
        final startDate = currentMembership.endDate.isBefore(now)
            ? now
            : currentMembership.endDate;
        
        // End date = start date + duration (based on plan or custom duration)
        DateTime endDate;
        if (params.customDurationDays != null) {
          endDate = startDate.add(Duration(days: params.customDurationDays!));
        } else if (params.customDurationMonths != null) {
          endDate = DateTime(
            startDate.year,
            startDate.month + params.customDurationMonths!,
            startDate.day,
          );
        } else {
          // Use plan duration
          endDate = _calculateEndDate(startDate, params.plan ?? currentMembership.plan);
        }

        // 4. Check seat availability - check if seat is occupied by another active membership
        if (currentMembership.assignedSeatId != null) {
          final occupiedResult = await membershipRepository.getMembershipBySeatAndSlot(
            libraryId: currentMembership.libraryId,
            seatId: currentMembership.assignedSeatId!,
            slot: currentMembership.slot ?? Slot.morning, // Default fallback
          );

          final occupiedMembership = occupiedResult.getOrElse(() => null);
          if (occupiedMembership != null &&
              occupiedMembership.id != currentMembership.id &&
              occupiedMembership.status == MembershipStatus.active) {
            return const Left(
              SeatAlreadyOccupiedFailure(
                message: 'Seat is already occupied by another student',
              ),
            );
          }
        }

        // 5. Create new membership
        final newMembershipId = DateTime.now().millisecondsSinceEpoch.toString();
        final newMembership = Membership(
          id: newMembershipId,
          userId: currentMembership.userId,
          libraryId: currentMembership.libraryId,
          plan: params.plan ?? currentMembership.plan,
          startDate: startDate,
          endDate: endDate,
          status: MembershipStatus.pendingPayment, // Will be activated on payment
          phoneNumber: currentMembership.phoneNumber,
          assignedSeatId: currentMembership.assignedSeatId,
          slot: currentMembership.slot,
          slotId: currentMembership.slotId,
          createdAt: DateTime.now(),
          paymentMethod: params.paymentMethod,
          paymentStatus: MembershipPaymentStatus.pending,
          paymentBreakdown: params.paymentBreakdown,
          assignedByOwner: false, // Student-initiated renewal
          customDurationDays: params.customDurationDays,
          customDurationMonths: params.customDurationMonths,
        );

        final createResult = await membershipRepository.createMembership(newMembership);
        if (createResult.isLeft()) {
          return Left(createResult.fold((l) => l, (r) => throw Error()));
        }

        final savedMembership = createResult.getOrElse(() => throw Error());

        // 6. Create payment record if amount is provided
        Payment? payment;
        if (params.amount != null && params.amount! > 0) {
          final paymentId = DateTime.now().millisecondsSinceEpoch.toString();
          payment = params.paymentMethod == PaymentMode.cash
              ? Payment.createCashPayment(
                  id: paymentId,
                  membershipId: savedMembership.id,
                  userId: currentMembership.userId!,
                  libraryId: currentMembership.libraryId,
                  amount: params.amount!,
                )
              : Payment.createUpiPayment(
                  id: paymentId,
                  membershipId: savedMembership.id,
                  userId: currentMembership.userId!,
                  libraryId: currentMembership.libraryId,
                  amount: params.amount!,
                );

          final paymentResult = await paymentRepository.createPayment(payment);
          if (paymentResult.isLeft()) {
            // Payment creation failed, but membership is created
            // Student can retry payment later
            return Right(
              RenewMembershipResult(
                membership: savedMembership,
                payment: null,
              ),
            );
          }

          payment = paymentResult.getOrElse(() => throw Error());
        }

        // Track membership renewal
        analyticsService.trackMembershipRenewed(
          membershipId: savedMembership.id,
          planType: params.plan?.name ?? 'custom',
          duration: params.plan != null ? '${params.plan!.durationInDays}d' : '${params.customDurationDays ?? params.customDurationMonths ?? 0}',
          amount: params.amount ?? 0,
          additionalParams: {
            'payment_mode': params.paymentMethod?.name ?? 'none',
            'old_membership_id': currentMembership.id,
          },
        );

        return Right(
          RenewMembershipResult(
            membership: savedMembership,
            payment: payment,
          ),
        );
      },
    );
  }

  DateTime _calculateEndDate(DateTime startDate, MembershipPlan plan) {
    switch (plan) {
      case MembershipPlan.daily:
        return startDate.add(const Duration(days: 1));
      case MembershipPlan.weekly:
        return startDate.add(const Duration(days: 7));
      case MembershipPlan.monthly:
        return DateTime(startDate.year, startDate.month + 1, startDate.day);
      case MembershipPlan.quarterly:
        return DateTime(startDate.year, startDate.month + 3, startDate.day);
      case MembershipPlan.yearly:
        return DateTime(startDate.year + 1, startDate.month, startDate.day);
    }
  }
}

/// Parameters for RenewMembership use case.
class RenewMembershipParams extends Equatable {
  const RenewMembershipParams({
    required this.currentMembershipId,
    this.plan,
    this.amount,
    this.paymentMethod,
    this.paymentBreakdown,
    this.customDurationDays,
    this.customDurationMonths,
    this.renewalDate,
  });

  final String currentMembershipId;
  final MembershipPlan? plan;
  final double? amount;
  final PaymentMode? paymentMethod;
  final PaymentBreakdown? paymentBreakdown;
  final int? customDurationDays;
  final int? customDurationMonths;
  final DateTime? renewalDate;

  @override
  List<Object?> get props => [
        currentMembershipId,
        plan,
        amount,
        paymentMethod,
        paymentBreakdown,
        customDurationDays,
        customDurationMonths,
        renewalDate,
      ];
}

/// Result of renew membership operation.
class RenewMembershipResult extends Equatable {
  const RenewMembershipResult({
    required this.membership,
    this.payment,
  });

  final Membership membership;
  final Payment? payment;

  @override
  List<Object?> get props => [membership, payment];
}
