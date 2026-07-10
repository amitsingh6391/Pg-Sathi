import 'dart:io';
import 'dart:ui';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Service for PDF manipulation operations.
class PdfService {
  const PdfService();

  /// Convert PDF to images (one per page).
  Future<List<File>> convertPdfToImages(File pdfFile) async {
    if (!await pdfFile.exists()) {
      throw PdfException('PDF file does not exist');
    }

    try {
      final directory = await getTemporaryDirectory();
      final imageFiles = <File>[];

      // Open PDF document
      final document = await pdfx.PdfDocument.openFile(pdfFile.path);

      // Convert each page to image
      for (int i = 1; i <= document.pagesCount; i++) {
        final page = await document.getPage(i);

        // Render page to image with good quality
        final pageImage = await page.render(
          width: page.width * 2, // 2x resolution for better quality
          height: page.height * 2,
          format: pdfx.PdfPageImageFormat.png,
        );

        // Save to file
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final imagePath = path.join(
          directory.path,
          'pdf_page_${timestamp}_$i.png',
        );

        final imageFile = File(imagePath);
        await imageFile.writeAsBytes(pageImage!.bytes);
        imageFiles.add(imageFile);

        await page.close();
      }

      await document.close();

      return imageFiles;
    } catch (e) {
      throw PdfException('Failed to convert PDF to images: ${e.toString()}');
    }
  }

  /// Convert images to PDF.
  Future<File> convertImagesToPdf(List<File> imageFiles) async {
    if (imageFiles.isEmpty) {
      throw PdfException('No images provided');
    }

    for (final file in imageFiles) {
      if (!await file.exists()) {
        throw PdfException('Image file does not exist: ${file.path}');
      }
    }

    try {
      final document = PdfDocument();

      for (final imageFile in imageFiles) {
        final bytes = await imageFile.readAsBytes();
        final page = document.pages.add();

        // Load image
        final image = PdfBitmap(bytes);

        // Calculate dimensions to fit page while maintaining aspect ratio
        final pageSize = page.getClientSize();
        final imageWidth = image.width.toDouble();
        final imageHeight = image.height.toDouble();

        final scaleWidth = pageSize.width / imageWidth;
        final scaleHeight = pageSize.height / imageHeight;
        final scale = scaleWidth < scaleHeight ? scaleWidth : scaleHeight;

        final targetWidth = imageWidth * scale;
        final targetHeight = imageHeight * scale;

        // Center image on page
        final x = (pageSize.width - targetWidth) / 2;
        final y = (pageSize.height - targetHeight) / 2;

        // Draw image
        page.graphics.drawImage(
          image,
          Rect.fromLTWH(x, y, targetWidth, targetHeight),
        );
      }

      // Save PDF
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = path.join(directory.path, 'merged_$timestamp.pdf');

      final bytes = await document.save();
      document.dispose();

      final file = File(outputPath);
      await file.writeAsBytes(bytes);

      return file;
    } catch (e) {
      throw PdfException('Failed to convert images to PDF: ${e.toString()}');
    }
  }

  /// Extract pages from PDF.
  Future<File> extractPages({
    required File pdfFile,
    required int startPage,
    required int endPage,
  }) async {
    if (!await pdfFile.exists()) {
      throw PdfException('PDF file does not exist');
    }

    if (startPage < 1) {
      throw PdfException('Start page must be at least 1');
    }

    if (endPage < startPage) {
      throw PdfException(
        'End page must be greater than or equal to start page',
      );
    }

    try {
      final bytes = await pdfFile.readAsBytes();
      final sourceDocument = PdfDocument(inputBytes: bytes);

      if (endPage > sourceDocument.pages.count) {
        throw PdfException(
          'End page ($endPage) exceeds document page count (${sourceDocument.pages.count})',
        );
      }

      // Create new document with extracted pages
      final newDocument = PdfDocument();

      for (int i = startPage - 1; i < endPage; i++) {
        // Import page from source document
        final template = sourceDocument.pages[i].createTemplate();
        newDocument.pages.add().graphics.drawPdfTemplate(template, Offset.zero);
      }

      // Save extracted PDF
      final directory = await getTemporaryDirectory();
      final baseName = path.basenameWithoutExtension(pdfFile.path);
      final outputPath = path.join(
        directory.path,
        '${baseName}_pages_${startPage}_to_$endPage.pdf',
      );

      final outputBytes = await newDocument.save();
      newDocument.dispose();
      sourceDocument.dispose();

      final file = File(outputPath);
      await file.writeAsBytes(outputBytes);

      return file;
    } catch (e) {
      if (e is PdfException) rethrow;
      throw PdfException('Failed to extract pages: ${e.toString()}');
    }
  }

  /// Get page count of PDF.
  Future<int> getPageCount(File pdfFile) async {
    if (!await pdfFile.exists()) {
      throw PdfException('PDF file does not exist');
    }

    try {
      final bytes = await pdfFile.readAsBytes();
      final document = PdfDocument(inputBytes: bytes);
      final count = document.pages.count;
      document.dispose();
      return count;
    } catch (e) {
      throw PdfException('Failed to get page count: ${e.toString()}');
    }
  }
}

/// Exception thrown when PDF operations fail.
class PdfException implements Exception {
  const PdfException(this.message);

  final String message;

  @override
  String toString() => 'PdfException: $message';
}
