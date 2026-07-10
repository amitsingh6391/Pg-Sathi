import 'dart:io';

import 'package:equatable/equatable.dart';

/// Result of an OCR operation.
class OcrResult extends Equatable {
  const OcrResult({
    required this.text,
    required this.confidence,
    required this.imageFile,
  });

  /// Extracted text from image.
  final String text;

  /// Confidence level (0.0 to 1.0).
  final double confidence;

  /// Source image file.
  final File imageFile;

  @override
  List<Object?> get props => [text, confidence, imageFile];
}

/// Result of image compression operation.
class ImageCompressionResult extends Equatable {
  const ImageCompressionResult({
    required this.originalFile,
    required this.compressedFile,
    required this.originalSizeBytes,
    required this.compressedSizeBytes,
  });

  /// Original image file.
  final File originalFile;

  /// Compressed image file.
  final File compressedFile;

  /// Original file size in bytes.
  final int originalSizeBytes;

  /// Compressed file size in bytes.
  final int compressedSizeBytes;

  /// Size reduction percentage.
  double get reductionPercentage {
    if (originalSizeBytes == 0) return 0.0;
    return ((originalSizeBytes - compressedSizeBytes) / originalSizeBytes) * 100;
  }

  /// Human-readable original size.
  String get originalSizeFormatted => _formatBytes(originalSizeBytes);

  /// Human-readable compressed size.
  String get compressedSizeFormatted => _formatBytes(compressedSizeBytes);

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  List<Object?> get props => [
        originalFile,
        compressedFile,
        originalSizeBytes,
        compressedSizeBytes,
      ];
}

/// Result of PDF to images conversion.
class PdfToImagesResult extends Equatable {
  const PdfToImagesResult({
    required this.pdfFile,
    required this.images,
    required this.pageCount,
  });

  /// Source PDF file.
  final File pdfFile;

  /// Generated image files (one per page).
  final List<File> images;

  /// Total page count.
  final int pageCount;

  @override
  List<Object?> get props => [pdfFile, images, pageCount];
}

/// Result of images to PDF conversion.
class ImagesToPdfResult extends Equatable {
  const ImagesToPdfResult({
    required this.imageFiles,
    required this.pdfFile,
    required this.pageCount,
  });

  /// Source image files.
  final List<File> imageFiles;

  /// Generated PDF file.
  final File pdfFile;

  /// Total page count.
  final int pageCount;

  @override
  List<Object?> get props => [imageFiles, pdfFile, pageCount];
}

/// Result of PDF page extraction.
class PdfPageExtractionResult extends Equatable {
  const PdfPageExtractionResult({
    required this.sourcePdfFile,
    required this.extractedPdfFile,
    required this.startPage,
    required this.endPage,
    required this.pageCount,
  });

  /// Source PDF file.
  final File sourcePdfFile;

  /// Extracted PDF file.
  final File extractedPdfFile;

  /// Start page number (1-based).
  final int startPage;

  /// End page number (1-based).
  final int endPage;

  /// Total pages extracted.
  final int pageCount;

  @override
  List<Object?> get props => [
        sourcePdfFile,
        extractedPdfFile,
        startPage,
        endPage,
        pageCount,
      ];
}
