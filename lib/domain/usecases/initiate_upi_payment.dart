import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

import '../../data/services/membership_notification_service.dart';
import '../core/core.dart';
import '../entities/membership.dart';
import '../entities/payment.dart';
import '../repositories/library_repository.dart';
import '../repositories/membership_repository.dart';
import '../repositories/payment_repository.dart';
import '../repositories/user_repository.dart';

/// Use case for initiating a UPI payment.
///
/// Business Rules:
/// - Creates payment record with mode = upi
/// - Membership remains in pendingPayment status
/// - Seat remains reserved until owner approves
/// - Student must mark as paid before owner can approve
/// - Sends notification to owner about pending UPI payment
class InitiateUpiPayment implements UseCase<Payment, InitiateUpiPaymentParams> {
  const InitiateUpiPayment({
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
  static const _uuid = Uuid();

  @override
  Future<Either<Failure, Payment>> call(InitiateUpiPaymentParams params) async {
    // Create UPI payment record
    final payment = Payment.createUpiPayment(
      id: _uuid.v4(),
      membershipId: params.membershipId,
      userId: params.userId,
      libraryId: params.libraryId,
      amount: params.amount,
      currency: params.currency,
    );

    // Save to repository
    final saveResult = await paymentRepository.createPayment(payment);

    // Send notification to owner (fire-and-forget)
    if (saveResult.isRight() && notificationService != null) {
      _sendOwnerNotification(payment);
    }

    return saveResult;
  }

  /// Sends notification to library owner about UPI payment initiation.
  Future<void> _sendOwnerNotification(Payment payment) async {
    try {
      // Get membership to check if it's an upcoming plan
      final membershipResult = await membershipRepository.getMembershipById(
        payment.membershipId,
      );
      if (membershipResult.isLeft()) return;

      final membership = membershipResult.getOrElse(() => throw Error());
      final isUpcomingPlan = membership.status == MembershipStatus.pendingPayment &&
          membership.startDate.isAfter(DateTime.now());

      // Get library to find owner
      final libraryResult = await libraryRepository.getLibraryById(
        payment.libraryId,
      );
      if (libraryResult.isLeft()) return;

      final library = libraryResult.getOrElse(() => null);
      if (library == null) return;

      // Get student name
      String studentName = 'Student';
      if (payment.userId.isNotEmpty) {
        final userResult = await userRepository.getUserById(payment.userId);
        userResult.fold(
          (_) {},
          (user) {
            studentName = user.name;
          },
        );
      } else if (membership.studentName != null) {
        studentName = membership.studentName!;
      }

      await notificationService?.notifyOwnerCashPaymentInitiated(
        ownerId: library.ownerId,
        studentName: studentName,
        amount: payment.amount,
        membershipId: membership.id,
        libraryId: library.id,
        isUpcomingPlan: isUpcomingPlan,
        paymentMode: 'upi',
      );
    } catch (_) {
      // Silent failure - notification is non-critical
    }
  }
}

/// Parameters for InitiateUpiPayment use case.
class InitiateUpiPaymentParams extends Equatable {
  const InitiateUpiPaymentParams({
    required this.membershipId,
    required this.userId,
    required this.libraryId,
    required this.amount,
    this.currency = 'INR',
  });

  final String membershipId;
  final String userId;
  final String libraryId;
  final double amount;
  final String currency;

  @override
  List<Object?> get props => [
    membershipId,
    userId,
    libraryId,
    amount,
    currency,
  ];
}
