import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

const _channel = MethodChannel('in.pgsathi.app/whatsapp_share');

bool get _isMobile =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// Copies the image at [path] to the clipboard for pasting in WhatsApp.
/// Returns true when copied.
Future<bool> copyImageToClipboard(String path) async {
  if (!_isMobile) return false;
  try {
    return await _channel.invokeMethod<bool>('copyImageToClipboard', {
          'filePath': path,
        }) ??
        false;
  } catch (e) {
    debugPrint('copyImageToClipboard failed: $e');
    return false;
  }
}

/// Renders the first page of the PDF [bytes] to a PNG and copies it
/// (WhatsApp accepts pasted images, not PDFs). Returns true when copied.
Future<bool> copyPdfAsImageToClipboard(Uint8List bytes) async {
  if (!_isMobile) return false;
  try {
    // 144 dpi = 2x the PDF's 72-point layout, sharp enough for chat.
    final page = await Printing.raster(bytes, pages: [0], dpi: 144).first;
    final png = await page.toPng();

    final dir = await getTemporaryDirectory();
    final file = await File('${dir.path}/invoice_share.png').writeAsBytes(png);
    return await copyImageToClipboard(file.path);
  } catch (e) {
    debugPrint('copyPdfAsImageToClipboard failed: $e');
    return false;
  }
}
