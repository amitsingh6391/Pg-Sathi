import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Captures a [RepaintBoundary] as a PNG and saves or shares it.
class PgQrExporter {
  const PgQrExporter._();

  static Future<Uint8List> capture(GlobalKey boundaryKey) async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  static Future<void> saveToGallery(Uint8List png) =>
      Gal.putImageBytes(png, album: 'PG Sathi');

  static Future<void> share(
    Uint8List png, {
    required String text,
    Rect? origin,
  }) async {
    final XFile file;
    if (kIsWeb) {
      file = XFile.fromData(
        png,
        mimeType: 'image/png',
        name: 'pg_registration_qr.png',
      );
    } else {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/pg_registration_qr.png';
      await File(path).writeAsBytes(png, flush: true);
      file = XFile(path, mimeType: 'image/png');
    }
    await Share.shareXFiles([file], text: text, sharePositionOrigin: origin);
  }
}
