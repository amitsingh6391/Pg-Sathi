import '../../domain/entities/subscription.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/notification_repository.dart';
import '../../domain/repositories/user_repository.dart';

/// Service for sending subscription-related push notifications.
/// Uses existing User/Notification infrastructure.
class SubscriptionNotificationService {
  const SubscriptionNotificationService({
    required this.notificationRepository,
    required this.userRepository,
  });

  final NotificationRepository notificationRepository;
  final UserRepository userRepository;

  /// Sends notification to all admin users when an owner submits payment.
  Future<void> notifyAdminPaymentSubmitted({
    required String ownerName,
    required String libraryName,
    required double amount,
    required String subscriptionId,
  }) async {
    try {
      // Get all admin users
      final adminsResult = await userRepository.getUsersByRole(UserRole.admin);

      await adminsResult.fold((_) {}, (admins) async {
        if (admins.isEmpty) return;

        final adminIds = admins.map((a) => a.id).toList();

        await notificationRepository.sendNotificationsToUsers(
          userIds: adminIds,
          title: '💰 New Payment Verification',
          body:
              '$ownerName ($libraryName) submitted ₹${amount.toStringAsFixed(0)} for verification',
          data: {
            'type': 'payment_verification',
            'subscriptionId': subscriptionId,
            'ownerName': ownerName,
            'libraryName': libraryName,
            'amount': amount.toString(),
          },
        );
      });
    } catch (_) {
      // Silent failure - notification is non-critical
    }
  }

  /// Sends notification to owner when admin approves their payment.
  Future<void> notifyOwnerPaymentApproved({
    required String ownerId,
    required String planName,
    required int durationMonths,
    required DateTime validUntil,
  }) async {
    try {
      await notificationRepository.sendNotificationToUser(
        userId: ownerId,
        title: '✅ Payment Approved!',
        body:
            'Your $planName plan is now active for $durationMonths month${durationMonths > 1 ? 's' : ''}',
        data: {
          'type': 'payment_approved',
          'planName': planName,
          'durationMonths': durationMonths.toString(),
          'validUntil': validUntil.toIso8601String(),
        },
      );
    } catch (_) {
      // Silent failure - notification is non-critical
    }
  }

  /// Sends notification to owner when admin rejects their payment.
  Future<void> notifyOwnerPaymentRejected({
    required String ownerId,
    required String reason,
  }) async {
    try {
      await notificationRepository.sendNotificationToUser(
        userId: ownerId,
        title: '❌ Payment Verification Failed',
        body: reason.isNotEmpty
            ? 'Reason: $reason. Please contact support.'
            : 'Please contact support for more details.',
        data: {'type': 'payment_rejected', 'reason': reason},
      );
    } catch (_) {
      // Silent failure - notification is non-critical
    }
  }

  /// Sends notification to all admin users when Razorpay payment succeeds.
  /// Razorpay payments are auto-approved, so this is just informational.
  Future<void> notifyAdminRazorpayPayment({
    required String ownerName,
    required String libraryName,
    required double amount,
    required int durationMonths,
    required String razorpayPaymentId,
  }) async {
    try {
      // Get all admin users
      final adminsResult = await userRepository.getUsersByRole(UserRole.admin);

      await adminsResult.fold((_) {}, (admins) async {
        if (admins.isEmpty) return;

        final adminIds = admins.map((a) => a.id).toList();

        await notificationRepository.sendNotificationsToUsers(
          userIds: adminIds,
          title: '💳 Razorpay Payment Success',
          body:
              '$ownerName ($libraryName) paid ₹${amount.toStringAsFixed(0)} via Razorpay - Auto-activated',
          data: {
            'type': 'razorpay_payment',
            'ownerName': ownerName,
            'libraryName': libraryName,
            'amount': amount.toString(),
            'durationMonths': durationMonths.toString(),
            'razorpayPaymentId': razorpayPaymentId,
          },
        );
      });
    } catch (_) {
      // Silent failure - notification is non-critical
    }
  }

  /// Sends notification to all admins when an owner requests a withdrawal.
  Future<void> notifyAdminWithdrawalRequested({
    required String ownerId,
    required double amount,
    String? upiId,
  }) async {
    try {
      final adminsResult = await userRepository.getUsersByRole(UserRole.admin);

      await adminsResult.fold((_) {}, (admins) async {
        if (admins.isEmpty) return;

        final adminIds = admins.map((a) => a.id).toList();

        await notificationRepository.sendNotificationsToUsers(
          userIds: adminIds,
          title: '💸 Referral Withdrawal Request',
          body:
              'Owner requested ₹${amount.toStringAsFixed(0)} withdrawal'
              '${upiId != null && upiId.isNotEmpty ? ' to $upiId' : ''}',
          data: {
            'type': 'withdrawal_request',
            'ownerId': ownerId,
            'amount': amount.toString(),
            if (upiId != null) 'upiId': upiId,
          },
        );
      });
    } catch (_) {
      // Silent failure - notification is non-critical
    }
  }

  /// Sends notification to owner when admin approves their withdrawal.
  Future<void> notifyOwnerWithdrawalApproved({
    required String ownerId,
    required double amount,
  }) async {
    try {
      await notificationRepository.sendNotificationToUser(
        userId: ownerId,
        title: '✅ Withdrawal Approved!',
        body:
            'Your referral withdrawal of ₹${amount.toStringAsFixed(0)} has been approved. '
            'Payment will be sent to your UPI shortly.',
        data: {
          'type': 'withdrawal_approved',
          'amount': amount.toString(),
        },
      );
    } catch (_) {
      // Silent failure - notification is non-critical
    }
  }

  /// Sends notification to owner when admin rejects their withdrawal.
  Future<void> notifyOwnerWithdrawalRejected({
    required String ownerId,
    required double amount,
    required String reason,
  }) async {
    try {
      await notificationRepository.sendNotificationToUser(
        userId: ownerId,
        title: '❌ Withdrawal Rejected',
        body:
            'Your withdrawal of ₹${amount.toStringAsFixed(0)} was rejected. '
            '${reason.isNotEmpty ? 'Reason: $reason. ' : ''}'
            'The amount has been refunded to your wallet.',
        data: {
          'type': 'withdrawal_rejected',
          'amount': amount.toString(),
          'reason': reason,
        },
      );
    } catch (_) {
      // Silent failure - notification is non-critical
    }
  }

  /// Helper to get plan name from subscription.
  String getPlanName(Subscription subscription) {
    final planNames = {
      'tier_99': 'Starter',
      'tier_149': 'Growth',
      'tier_199': 'Professional',
      'tier_299': 'Business',
      'tier_unlimited': 'Enterprise',
    };
    return planNames[subscription.planId] ?? 'Plan';
  }
}
