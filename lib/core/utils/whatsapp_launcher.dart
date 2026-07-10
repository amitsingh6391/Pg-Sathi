import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class WhatsAppLauncher {
  WhatsAppLauncher._();

  static Future<bool> launchFromWaUrl(String waUrl) async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final parsed = Uri.parse(waUrl);
        final phone =
            parsed.pathSegments.isNotEmpty ? parsed.pathSegments.first : '';
        final text = parsed.queryParameters['text'] ?? '';

        if (phone.isNotEmpty) {
          final androidUri = Uri(
            scheme: 'whatsapp',
            host: 'send',
            queryParameters: {'phone': phone, 'text': text},
          );
          if (await canLaunchUrl(androidUri)) {
            return launchUrl(androidUri, mode: LaunchMode.externalApplication);
          }
        }
      } catch (_) {
        // Fall through to the wa.me fallback below.
      }
    }

    // iOS path (always) and Android fallback (neither WhatsApp app installed).
    final uri = Uri.parse(waUrl);
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  static Future<bool> launch({
    required String phone,
    required String message,
  }) async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidUri = Uri(
        scheme: 'whatsapp',
        host: 'send',
        queryParameters: {'phone': phone, 'text': message},
      );
      if (await canLaunchUrl(androidUri)) {
        return launchUrl(androidUri, mode: LaunchMode.externalApplication);
      }
    }

    final uri = Uri.parse(
      'https://wa.me/$phone?text=${Uri.encodeQueryComponent(message)}',
    );
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }
}
