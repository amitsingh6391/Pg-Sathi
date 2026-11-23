import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'whatsapp_launcher.dart';

const _whatsAppShareChannel = MethodChannel('in.pgsathi.app/whatsapp_share');

/// Downloads the owner's UPI QR image into the temp folder so sending is instant.
Future<File> prepareReminderQr(String qrUrl) async {
  final response = await http.get(Uri.parse(qrUrl));
  if (response.statusCode != 200) {
    throw Exception('Could not load the UPI QR code');
  }
  final mimeType = response.headers['content-type'] ?? 'image/png';
  final extension = mimeType.contains('jpeg') ? 'jpg' : 'png';
  final dir = await getTemporaryDirectory();
  return File('${dir.path}/upi_qr.$extension').writeAsBytes(response.bodyBytes);
}

/// Opens the WhatsApp chat of [phone] (a resident) with [message] and copies [qrFile] to
/// the clipboard so the owner pastes it there. Works for unsaved numbers.
/// Returns true when the QR was copied and still has to be pasted.
Future<bool> shareReminderWithQr({
  required String phone,
  required String message,
  required File? qrFile,
  Rect? origin,
}) async {
  final isMobile =
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  if (isMobile || qrFile == null) {
    var copied = false;
    if (isMobile && qrFile != null) {
      try {
        copied =
            await _whatsAppShareChannel.invokeMethod<bool>(
              'copyImageToClipboard',
              {'filePath': qrFile.path},
            ) ??
            false;
      } catch (_) {
        // Still open the chat; the owner can send the QR separately.
      }
    }
    final opened = await WhatsAppLauncher.launch(
      phone: phone,
      message: message,
    );
    if (!opened) throw Exception('Could not open WhatsApp');
    return copied;
  }

  final mimeType = qrFile.path.endsWith('.jpg') ? 'image/jpeg' : 'image/png';
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(qrFile.path, mimeType: mimeType)],
      text: message,
      sharePositionOrigin: origin,
    ),
  );
  return false;
}
