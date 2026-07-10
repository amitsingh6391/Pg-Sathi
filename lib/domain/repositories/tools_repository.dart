import 'package:dartz/dartz.dart';

import '../core/failure.dart';
import '../entities/tool_params.dart';
import '../entities/tool_result.dart';

/// Repository for student tools functionality.
abstract class ToolsRepository {
  /// Extract text from image using OCR.
  Future<Either<Failure, OcrResult>> extractTextFromImage(OcrParams params);

  /// Compress image to target size.
  Future<Either<Failure, ImageCompressionResult>> compressImage(
    ImageCompressionParams params,
  );

  /// Convert PDF to images.
  Future<Either<Failure, PdfToImagesResult>> convertPdfToImages(
    PdfToImagesParams params,
  );

  /// Convert images to PDF.
  Future<Either<Failure, ImagesToPdfResult>> convertImagesToPdf(
    ImagesToPdfParams params,
  );

  /// Extract pages from PDF.
  Future<Either<Failure, PdfPageExtractionResult>> extractPdfPages(
    PdfPageExtractionParams params,
  );
}
