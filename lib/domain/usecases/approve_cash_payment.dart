import 'dart:developer';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../data/failures/data_failures.dart';
import '../../data/services/membership_notification_service.dart';
import '../core/core.dart';
import '../entities/invoice.dart';
import '../entities/membership.dart';
import '../entities/payment.dart';
import '../entities/payment_breakdown.dart';
import '../repositories/library_repository.dart';
import '../repositories/membership_repository.dart';
import '../repositories/payment_repository.dart';
import '../repositories/whatsapp_notification_repository.dart';
import 'generate_invoice.dart';

/// Use case for owner to approve a cash payment.
///
/// Business Rules:
/// - Only owner can approve
/// - Payment status changes to approved
/// - Membership status changes to active
/// - Seat status follows membership status (handled by existing flow)
/// - Invoice is generated after successful approval
/// - Sends push notification to student
class ApproveCashPayment
    implements UseCase<CashApprovalResult, ApproveCashPaymentParams> {
  const ApproveCashPayment({
    required this.paymentRepository,
    required this.membershipRepository,
    required this.libraryRepository,
    this.generateInvoice,
    this.notificationService,
    this.whatsAppNotificationRepository,
  });

  final PaymentRepository paymentRepository;
  final MembershipRepository membershipRepository;
  final LibraryRepository libraryRepository;
  final GenerateInvoice? generateInvoice;
  final MembershipNotificationService? notificationService;
  final WhatsAppNotificationRepository? whatsAppNotificationRepository;

  @override
  Future<Either<Failure, CashApprovalResult>> call(
    ApproveCashPaymentParams params,
  ) async {
    try {
      // 1. Get and validate payment
      final paymentResult = await paymentRepository.getPaymentById(
        params.paymentId,
      );
      if (paymentResult.isLeft()) {
        return Left(paymentResult.fold((l) => l, (r) => throw Error()));
      }

      final payment = paymentResult.getOrElse(() => throw Error());

      // Check for both cash and UPI pending approvals
      if (!payment.isPendingApproval) {
        return const Left(
          ValidationFailure(message: 'Payment is not pending approval'),
        );
      }

      // 2. Get membership
      final membershipResult = await membershipRepository.getMembershipById(
        payment.membershipId,
      );
      if (membershipResult.isLeft()) {
        return Left(membershipResult.fold((l) => l, (r) => throw Error()));
      }

      final membership = membershipResult.getOrElse(() => throw Error());

      // 3. Approve payment (works for both cash and UPI)
      final approvedPayment = payment.isUpiPayment
          ? payment.approveUpiPayment(params.ownerId)
          : payment.approveCashPayment(params.ownerId);
      final updatePaymentResult = await paymentRepository.updatePayment(
        approvedPayment,
      );
      if (updatePaymentResult.isLeft()) {
        return Left(updatePaymentResult.fold((l) => l, (r) => throw Error()));
      }

      // 4. Check if this is a partial payment completion
      // If membership has partial payment and this payment completes it, update breakdown
      Membership updatedMembership = membership;
      if (membership.hasPartialPayment && membership.paymentBreakdown != null) {
        final breakdown = membership.paymentBreakdown!;
        final totalPaid = breakdown.amountPaid + approvedPayment.amount;
        final totalAmount = breakdown.totalAmount;

        // If this payment completes the remaining amount, mark as full payment
        if (totalPaid >= totalAmount) {
          updatedMembership = membership.copyWith(
            paymentBreakdown: PaymentBreakdown.fullPayment(totalAmount),
          );
        } else {
          // Update breakdown with new amount paid
          updatedMembership = membership.copyWith(
            paymentBreakdown: breakdown.copyWith(
              amountPaid: totalPaid,
              amountRemaining: totalAmount - totalPaid,
            ),
          );
        }
      }

      // 5. Activate membership (or keep active if already active)
      final activatedMembership =
          updatedMembership.status == MembershipStatus.active
          ? updatedMembership
          : updatedMembership.activate();
      final updateMembershipResult = await membershipRepository
          .updateMembership(activatedMembership);
      if (updateMembershipResult.isLeft()) {
        return Left(
          updateMembershipResult.fold((l) => l, (r) => throw Error()),
        );
      }

      final savedMembership = updateMembershipResult.getOrElse(
        () => throw Error(),
      );

      // 5. Generate invoice (optional, doesn't block success)
      Invoice? invoice;
      if (generateInvoice != null) {
        log('ApproveCashPayment: Generating invoice...');
        final invoiceResult = await generateInvoice!(
          GenerateInvoiceParams(
            membershipId: savedMembership.id,
            paymentId: approvedPayment.id,
            paymentDate: DateTime.now(),
            amountPaid: approvedPayment.amount,
            currency: approvedPayment.currency,
          ),
        );
        invoiceResult.fold(
          (failure) => log(
            'ApproveCashPayment: Invoice generation failed - ${failure.message}',
          ),
          (inv) {
            invoice = inv;
            log('ApproveCashPayment: Invoice generated: ${inv.invoiceNumber}');
          },
        );
      }

      // Send WhatsApp invoice (fire-and-forget — never blocks success)
      if (invoice != null && whatsAppNotificationRepository != null) {
        whatsAppNotificationRepository!.sendInvoiceWhatsApp(invoice!);
      }

      // Send push notification to student (fire-and-forget)
      if (notificationService != null && savedMembership.userId != null) {
        _sendStudentNotification(savedMembership, approvedPayment);
      }

      return Right(
        CashApprovalResult(
          payment: approvedPayment,
          membership: savedMembership,
          invoice: invoice,
        ),
      );
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Sends notification to student about payment approval.
  Future<void> _sendStudentNotification(
    Membership membership,
    Payment payment,
  ) async {
    try {
      // Get library name
      final libraryResult = await libraryRepository.getLibraryById(
        membership.libraryId,
      );
      if (libraryResult.isLeft()) return;

      final library = libraryResult.getOrElse(() => null);
      if (library == null) return;

      await notificationService!.notifyStudentPaymentApproved(
        studentId: membership.userId!,
        libraryName: library.name,
        amount: payment.amount,
        membershipId: membership.id,
      );
    } catch (_) {
      // Silent failure - notification is non-critical
    }
  }
}

/// Parameters for ApproveCashPayment use case.
class ApproveCashPaymentParams extends Equatable {
  const ApproveCashPaymentParams({
    required this.paymentId,
    required this.ownerId,
  });

  final String paymentId;
  final String ownerId;

  @override
  List<Object?> get props => [paymentId, ownerId];
}

/// Result of cash payment approval.
class CashApprovalResult extends Equatable {
  const CashApprovalResult({
    required this.payment,
    required this.membership,
    this.invoice,
  });

  final Payment payment;
  final Membership membership;

  /// Generated invoice (if invoice generation is enabled).
  final Invoice? invoice;

  @override
  List<Object?> get props => [payment, membership, invoice];
}

/// Failure when entity is not found.
class NotFoundFailure extends Failure {
  const NotFoundFailure({super.message});
}

/// Failure for validation errors.
class ValidationFailure extends Failure {
  const ValidationFailure({super.message});
}
