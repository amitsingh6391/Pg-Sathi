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

/// Use case for initiating a cash payment.
///
/// Business Rules:
/// - Marks payment as initiated with mode = cash
/// - Membership remains in pendingPayment status
/// - Seat remains reserved until owner approves
/// - No expiry for cash payments (unlike online)
/// - Sends notification to owner about pending payment
class InitiateCashPayment
    implements UseCase<Payment, InitiateCashPaymentParams> {
  const InitiateCashPayment({
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
  Future<Either<Failure, Payment>> call(
    InitiateCashPaymentParams params,
  ) async {
    // Create cash payment record
    final payment = Payment.createCashPayment(
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

  /// Sends notification to library owner about cash payment initiation.
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
      );
    } catch (_) {
      // Silent failure - notification is non-critical
    }
  }
}

/// Parameters for InitiateCashPayment use case.
class InitiateCashPaymentParams extends Equatable {
  const InitiateCashPaymentParams({
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
