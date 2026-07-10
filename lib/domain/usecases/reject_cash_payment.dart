import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../data/failures/data_failures.dart';
import '../../data/services/membership_notification_service.dart';
import '../core/core.dart';
import '../entities/membership.dart';
import '../entities/payment.dart';
import '../repositories/library_repository.dart';
import '../repositories/membership_repository.dart';
import '../repositories/payment_repository.dart';

/// Use case for owner to reject a cash payment.
///
/// Business Rules:
/// - Only owner can reject
/// - Payment status changes to failed
/// - Membership is NOT modified — stays as-is with seat assigned
/// - Student can re-submit a new payment for the same membership
/// - Sends push notification to student
class RejectCashPayment
    implements UseCase<CashRejectionResult, RejectCashPaymentParams> {
  const RejectCashPayment({
    required this.paymentRepository,
    required this.membershipRepository,
    required this.libraryRepository,
    this.notificationService,
  });

  final PaymentRepository paymentRepository;
  final MembershipRepository membershipRepository;
  final LibraryRepository libraryRepository;
  final MembershipNotificationService? notificationService;

  @override
  Future<Either<Failure, CashRejectionResult>> call(
    RejectCashPaymentParams params,
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
        return Left(
          const ValidationFailure(message: 'Payment is not pending approval'),
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

      // 3. Reject payment (same logic for cash and UPI)
      final rejectedPayment = payment.copyWith(
        status: PaymentStatus.failed,
        failureReason: params.reason ?? 'Payment rejected by owner',
        approvedByOwnerId: params.ownerId,
        updatedAt: DateTime.now(),
      );
      final updatePaymentResult = await paymentRepository.updatePayment(
        rejectedPayment,
      );
      if (updatePaymentResult.isLeft()) {
        return Left(updatePaymentResult.fold((l) => l, (r) => throw Error()));
      }

      // 4. Membership stays untouched — seat, status, slot all preserved.
      //    Student can re-submit payment for the same membership.

      // Send notification to student (fire-and-forget)
      if (notificationService != null && membership.userId != null) {
        _sendStudentNotification(
          membership,
          rejectedPayment,
          params.reason,
        );
      }

      return Right(
        CashRejectionResult(
          payment: rejectedPayment,
          membership: membership,
        ),
      );
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Sends notification to student about payment rejection.
  Future<void> _sendStudentNotification(
    Membership membership,
    Payment payment,
    String? reason,
  ) async {
    try {
      // Get library name
      final libraryResult = await libraryRepository.getLibraryById(
        membership.libraryId,
      );
      if (libraryResult.isLeft()) return;

      final library = libraryResult.getOrElse(() => null);
      if (library == null) return;

      await notificationService?.notifyStudentPaymentRejected(
        studentId: membership.userId!,
        libraryName: library.name,
        amount: payment.amount,
        membershipId: membership.id,
        reason: reason,
      );
    } catch (_) {
      // Silent failure - notification is non-critical
    }
  }
}

/// Parameters for RejectCashPayment use case.
class RejectCashPaymentParams extends Equatable {
  const RejectCashPaymentParams({
    required this.paymentId,
    required this.ownerId,
    this.reason,
  });

  final String paymentId;
  final String ownerId;
  final String? reason;

  @override
  List<Object?> get props => [paymentId, ownerId, reason];
}

/// Result of cash payment rejection.
class CashRejectionResult extends Equatable {
  const CashRejectionResult({required this.payment, required this.membership});

  final Payment payment;
  final Membership membership;

  @override
  List<Object?> get props => [payment, membership];
}
