import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Helper class for downloading files in a cross-platform way.
/// Handles web and mobile platforms differently.
class FileDownloadHelper {
  /// Downloads a file with the given bytes and filename.
  /// Works on both web and mobile platforms.
  /// [sharePositionOrigin] is required on iOS/iPad for share sheet positioning.
  static Future<void> downloadFile({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
    Rect? sharePositionOrigin,
  }) async {
    try {
      if (kIsWeb) {
        try {
          await Share.shareXFiles([
            XFile.fromData(
              bytes,
              name: fileName,
              mimeType: mimeType ?? _getMimeType(fileName),
            ),
          ], subject: fileName);
        } on PlatformException catch (e) {
          throw Exception('Web download failed: ${e.message ?? e.code}');
        }
      } else {
        // Mobile: Save to temp directory and share
        final tempDir = await getTemporaryDirectory();

        // Sanitize filename to avoid path issues
        final sanitizedFileName = fileName.replaceAll(
          RegExp(r'[<>:"/\\|?*]'),
          '_',
        );
        final file = File('${tempDir.path}/$sanitizedFileName');

        // Ensure directory exists
        if (!await tempDir.exists()) {
          await tempDir.create(recursive: true);
        }

        // Write file
        await file.writeAsBytes(bytes);

        // Verify file was written and has content
        if (!await file.exists()) {
          throw Exception('Failed to create file: $sanitizedFileName');
        }

        final fileSize = await file.length();
        if (fileSize == 0) {
          throw Exception('File was created but is empty: $sanitizedFileName');
        }

        // Share file with proper error handling
        // iOS/iPad requires sharePositionOrigin for share sheet (must be non-null and valid)
        try {
          // Always provide a valid position on iOS
          final position = sharePositionOrigin ?? _getDefaultSharePosition();
          await Share.shareXFiles(
            [XFile(file.path)],
            subject: sanitizedFileName,
            sharePositionOrigin: position,
          );
        } on PlatformException catch (e) {
          // Platform-specific error (e.g., no app to handle file)
          throw Exception('Cannot share file: ${e.message ?? e.code}');
        }
      }
    } on PlatformException catch (e) {
      throw Exception('Platform error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to download file: ${e.toString()}');
    }
  }

  /// Downloads a file and opens it (for mobile) or downloads it (for web).
  /// [sharePositionOrigin] is required on iOS/iPad for share sheet positioning.
  static Future<void> downloadAndOpenFile({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
    Rect? sharePositionOrigin,
  }) async {
    if (kIsWeb) {
      // Web: Just download the file
      await downloadFile(bytes: bytes, fileName: fileName, mimeType: mimeType);
    } else {
      // Mobile: Save to temp directory and open
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      // Try to open the file
      // Always provide a valid position on iOS
      final position = sharePositionOrigin ?? _getDefaultSharePosition();
      try {
        // For PDFs and other documents, we can use open_filex
        // But for now, just download/share
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: fileName,
          sharePositionOrigin: position,
        );
      } catch (e) {
        // If opening fails, just share
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: fileName,
          sharePositionOrigin: position,
        );
      }
    }
  }

  static Rect _getDefaultSharePosition() {
    if (Platform.isIOS) {
      return const Rect.fromLTWH(50, 750, 300, 60);
    }

    return const Rect.fromLTWH(0, 0, 1, 1);
  }

  /// Gets MIME type from file extension.
  static String _getMimeType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      default:
        return 'application/octet-stream';
    }
  }
}
