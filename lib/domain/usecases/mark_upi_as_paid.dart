import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../data/services/membership_notification_service.dart';
import '../core/core.dart';
import '../entities/payment.dart';
import '../failures/payment_failures.dart';
import '../repositories/library_repository.dart';
import '../repositories/membership_repository.dart';
import '../repositories/payment_repository.dart';
import '../repositories/user_repository.dart';

/// Use case for marking a UPI payment as paid by student.
///
/// Business Rules:
/// - Student provides optional UTR and/or payment proof
/// - Payment status remains "initiated" until owner approves
/// - Sets studentMarkedPaidAt timestamp
/// - Owner can now see this in pending approvals
/// - Sends push notification to library owner
class MarkUpiAsPaid implements UseCase<Payment, MarkUpiAsPaidParams> {
  const MarkUpiAsPaid({
    required this.paymentRepository,
    required this.membershipRepository,
    required this.libraryRepository,
    required this.userRepository,
    this.notificationService,
  });

  final PaymentRepository paymentRepository;
  final MembershipRepository membershipRepository;
  final LibraryRepository libraryRepository;
  final UserRepository userRepository;
  final MembershipNotificationService? notificationService;

  @override
  Future<Either<Failure, Payment>> call(MarkUpiAsPaidParams params) async {
    // Get existing payment
    final paymentResult = await paymentRepository.getPaymentById(
      params.paymentId,
    );

    return paymentResult.fold((failure) => Left(failure), (payment) async {
      // Validate payment is UPI and not already marked
      if (!payment.isUpiPayment) {
        return const Left(
          PaymentValidationFailure(message: 'Payment is not a UPI payment'),
        );
      }

      if (payment.studentMarkedPaidAt != null) {
        return const Left(
          PaymentValidationFailure(message: 'Payment already marked as paid'),
        );
      }

      if (payment.status != PaymentStatus.initiated) {
        return const Left(
          PaymentValidationFailure(message: 'Payment is not in pending state'),
        );
      }

      // Mark as paid
      final updatedPayment = payment.markUpiAsPaid(
        utr: params.utrNumber,
        proofUrl: params.paymentProofUrl,
      );

      // Save updated payment
      final updateResult = await paymentRepository.updatePayment(updatedPayment);

      // Send notification to owner (fire-and-forget)
      if (updateResult.isRight() && notificationService != null) {
        _sendOwnerNotification(payment);
      }

      return updateResult;
    });
  }

  /// Sends notification to library owner about payment marked as done.
  Future<void> _sendOwnerNotification(Payment payment) async {
    try {
      // Get membership to find library info
      final membershipResult = await membershipRepository.getMembershipById(
        payment.membershipId,
      );
      if (membershipResult.isLeft()) return;

      final membership = membershipResult.getOrElse(() => throw Error());

      // Get library to find owner
      final libraryResult = await libraryRepository.getLibraryById(
        membership.libraryId,
      );
      if (libraryResult.isLeft()) return;

      final library = libraryResult.getOrElse(() => null);
      if (library == null) return;

      // Get student name
      String studentName = 'Student';
      if (membership.userId != null) {
        final userResult = await userRepository.getUserById(membership.userId!);
        userResult.fold(
          (_) {},
          (user) {
            studentName = user.name;
          },
        );
      } else if (membership.studentName != null) {
        studentName = membership.studentName!;
      }

      await notificationService?.notifyOwnerPaymentMarkedDone(
        ownerId: library.ownerId,
        studentName: studentName,
        amount: payment.amount,
        membershipId: membership.id,
        libraryId: library.id,
      );
    } catch (_) {
      // Silent failure - notification is non-critical
    }
  }
}

/// Parameters for MarkUpiAsPaid use case.
class MarkUpiAsPaidParams extends Equatable {
  const MarkUpiAsPaidParams({
    required this.paymentId,
    this.utrNumber,
    this.paymentProofUrl,
  });

  final String paymentId;
  final String? utrNumber;
  final String? paymentProofUrl;

  @override
  List<Object?> get props => [paymentId, utrNumber, paymentProofUrl];
}
