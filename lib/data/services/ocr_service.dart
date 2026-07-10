import 'dart:io';

/// Service for OCR operations.
///
/// OCR was part of the old utility tools module. It is intentionally disabled
/// in PG Sathi because the native ML Kit dependency blocks Apple Silicon iOS
/// simulator builds on newer Xcode/iOS runtimes.
class OcrService {
  const OcrService();

  /// Extract text from image file.
  Future<OcrServiceResult> extractText(File imageFile) async {
    throw const OcrException('OCR is not available in PG Sathi.');
  }
}

/// Result of OCR operation.
class OcrServiceResult {
  const OcrServiceResult({required this.text, required this.confidence});

  final String text;
  final double confidence;
}

/// Exception thrown when OCR fails.
class OcrException implements Exception {
  const OcrException(this.message);

  final String message;

  @override
  String toString() => 'OcrException: $message';
}
