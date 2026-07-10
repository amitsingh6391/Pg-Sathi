import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';

/// Helper utility for admin contact actions (WhatsApp, phone calls).
/// Follows clean architecture by isolating side effects (URL launching).
class AdminContactHelper {
  AdminContactHelper._();

  /// Formats phone number for WhatsApp (with country code, no +).
  static String formatPhoneForWhatsApp(String phone) {
    if (phone.isEmpty) return '';

    String cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (cleaned.startsWith('+')) {
      cleaned = cleaned.substring(1);
    }
    if (!cleaned.startsWith('91') && cleaned.length == 10) {
      cleaned = '91$cleaned';
    }
    return cleaned;
  }

  /// Formats phone number for tel: URI.
  static String formatPhoneForCall(String phone) {
    if (phone.isEmpty) return '';

    String cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (!cleaned.startsWith('+')) {
      if (cleaned.startsWith('91') && cleaned.length == 12) {
        cleaned = '+$cleaned';
      } else if (cleaned.length == 10) {
        cleaned = '+91$cleaned';
      }
    }
    return cleaned;
  }

  /// Generates WhatsApp message for student to download app.
  static String generateAppDownloadMessage({
    required String studentName,
    required String libraryName,
  }) {
    return '''Hi $studentName! 👋

Your library *$libraryName* uses our official app to manage memberships and seat bookings.

📱 *Download the app now:*
• Android: ${AppConstants.playStoreUrl}
• iOS: ${AppConstants.appStoreUrl}

Manage your membership, book seats, and make payments - all in one place!

Thank you! 📚''';
  }

  /// Builds WhatsApp URL with app download message.
  static String buildWhatsAppUrlForStudent({
    required String studentPhone,
    required String studentName,
    required String libraryName,
  }) {
    final formattedPhone = formatPhoneForWhatsApp(studentPhone);
    if (formattedPhone.isEmpty) return '';

    final message = generateAppDownloadMessage(
      studentName: studentName,
      libraryName: libraryName,
    );
    final encodedMessage = Uri.encodeComponent(message);
    return 'https://wa.me/$formattedPhone?text=$encodedMessage';
  }

  /// Builds WhatsApp URL with custom message.
  static String buildWhatsAppUrl({
    required String phone,
    required String message,
  }) {
    final formattedPhone = formatPhoneForWhatsApp(phone);
    if (formattedPhone.isEmpty) return '';

    final encodedMessage = Uri.encodeComponent(message);
    return 'https://wa.me/$formattedPhone?text=$encodedMessage';
  }

  /// Builds tel: URI for phone calls.
  static String buildPhoneCallUrl(String phone) {
    final formattedPhone = formatPhoneForCall(phone);
    if (formattedPhone.isEmpty) return '';
    return 'tel:$formattedPhone';
  }

  /// Launches WhatsApp with app download message for student.
  static Future<bool> sendWhatsAppToStudent({
    required String studentPhone,
    required String studentName,
    required String libraryName,
  }) async {
    final url = buildWhatsAppUrlForStudent(
      studentPhone: studentPhone,
      studentName: studentName,
      libraryName: libraryName,
    );

    if (url.isEmpty) return false;

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Launches WhatsApp with custom message.
  static Future<bool> sendWhatsApp({
    required String phone,
    required String message,
  }) async {
    final url = buildWhatsAppUrl(phone: phone, message: message);

    if (url.isEmpty) return false;

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Launches phone dialer to call owner.
  static Future<bool> callOwner(String phone) async {
    final url = buildPhoneCallUrl(phone);

    if (url.isEmpty) return false;

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
