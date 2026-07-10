import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../core/services/analytics_service.dart';
import '../core/core.dart';
import '../entities/invoice.dart';
import '../entities/membership.dart';
import '../entities/payment.dart';
import '../failures/payment_failures.dart';
import '../repositories/invoice_repository.dart';
import '../repositories/membership_repository.dart';
import '../repositories/payment_repository.dart';

/// Use case for refunding a payment and cancelling the associated membership.
///
/// This handles the scenario where a seat was assigned by mistake or
/// a student wants to cancel their membership after payment.
///
/// Business Rules:
/// - Payment must be in success status (already approved/completed)
/// - Membership will be cancelled (seat released)
/// - Payment status changed to 'refunded' (excluded from revenue)
/// - Associated invoices are deleted from both student and owner records
/// - Revenue is automatically decreased (refunded payments excluded)
/// - Analytics event tracked for refund
class RefundPayment implements UseCase<RefundResult, RefundPaymentParams> {
  const RefundPayment({
    required this.paymentRepository,
    required this.membershipRepository,
    required this.invoiceRepository,
    required this.analyticsService,
  });

  final PaymentRepository paymentRepository;
  final MembershipRepository membershipRepository;
  final InvoiceRepository invoiceRepository;
  final AnalyticsService analyticsService;

  @override
  Future<Either<Failure, RefundResult>> call(RefundPaymentParams params) async {
    // 1. Get and validate payment
    final paymentResult = await paymentRepository.getPaymentById(
      params.paymentId,
    );

    return paymentResult.fold((failure) => Left(failure), (payment) async {
      // Validate payment can be refunded
      if (payment.status != PaymentStatus.success) {
        return const Left(
          PaymentValidationFailure(
            message: 'Only successful payments can be refunded',
          ),
        );
      }

      if (payment.isRefunded) {
        return const Left(
          PaymentValidationFailure(message: 'Payment is already refunded'),
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

      // 3. Refund payment
      final refundedPayment = payment.markAsRefunded(
        reason: params.reason,
        refundedBy: params.refundedBy,
      );

      final updatePaymentResult = await paymentRepository.updatePayment(
        refundedPayment,
      );

      if (updatePaymentResult.isLeft()) {
        return Left(updatePaymentResult.fold((l) => l, (r) => throw Error()));
      }

      // 4. Cancel membership (releases seat)
      final cancelledMembership = membership.cancel();
      final updateMembershipResult = await membershipRepository
          .updateMembership(cancelledMembership);

      if (updateMembershipResult.isLeft()) {
        return Left(
          updateMembershipResult.fold((l) => l, (r) => throw Error()),
        );
      }

      // 5. Delete invoices associated with this payment
      // Invoices need to be deleted from both student and owner's records
      Invoice? invoice;
      final invoiceResult = await invoiceRepository.getInvoiceByPaymentId(
        payment.id,
      );

      await invoiceResult.fold(
        (failure) async => null, // Invoice might not exist, that's okay
        (foundInvoice) async {
          if (foundInvoice != null) {
            invoice = foundInvoice;
            // Delete the invoice since payment is refunded
            await invoiceRepository.deleteInvoice(foundInvoice.id);
          }
        },
      );

      // 6. Track refund analytics
      await analyticsService.trackPaymentRefunded(
        paymentId: payment.id,
        paymentMethod: payment.mode.name,
        amount: payment.amount,
        reason: params.reason,
        additionalParams: {
          'membership_id': membership.id,
          'library_id': payment.libraryId,
          'refunded_by': params.refundedBy,
        },
      );

      return Right(
        RefundResult(
          refundedPayment: refundedPayment,
          cancelledMembership: cancelledMembership,
          invoice: invoice,
        ),
      );
    });
  }
}

/// Parameters for RefundPayment use case.
class RefundPaymentParams extends Equatable {
  const RefundPaymentParams({
    required this.paymentId,
    required this.reason,
    required this.refundedBy,
  });

  final String paymentId;
  final String reason; // Reason for refund
  final String refundedBy; // Owner ID who initiated the refund

  @override
  List<Object?> get props => [paymentId, reason, refundedBy];
}

/// Result of a refund operation.
class RefundResult extends Equatable {
  const RefundResult({
    required this.refundedPayment,
    required this.cancelledMembership,
    this.invoice,
  });

  final Payment refundedPayment;
  final Membership cancelledMembership;
  final Invoice? invoice;

  @override
  List<Object?> get props => [refundedPayment, cancelledMembership, invoice];
}
