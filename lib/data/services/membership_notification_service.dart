import '../../domain/repositories/notification_repository.dart';

/// Service for sending membership-related push notifications.
/// Handles notifications for payments, seat assignments, and seat changes.
class MembershipNotificationService {
  const MembershipNotificationService({
    required this.notificationRepository,
  });

  final NotificationRepository notificationRepository;

  /// Notifies the library owner when a student marks payment as done.
  /// Called when student marks UPI payment as paid.
  Future<void> notifyOwnerPaymentMarkedDone({
    required String ownerId,
    required String studentName,
    required double amount,
    required String membershipId,
    required String libraryId,
  }) async {
    try {
      await notificationRepository.sendNotificationToUser(
        userId: ownerId,
        title: '💰 Payment Marked as Done',
        body: '$studentName has marked payment of ₹${amount.toStringAsFixed(0)} as done. Please verify.',
        data: {
          'type': 'payment_marked_done',
          'membershipId': membershipId,
          'libraryId': libraryId,
          'studentName': studentName,
          'amount': amount.toString(),
        },
      );
    } catch (_) {
      // Silent failure - notification is non-critical
    }
  }

  /// Notifies the library owner when a student initiates a payment (cash or UPI).
  /// Called when student initiates payment (for current or upcoming membership).
  Future<void> notifyOwnerCashPaymentInitiated({
    required String ownerId,
    required String studentName,
    required double amount,
    required String membershipId,
    required String libraryId,
    required bool isUpcomingPlan,
    String paymentMode = 'cash',
  }) async {
    try {
      final planType = isUpcomingPlan ? 'upcoming plan' : 'membership';
      final paymentType = paymentMode == 'upi' ? 'UPI' : 'Cash';
      await notificationRepository.sendNotificationToUser(
        userId: ownerId,
        title: '💰 $paymentType Payment Initiated',
        body: '$studentName has initiated $paymentType payment of ₹${amount.toStringAsFixed(0)} for $planType. Please approve.',
        data: {
          'type': 'payment_initiated',
          'membershipId': membershipId,
          'libraryId': libraryId,
          'studentName': studentName,
          'amount': amount.toString(),
          'isUpcomingPlan': isUpcomingPlan.toString(),
          'paymentMode': paymentMode,
        },
      );
    } catch (_) {
      // Silent failure - notification is non-critical
    }
  }

  /// Notifies the student when their payment is approved by the owner.
  /// Called when owner approves cash or UPI payment.
  Future<void> notifyStudentPaymentApproved({
    required String studentId,
    required String libraryName,
    required double amount,
    required String membershipId,
  }) async {
    try {
      await notificationRepository.sendNotificationToUser(
        userId: studentId,
        title: '✅ Payment Approved!',
        body: 'Your payment of ₹${amount.toStringAsFixed(0)} for $libraryName has been approved.',
        data: {
          'type': 'payment_approved',
          'membershipId': membershipId,
          'libraryName': libraryName,
          'amount': amount.toString(),
        },
      );
    } catch (_) {
      // Silent failure - notification is non-critical
    }
  }

  /// Notifies the student when a seat is assigned to them by the owner.
  /// Called when owner assigns membership with seat.
  Future<void> notifyStudentSeatAssigned({
    required String studentId,
    required String libraryName,
    required String seatNumber,
    required String slotName,
    required String membershipId,
    required bool isActive,
  }) async {
    try {
      final statusMessage = isActive
          ? 'Your seat is now active.'
          : 'Please complete payment to activate.';

      await notificationRepository.sendNotificationToUser(
        userId: studentId,
        title: '🪑 Seat Assigned!',
        body: 'You have been assigned Seat $seatNumber ($slotName) at $libraryName. $statusMessage',
        data: {
          'type': 'seat_assigned',
          'membershipId': membershipId,
          'libraryName': libraryName,
          'seatNumber': seatNumber,
          'slotName': slotName,
          'isActive': isActive.toString(),
        },
      );
    } catch (_) {
      // Silent failure - notification is non-critical
    }
  }

  /// Notifies the student when their seat is activated by the owner.
  /// Called when owner activates a pending membership.
  Future<void> notifyStudentSeatActivated({
    required String studentId,
    required String libraryName,
    required String seatNumber,
    required String slotName,
    required String membershipId,
  }) async {
    try {
      await notificationRepository.sendNotificationToUser(
        userId: studentId,
        title: '🎉 Seat Activated!',
        body: 'Your Seat $seatNumber ($slotName) at $libraryName is now active. Happy studying!',
        data: {
          'type': 'seat_activated',
          'membershipId': membershipId,
          'libraryName': libraryName,
          'seatNumber': seatNumber,
          'slotName': slotName,
        },
      );
    } catch (_) {
      // Silent failure - notification is non-critical
    }
  }

  /// Notifies the student when their seat number is changed by the owner.
  /// Called when owner reassigns seat.
  Future<void> notifyStudentSeatChanged({
    required String studentId,
    required String libraryName,
    required String oldSeatNumber,
    required String newSeatNumber,
    required String slotName,
    required String membershipId,
  }) async {
    try {
      await notificationRepository.sendNotificationToUser(
        userId: studentId,
        title: '🔄 Seat Changed',
        body: 'Your seat at $libraryName has been changed from Seat $oldSeatNumber to Seat $newSeatNumber ($slotName).',
        data: {
          'type': 'seat_changed',
          'membershipId': membershipId,
          'libraryName': libraryName,
          'oldSeatNumber': oldSeatNumber,
          'newSeatNumber': newSeatNumber,
          'slotName': slotName,
        },
      );
    } catch (_) {
      // Silent failure - notification is non-critical
    }
  }

  /// Notifies the student when their payment is rejected by the owner.
  Future<void> notifyStudentPaymentRejected({
    required String studentId,
    required String libraryName,
    required double amount,
    required String membershipId,
    String? reason,
  }) async {
    try {
      final reasonText = reason != null && reason.isNotEmpty
          ? ' Reason: $reason'
          : '';

      await notificationRepository.sendNotificationToUser(
        userId: studentId,
        title: '❌ Payment Rejected',
        body: 'Your payment of ₹${amount.toStringAsFixed(0)} for $libraryName was rejected.$reasonText',
        data: {
          'type': 'payment_rejected',
          'membershipId': membershipId,
          'libraryName': libraryName,
          'amount': amount.toString(),
          if (reason != null) 'reason': reason,
        },
      );
    } catch (_) {
      // Silent failure - notification is non-critical
    }
  }
}
