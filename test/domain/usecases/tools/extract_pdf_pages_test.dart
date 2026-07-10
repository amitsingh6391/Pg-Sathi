import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:pg_manager/domain/failures/tools_failures.dart';
import 'package:pg_manager/domain/entities/tool_params.dart';
import 'package:pg_manager/domain/entities/tool_result.dart';
import 'package:pg_manager/domain/repositories/tools_repository.dart';
import 'package:pg_manager/domain/usecases/tools/extract_pdf_pages.dart';

class MockToolsRepository extends Mock implements ToolsRepository {}

class MockFile extends Mock implements File {}

void main() {
  late ExtractPdfPages useCase;
  late MockToolsRepository mockRepository;

  setUp(() {
    mockRepository = MockToolsRepository();
    useCase = ExtractPdfPages(repository: mockRepository);
  });

  group('ExtractPdfPages', () {
    test('should_extract_pdf_pages_successfully', () async {
      // Arrange
      final sourcePdf = MockFile();
      final extractedPdf = MockFile();
      final params = PdfPageExtractionParams(
        pdfFile: sourcePdf,
        startPage: 2,
        endPage: 5,
      );
      final expectedResult = PdfPageExtractionResult(
        sourcePdfFile: sourcePdf,
        extractedPdfFile: extractedPdf,
        startPage: 2,
        endPage: 5,
        pageCount: 4,
      );

      when(() => mockRepository.extractPdfPages(params))
          .thenAnswer((_) async => Right(expectedResult));

      // Act
      final result = await useCase(params);

      // Assert
      expect(result, Right(expectedResult));
      expect(result.getOrElse(() => throw Exception()).pageCount, 4);
      verify(() => mockRepository.extractPdfPages(params)).called(1);
    });

    test('should_return_failure_when_extraction_fails', () async {
      // Arrange
      final sourcePdf = MockFile();
      final params = PdfPageExtractionParams(
        pdfFile: sourcePdf,
        startPage: 1,
        endPage: 10,
      );
      const failure = ToolsFailure(message: 'Failed to extract pages');

      when(() => mockRepository.extractPdfPages(params))
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase(params);

      // Assert
      expect(result, const Left(failure));
      verify(() => mockRepository.extractPdfPages(params)).called(1);
    });
  });
}
