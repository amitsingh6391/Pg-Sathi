import 'dart:io';

import 'package:equatable/equatable.dart';

/// Parameters for OCR operation.
class OcrParams extends Equatable {
  const OcrParams({required this.imageFile});

  final File imageFile;

  @override
  List<Object?> get props => [imageFile];
}

/// Parameters for image compression.
class ImageCompressionParams extends Equatable {
  const ImageCompressionParams({
    required this.imageFile,
    required this.targetSizeKb,
  });

  /// Image file to compress.
  final File imageFile;

  /// Target size in kilobytes.
  final int targetSizeKb;

  @override
  List<Object?> get props => [imageFile, targetSizeKb];
}

/// Parameters for PDF to images conversion.
class PdfToImagesParams extends Equatable {
  const PdfToImagesParams({required this.pdfFile});

  final File pdfFile;

  @override
  List<Object?> get props => [pdfFile];
}

/// Parameters for images to PDF conversion.
class ImagesToPdfParams extends Equatable {
  const ImagesToPdfParams({required this.imageFiles});

  /// List of image files to convert (order matters).
  final List<File> imageFiles;

  @override
  List<Object?> get props => [imageFiles];
}

/// Parameters for PDF page extraction.
class PdfPageExtractionParams extends Equatable {
  const PdfPageExtractionParams({
    required this.pdfFile,
    required this.startPage,
    required this.endPage,
  });

  /// Source PDF file.
  final File pdfFile;

  /// Start page (1-based, inclusive).
  final int startPage;

  /// End page (1-based, inclusive).
  final int endPage;

  @override
  List<Object?> get props => [pdfFile, startPage, endPage];
}
