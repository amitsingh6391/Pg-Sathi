import 'dart:developer';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../core/core.dart';
import '../entities/invoice.dart';
import '../entities/membership.dart';
import '../entities/payment.dart';
import '../failures/membership_failures.dart';
import '../repositories/membership_repository.dart';
import '../repositories/payment_repository.dart';
import '../repositories/whatsapp_notification_repository.dart';
import 'generate_invoice.dart';

/// Use case for marking payment as received (for cash/UPI payments).
/// Updates membership status to active, payment status to markedPaid,
/// creates/updates payment record, generates invoice, and updates revenue.
class MarkPaymentReceived
    implements UseCase<MarkPaymentReceivedResult, MarkPaymentReceivedParams> {
  const MarkPaymentReceived({
    required this.membershipRepository,
    required this.paymentRepository,
    this.generateInvoice,
    this.whatsAppNotificationRepository,
  });

  final MembershipRepository membershipRepository;
  final PaymentRepository paymentRepository;
  final GenerateInvoice? generateInvoice;
  final WhatsAppNotificationRepository? whatsAppNotificationRepository;

  @override
  Future<Either<Failure, MarkPaymentReceivedResult>> call(
    MarkPaymentReceivedParams params,
  ) async {
    // Get the membership
    final membershipResult = await membershipRepository.getMembershipById(
      params.membershipId,
    );

    return membershipResult.fold((failure) => Left(failure), (
      membership,
    ) async {
      // Validate that this is a cash or UPI payment
      if (membership.paymentMethod != PaymentMode.cash &&
          membership.paymentMethod != PaymentMode.upi) {
        return const Left(
          InvalidMembershipDataFailure(
            message: 'Only cash and UPI payments can be marked as received',
          ),
        );
      }

      // Validate that payment can be processed
      // Allow if: pending status OR active with remaining balance (partial payment)
      final hasRemainingBalance =
          membership.paymentBreakdown != null &&
          membership.paymentBreakdown!.amountRemaining > 0;
      final canProcessPayment =
          membership.paymentStatus == MembershipPaymentStatus.pending ||
          (membership.status == MembershipStatus.active &&
              hasRemainingBalance) ||
          membership.status == MembershipStatus.pendingPayment;

      if (!canProcessPayment) {
        return const Left(
          InvalidMembershipDataFailure(
            message: 'Payment has already been processed',
          ),
        );
      }

      // Calculate payment amount for THIS transaction
      // The payment breakdown's amountPaid represents the CUMULATIVE amount paid so far
      // We need to find the amount for THIS specific transaction by comparing with existing payments
      double paymentAmount;

      if (membership.paymentBreakdown != null) {
        final breakdown = membership.paymentBreakdown!;

        // Get sum of all existing payments for this membership
        final paymentsResult = await paymentRepository
            .getPaymentsByMembershipId(membership.id);

        double totalExistingPayments = 0.0;
        paymentsResult.fold(
          (_) {
            // No existing payments or error
            totalExistingPayments = 0.0;
          },
          (payments) {
            // Sum up all approved payments (exclude failed/pending payments)
            for (final payment in payments) {
              if (payment.status == PaymentStatus.success) {
                totalExistingPayments += payment.amount;
              }
            }
          },
        );

        // Calculate the new payment amount:
        // New payment = Current cumulative amountPaid - Sum of all existing approved payments
        paymentAmount = (breakdown.amountPaid - totalExistingPayments).clamp(
          0.0,
          double.infinity,
        );

        log(
          'MarkPaymentReceived: Cumulative amountPaid=${breakdown.amountPaid}, '
          'Total existing payments=$totalExistingPayments, '
          'New payment amount=$paymentAmount',
        );
      } else {
        // No payment breakdown: use full amount (this is a full payment activation)
        paymentAmount = _calculateFullPaymentAmount(membership);
        log(
          'MarkPaymentReceived: Full payment (no breakdown), amount=$paymentAmount',
        );
      }

      // Mark payment as received and activate membership (if not already active)
      // For active memberships with partial payments:
      // - Keep status as active
      // - Set payment status based on remaining balance
      final Membership updatedMembership;
      if (membership.status == MembershipStatus.active) {
        updatedMembership = membership.copyWith(
          paymentStatus: hasRemainingBalance
              ? MembershipPaymentStatus.pending
              : MembershipPaymentStatus.markedPaid,
        );
      } else if (membership.status == MembershipStatus.pendingPayment) {
        updatedMembership = membership.copyWith(
          status: MembershipStatus.active,
          paymentStatus: hasRemainingBalance
              ? MembershipPaymentStatus.pending
              : MembershipPaymentStatus.markedPaid,
        );
      } else {
        updatedMembership = membership.markPaymentReceived();
      }
      final updateMembershipResult = await membershipRepository
          .updateMembership(updatedMembership);

      if (updateMembershipResult.isLeft()) {
        return Left(
          updateMembershipResult.fold((l) => l, (r) => throw Error()),
        );
      }

      final savedMembership = updateMembershipResult.getOrElse(
        () => throw Error(),
      );
      Payment? savedPayment;
      Invoice? invoice;

      if (paymentAmount > 0) {
        final userId = membership.userId ?? '';
        final paymentId = DateTime.now().millisecondsSinceEpoch.toString();
        final isUpi = membership.paymentMethod == PaymentMode.upi;
        final basePayment = isUpi
            ? Payment.createUpiPayment(
                id: paymentId,
                membershipId: membership.id,
                userId: userId,
                libraryId: membership.libraryId,
                amount: paymentAmount,
              )
            : Payment.createCashPayment(
                id: paymentId,
                membershipId: membership.id,
                userId: userId,
                libraryId: membership.libraryId,
                amount: paymentAmount,
              );
        final payment = isUpi
            ? basePayment.approveUpiPayment(params.ownerId)
            : basePayment.approveCashPayment(params.ownerId);

        // Save payment record
        final savePaymentResult = await paymentRepository.createPayment(
          payment,
        );

        if (savePaymentResult.isLeft()) {
          return Left(savePaymentResult.fold((l) => l, (r) => throw Error()));
        }

        savedPayment = savePaymentResult.getOrElse(() => throw Error());

        // Generate invoice (optional, doesn't block success)
        if (generateInvoice != null) {
          log('MarkPaymentReceived: Generating invoice for ₹$paymentAmount...');
          final invoiceResult = await generateInvoice!(
            GenerateInvoiceParams(
              membershipId: savedMembership.id,
              paymentId: savedPayment.id,
              paymentDate: DateTime.now(),
              amountPaid: paymentAmount,
              currency: savedPayment.currency,
            ),
          );
          invoiceResult.fold(
            (failure) => log(
              'MarkPaymentReceived: Invoice generation failed - ${failure.message}',
            ),
            (inv) {
              invoice = inv;
              log(
                'MarkPaymentReceived: Invoice generated: ${inv.invoiceNumber}',
              );
              // Send WhatsApp invoice (fire-and-forget — never blocks success)
              if (whatsAppNotificationRepository != null) {
                whatsAppNotificationRepository!.sendInvoiceWhatsApp(inv);
              }
            },
          );
        }
      } else {
        log(
          'MarkPaymentReceived: Skipping payment/invoice creation - no new payment amount (only discount or breakdown updated)',
        );
      }

      final placeholderPayment = membership.paymentMethod == PaymentMode.upi
          ? Payment.createUpiPayment(
              id: 'no_payment',
              membershipId: membership.id,
              userId: membership.userId ?? '',
              libraryId: membership.libraryId,
              amount: 0,
            )
          : Payment.createCashPayment(
              id: 'no_payment',
              membershipId: membership.id,
              userId: membership.userId ?? '',
              libraryId: membership.libraryId,
              amount: 0,
            );

      return Right(
        MarkPaymentReceivedResult(
          membership: savedMembership,
          payment: savedPayment ?? placeholderPayment,
          invoice: invoice,
        ),
      );
    });
  }

  /// Calculate full payment amount based on membership plan and slot.
  /// For pending payments, this should get the original total amount from paymentBreakdown.
  double _calculateFullPaymentAmount(Membership membership) {
    // If membership has payment breakdown, use totalAmount (which includes custom slot price)
    if (membership.paymentBreakdown != null) {
      return membership.paymentBreakdown!.totalAmount;
    }

    // Fallback to hardcoded values for legacy slots without breakdown
    // Note: This should ideally fetch custom slot price if slotId is set
    switch (membership.plan) {
      case MembershipPlan.daily:
        return 50.0;
      case MembershipPlan.weekly:
        return 300.0;
      case MembershipPlan.monthly:
        return 1000.0;
      case MembershipPlan.quarterly:
        return 2500.0;
      case MembershipPlan.yearly:
        return 8000.0;
    }
  }
}

/// Parameters for MarkPaymentReceived use case.
class MarkPaymentReceivedParams extends Equatable {
  const MarkPaymentReceivedParams({
    required this.membershipId,
    required this.ownerId,
  });

  final String membershipId;
  final String ownerId;

  @override
  List<Object?> get props => [membershipId, ownerId];
}

/// Result of marking payment as received.
class MarkPaymentReceivedResult extends Equatable {
  const MarkPaymentReceivedResult({
    required this.membership,
    required this.payment,
    this.invoice,
  });

  final Membership membership;
  final Payment payment;
  final Invoice? invoice;

  @override
  List<Object?> get props => [membership, payment, invoice];
}
