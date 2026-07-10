import '../../../../domain/usecases/get_occupied_seats.dart';
import '../../../../domain/entities/library.dart';

/// Helper utility for building WhatsApp URLs from OccupiedSeatInfo.
class ReminderWhatsAppHelper {
  /// Formats phone number for WhatsApp (with country code, no +).
  static String formatPhoneForWhatsApp(String? phone) {
    if (phone == null || phone.isEmpty) return '';

    String cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (cleaned.startsWith('+')) {
      cleaned = cleaned.substring(1);
    }
    if (!cleaned.startsWith('91') && cleaned.length == 10) {
      cleaned = '91$cleaned';
    }
    return cleaned;
  }

  /// Builds WhatsApp URL for a reminder message.
  static String buildWhatsAppUrl({
    required String phone,
    required String message,
  }) {
    final formattedPhone = formatPhoneForWhatsApp(phone);
    if (formattedPhone.isEmpty) return '';

    final encodedMessage = Uri.encodeComponent(message);
    return 'https://wa.me/$formattedPhone?text=$encodedMessage';
  }

  /// Generates reminder message based on tenant stay info and reminder type.
  static String generateReminderMessage({
    required OccupiedSeatInfo seatInfo,
    required Library library,
    required ReminderType type,
    double? amount,
  }) {
    final tenantName = seatInfo.displayName;
    final pgName = library.name;

    switch (type) {
      case ReminderType.pendingPayment:
        return '''Hi $tenantName,

Your rent payment of ₹${amount?.toStringAsFixed(0) ?? '0'} is pending for your stay at *$pgName*.

Please complete the payment to activate your stay.

Thank you!''';

      case ReminderType.partialPayment:
        return '''Hi $tenantName,

You have a remaining rent balance of ₹${amount?.toStringAsFixed(0) ?? '0'} for your stay at *$pgName*.

Please complete the payment to keep your stay active.

Thank you!''';

      case ReminderType.expiry:
        final daysRemaining = seatInfo.daysRemaining;
        final endDate = seatInfo.membership.endDate;
        final formattedDate = '${endDate.day}/${endDate.month}/${endDate.year}';

        if (daysRemaining == 0) {
          return '''Hi $tenantName,

Your stay at *$pgName* expires *today* ($formattedDate).

Please renew to continue your bed without interruption.

Thank you!''';
        } else if (daysRemaining == 1) {
          return '''Hi $tenantName,

Your stay at *$pgName* expires *tomorrow* ($formattedDate).

Please renew to continue your bed without interruption.

Thank you!''';
        } else {
          return '''Hi $tenantName,

Your stay at *$pgName* is expiring on *$formattedDate* ($daysRemaining days left).

Please renew to continue your bed without interruption.

Thank you!''';
        }
    }
  }

  /// Builds complete WhatsApp URL for reminder.
  static String? buildReminderWhatsAppUrl({
    required OccupiedSeatInfo seatInfo,
    required Library library,
    required ReminderType type,
    double? amount,
    String? customMessage,
  }) {
    final phone = seatInfo.studentPhone ?? seatInfo.membership.phoneNumber;
    if (phone.isEmpty) return null;

    final message = customMessage?.trim().isNotEmpty == true
        ? customMessage!
        : generateReminderMessage(
            seatInfo: seatInfo,
            library: library,
            type: type,
            amount: amount,
          );

    return buildWhatsAppUrl(phone: phone, message: message);
  }
}

/// Type of reminder to send.
enum ReminderType { pendingPayment, partialPayment, expiry }
