import 'package:intl/intl.dart';

/// Helper for generating subscription-related messages.
class SubscriptionMessagingHelper {
  SubscriptionMessagingHelper._();

  /// Generates WhatsApp message for expiring subscription.
  static String generateExpiringSubscriptionMessage({
    required String ownerName,
    required String libraryName,
    required DateTime expiryDate,
    required int daysRemaining,
    required double amount,
  }) {
    final formattedDate = DateFormat('dd MMM yyyy').format(expiryDate);

    if (daysRemaining == 0) {
      return '''Hi $ownerName! 👋

Your subscription for *$libraryName* expires *today* ($formattedDate).

Please renew your subscription to continue managing your library without interruption.

Amount: ₹${amount.toStringAsFixed(0)}

Thank you! 📚''';
    } else if (daysRemaining == 1) {
      return '''Hi $ownerName! 👋

Your subscription for *$libraryName* expires *tomorrow* ($formattedDate).

Please renew your subscription to continue managing your library without interruption.

Amount: ₹${amount.toStringAsFixed(0)}

Thank you! 📚''';
    } else {
      return '''Hi $ownerName! 👋

Your subscription for *$libraryName* expires on *$formattedDate* ($daysRemaining days remaining).

Please renew your subscription to continue managing your library without interruption.

Amount: ₹${amount.toStringAsFixed(0)}

Thank you! 📚''';
    }
  }

  /// Generates WhatsApp message for expiring trial.
  static String generateExpiringTrialMessage({
    required String ownerName,
    required String libraryName,
    required DateTime expiryDate,
    required int daysRemaining,
  }) {
    final formattedDate = DateFormat('dd MMM yyyy').format(expiryDate);

    if (daysRemaining == 0) {
      return '''Hi $ownerName! 👋

Your free trial for *$libraryName* expires *today* ($formattedDate).

Subscribe now to continue managing your library without interruption.

Thank you! 📚''';
    } else if (daysRemaining == 1) {
      return '''Hi $ownerName! 👋

Your free trial for *$libraryName* expires *tomorrow* ($formattedDate).

Subscribe now to continue managing your library without interruption.

Thank you! 📚''';
    } else {
      return '''Hi $ownerName! 👋

Your free trial for *$libraryName* expires on *$formattedDate* ($daysRemaining days remaining).

Subscribe now to continue managing your library without interruption.

Thank you! 📚''';
    }
  }

  /// Generates push notification title for expiring subscription.
  static String getExpiringSubscriptionTitle(int daysRemaining) {
    if (daysRemaining == 0) {
      return 'Subscription Expires Today';
    } else if (daysRemaining == 1) {
      return 'Subscription Expires Tomorrow';
    } else {
      return 'Subscription Expiring Soon';
    }
  }

  /// Generates push notification body for expiring subscription.
  static String generateExpiringSubscriptionNotificationBody({
    required String libraryName,
    required int daysRemaining,
  }) {
    if (daysRemaining == 0) {
      return 'Your subscription for $libraryName expires today. Please renew to continue.';
    } else if (daysRemaining == 1) {
      return 'Your subscription for $libraryName expires tomorrow. Please renew to continue.';
    } else {
      return 'Your subscription for $libraryName expires in $daysRemaining days. Please renew to continue.';
    }
  }

  /// Generates push notification title for expiring trial.
  static String getExpiringTrialTitle(int daysRemaining) {
    if (daysRemaining == 0) {
      return 'Trial Expires Today';
    } else if (daysRemaining == 1) {
      return 'Trial Expires Tomorrow';
    } else {
      return 'Trial Expiring Soon';
    }
  }

  /// Generates push notification body for expiring trial.
  static String generateExpiringTrialNotificationBody({
    required String libraryName,
    required int daysRemaining,
  }) {
    if (daysRemaining == 0) {
      return 'Your free trial for $libraryName expires today. Subscribe now to continue.';
    } else if (daysRemaining == 1) {
      return 'Your free trial for $libraryName expires tomorrow. Subscribe now to continue.';
    } else {
      return 'Your free trial for $libraryName expires in $daysRemaining days. Subscribe now to continue.';
    }
  }
}
