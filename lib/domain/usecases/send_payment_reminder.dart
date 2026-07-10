import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../core/core.dart';
import '../entities/membership.dart';
import '../failures/membership_failures.dart';
import '../repositories/membership_repository.dart';
import '../repositories/notification_repository.dart';

/// Use case for sending payment reminder notifications.
/// Used for partial payments or pending payments.
class SendPaymentReminder implements UseCase<void, SendPaymentReminderParams> {
  const SendPaymentReminder({
    required this.membershipRepository,
    required this.notificationRepository,
  });

  final MembershipRepository membershipRepository;
  final NotificationRepository notificationRepository;

  @override
  Future<Either<Failure, void>> call(SendPaymentReminderParams params) async {
    // Validate membership ID
    if (params.membershipId.isEmpty) {
      return const Left(
        InvalidMembershipDataFailure(message: 'Membership ID cannot be empty'),
      );
    }

    // Get membership
    final membershipResult = await membershipRepository.getMembershipById(
      params.membershipId,
    );

    return membershipResult.fold((failure) => Left(failure), (
      membership,
    ) async {
      // Validate user ID exists
      if (membership.userId == null) {
        return const Left(
          InvalidMembershipDataFailure(
            message: 'Cannot send reminder to unregistered student',
          ),
        );
      }

      // Determine reminder message based on payment status
      final title =
          params.title ??
          (membership.hasPartialPayment
              ? 'Payment Reminder'
              : 'Payment Pending');
      final body =
          params.body ??
          (membership.hasPartialPayment
              ? 'You have a remaining balance of ₹${membership.paymentBreakdown?.amountRemaining.toStringAsFixed(0) ?? "0"}. Please complete your payment to continue enjoying our services.'
              : 'Your payment of ₹${_calculateFullPaymentAmount(membership).toStringAsFixed(0)} is pending. Please complete the payment to activate your membership.');

      // Send notification (fire-and-forget)
      notificationRepository.sendNotificationsToUsers(
        userIds: [membership.userId!],
        title: title,
        body: body,
        data: {
          'type': 'payment_reminder',
          'libraryId': membership.libraryId,
          'membershipId': membership.id,
          'isPartialPayment': membership.hasPartialPayment,
        },
      );

      // Return success immediately (fire-and-forget pattern)
      return const Right(null);
    });
  }

  /// Calculate full payment amount based on membership plan.
  double _calculateFullPaymentAmount(Membership membership) {
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

/// Parameters for SendPaymentReminder use case.
class SendPaymentReminderParams extends Equatable {
  const SendPaymentReminderParams({
    required this.membershipId,
    this.title,
    this.body,
  });

  final String membershipId;
  final String? title;
  final String? body;

  @override
  List<Object?> get props => [membershipId, title, body];
}
