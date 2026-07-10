import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../core/services/analytics_service.dart';
import '../core/core.dart';
import '../entities/membership.dart';
import '../entities/payment.dart';
import '../failures/payment_failures.dart';
import '../repositories/membership_repository.dart';
import '../repositories/payment_repository.dart';

/// Use case for handling payment failure.
///
/// Marks payment as failed and cancels the membership reservation.
///
/// Business Rules:
/// - Payment must exist
/// - Membership is cancelled (seat becomes available)
/// - Failure reason is recorded
class HandlePaymentFailure
    implements UseCase<PaymentFailureResult, HandlePaymentFailureParams> {
  const HandlePaymentFailure({
    required this.paymentRepository,
    required this.membershipRepository,
    required this.analyticsService,
  });

  final PaymentRepository paymentRepository;
  final MembershipRepository membershipRepository;
  final AnalyticsService analyticsService;

  @override
  Future<Either<Failure, PaymentFailureResult>> call(
    HandlePaymentFailureParams params,
  ) async {
    // 1. Get payment record
    final paymentResult = await paymentRepository.getPaymentById(
      params.paymentId,
    );

    return paymentResult.fold((failure) => Left(failure), (payment) async {
      // 2. Validate payment can be marked as failed
      if (payment.status == PaymentStatus.success) {
        return const Left(
          PaymentAlreadyProcessedFailure(
            message: 'Cannot fail a successful payment',
          ),
        );
      }

      // 3. Mark payment as failed
      final updatedPayment = payment.markFailed(params.reason);
      final updatePaymentResult = await paymentRepository.updatePayment(
        updatedPayment,
      );

      return updatePaymentResult.fold((failure) => Left(failure), (
        savedPayment,
      ) async {
        // 4. Cancel membership (release seat)
        final membershipResult = await membershipRepository.getMembershipById(
          payment.membershipId,
        );

        return membershipResult.fold((failure) => Left(failure), (
          membership,
        ) async {
          // Only cancel if still pending payment
          if (membership.status == MembershipStatus.pendingPayment) {
            final cancelledMembership = membership.cancel();
            final updateResult = await membershipRepository.updateMembership(
              cancelledMembership,
            );

            return updateResult.fold(
              (failure) => Left(failure),
              (savedMembership) async {
                // Track payment failed event
                await analyticsService.trackPaymentFailed(
                  paymentId: savedPayment.id,
                  paymentMethod: savedPayment.mode.name,
                  amount: savedPayment.amount,
                  failureReason: params.reason,
                );
                
                return Right(
                  PaymentFailureResult(
                    payment: savedPayment,
                    membership: savedMembership,
                  ),
                );
              },
            );
          }

          // Track payment failed event even if membership wasn't cancelled
          await analyticsService.trackPaymentFailed(
            paymentId: savedPayment.id,
            paymentMethod: savedPayment.mode.name,
            amount: savedPayment.amount,
            failureReason: params.reason,
          );
          
          return Right(
            PaymentFailureResult(payment: savedPayment, membership: membership),
          );
        });
      });
    });
  }
}

/// Parameters for HandlePaymentFailure use case.
class HandlePaymentFailureParams extends Equatable {
  const HandlePaymentFailureParams({
    required this.paymentId,
    required this.reason,
  });

  final String paymentId;
  final String reason;

  @override
  List<Object?> get props => [paymentId, reason];
}

/// Result of payment failure handling.
class PaymentFailureResult extends Equatable {
  const PaymentFailureResult({required this.payment, required this.membership});

  final Payment payment;
  final Membership membership;

  @override
  List<Object?> get props => [payment, membership];
}
