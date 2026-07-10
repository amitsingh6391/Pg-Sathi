import 'package:dartz/dartz.dart';

import '../../domain/core/failure.dart';
import '../../domain/failures/tools_failures.dart';
import '../../domain/entities/tool_params.dart';
import '../../domain/entities/tool_result.dart';
import '../../domain/repositories/tools_repository.dart';
import '../services/image_compression_service.dart';
import '../services/ocr_service.dart';
import '../services/pdf_service.dart';

/// Implementation of ToolsRepository.
class ToolsRepositoryImpl implements ToolsRepository {
  const ToolsRepositoryImpl({
    required this.ocrService,
    required this.compressionService,
    required this.pdfService,
  });

  final OcrService ocrService;
  final ImageCompressionService compressionService;
  final PdfService pdfService;

  @override
  Future<Either<Failure, OcrResult>> extractTextFromImage(
    OcrParams params,
  ) async {
    try {
      final result = await ocrService.extractText(params.imageFile);

      return Right(
        OcrResult(
          text: result.text,
          confidence: result.confidence,
          imageFile: params.imageFile,
        ),
      );
    } on OcrException catch (e) {
      return Left(ToolsFailure(message: e.message));
    } catch (e) {
      return Left(ToolsFailure(message: 'Failed to extract text: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, ImageCompressionResult>> compressImage(
    ImageCompressionParams params,
  ) async {
    try {
      final originalSize = await params.imageFile.length();

      final compressedFile = await compressionService.compressToSize(
        imageFile: params.imageFile,
        targetSizeKb: params.targetSizeKb,
      );

      final compressedSize = await compressedFile.length();

      return Right(
        ImageCompressionResult(
          originalFile: params.imageFile,
          compressedFile: compressedFile,
          originalSizeBytes: originalSize,
          compressedSizeBytes: compressedSize,
        ),
      );
    } on CompressionException catch (e) {
      return Left(ToolsFailure(message: e.message));
    } catch (e) {
      return Left(ToolsFailure(message: 'Failed to compress image: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, PdfToImagesResult>> convertPdfToImages(
    PdfToImagesParams params,
  ) async {
    try {
      final images = await pdfService.convertPdfToImages(params.pdfFile);

      return Right(
        PdfToImagesResult(
          pdfFile: params.pdfFile,
          images: images,
          pageCount: images.length,
        ),
      );
    } on PdfException catch (e) {
      return Left(ToolsFailure(message: e.message));
    } catch (e) {
      return Left(
        ToolsFailure(message: 'Failed to convert PDF to images: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, ImagesToPdfResult>> convertImagesToPdf(
    ImagesToPdfParams params,
  ) async {
    try {
      final pdfFile = await pdfService.convertImagesToPdf(params.imageFiles);

      return Right(
        ImagesToPdfResult(
          imageFiles: params.imageFiles,
          pdfFile: pdfFile,
          pageCount: params.imageFiles.length,
        ),
      );
    } on PdfException catch (e) {
      return Left(ToolsFailure(message: e.message));
    } catch (e) {
      return Left(
        ToolsFailure(message: 'Failed to convert images to PDF: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, PdfPageExtractionResult>> extractPdfPages(
    PdfPageExtractionParams params,
  ) async {
    try {
      final extractedFile = await pdfService.extractPages(
        pdfFile: params.pdfFile,
        startPage: params.startPage,
        endPage: params.endPage,
      );

      final pageCount = params.endPage - params.startPage + 1;

      return Right(
        PdfPageExtractionResult(
          sourcePdfFile: params.pdfFile,
          extractedPdfFile: extractedFile,
          startPage: params.startPage,
          endPage: params.endPage,
          pageCount: pageCount,
        ),
      );
    } on PdfException catch (e) {
      return Left(ToolsFailure(message: e.message));
    } catch (e) {
      return Left(
        ToolsFailure(message: 'Failed to extract PDF pages: ${e.toString()}'),
      );
    }
  }
}
