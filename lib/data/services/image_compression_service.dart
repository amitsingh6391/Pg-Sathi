import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Service for image compression operations.
class ImageCompressionService {
  const ImageCompressionService();

  /// Compress image to approximate target size in KB.
  /// Returns the compressed file.
  Future<File> compressToSize({
    required File imageFile,
    required int targetSizeKb,
  }) async {
    // Validate input
    if (targetSizeKb <= 0) {
      throw CompressionException('Target size must be greater than 0');
    }

    if (!await imageFile.exists()) {
      throw CompressionException('Image file does not exist');
    }

    final originalSize = await imageFile.length();
    final targetSizeBytes = targetSizeKb * 1024;

    // If already smaller than target, return a copy
    if (originalSize <= targetSizeBytes) {
      return await _copyFile(imageFile);
    }

    // Generate output path
    final directory = await getTemporaryDirectory();
    final fileName = path.basenameWithoutExtension(imageFile.path);
    final extension = path.extension(imageFile.path);
    final outputPath =
        path.join(directory.path, '${fileName}_compressed$extension');

    // Calculate initial quality based on size ratio
    int quality = ((targetSizeBytes / originalSize) * 100).clamp(10, 100).toInt();

    // Iterative compression with quality adjustment
    File? compressedFile;
    int attempts = 0;
    const maxAttempts = 5;

    while (attempts < maxAttempts) {
      final result = await FlutterImageCompress.compressAndGetFile(
        imageFile.absolute.path,
        outputPath,
        quality: quality,
        format: _getFormat(extension),
      );

      if (result == null) {
        throw CompressionException('Compression failed');
      }

      compressedFile = File(result.path);
      final compressedSize = await compressedFile.length();

      // Check if we're within acceptable range (±10%)
      final tolerance = (targetSizeBytes * 0.1).toInt();
      if ((compressedSize - targetSizeBytes).abs() <= tolerance ||
          compressedSize < targetSizeBytes) {
        break;
      }

      // Adjust quality for next attempt
      final ratio = targetSizeBytes / compressedSize;
      quality = (quality * ratio).clamp(10, 100).toInt();
      attempts++;
    }

    if (compressedFile == null) {
      throw CompressionException('Failed to compress image after $maxAttempts attempts');
    }

    return compressedFile;
  }

  /// Copy file to temporary directory.
  Future<File> _copyFile(File sourceFile) async {
    final directory = await getTemporaryDirectory();
    final fileName = path.basename(sourceFile.path);
    final targetPath = path.join(directory.path, fileName);
    return await sourceFile.copy(targetPath);
  }

  /// Get compression format from file extension.
  CompressFormat _getFormat(String extension) {
    switch (extension.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return CompressFormat.jpeg;
      case '.png':
        return CompressFormat.png;
      case '.webp':
        return CompressFormat.webp;
      case '.heic':
        return CompressFormat.heic;
      default:
        return CompressFormat.jpeg; // Default to JPEG
    }
  }
}

/// Exception thrown when compression fails.
class CompressionException implements Exception {
  const CompressionException(this.message);

  final String message;

  @override
  String toString() => 'CompressionException: $message';
}
