import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:pg_manager/domain/failures/tools_failures.dart';
import 'package:pg_manager/domain/entities/tool_params.dart';
import 'package:pg_manager/domain/entities/tool_result.dart';
import 'package:pg_manager/domain/repositories/tools_repository.dart';
import 'package:pg_manager/domain/usecases/tools/convert_images_to_pdf.dart';

class MockToolsRepository extends Mock implements ToolsRepository {}

class MockFile extends Mock implements File {}

void main() {
  late ConvertImagesToPdf useCase;
  late MockToolsRepository mockRepository;

  setUp(() {
    mockRepository = MockToolsRepository();
    useCase = ConvertImagesToPdf(repository: mockRepository);
  });

  group('ConvertImagesToPdf', () {
    test('should_convert_images_to_pdf_successfully', () async {
      // Arrange
      final imageFiles = [MockFile(), MockFile(), MockFile()];
      final pdfFile = MockFile();
      final params = ImagesToPdfParams(imageFiles: imageFiles);
      final expectedResult = ImagesToPdfResult(
        imageFiles: imageFiles,
        pdfFile: pdfFile,
        pageCount: 3,
      );

      when(() => mockRepository.convertImagesToPdf(params))
          .thenAnswer((_) async => Right(expectedResult));

      // Act
      final result = await useCase(params);

      // Assert
      expect(result, Right(expectedResult));
      verify(() => mockRepository.convertImagesToPdf(params)).called(1);
    });

    test('should_return_failure_when_conversion_fails', () async {
      // Arrange
      final imageFiles = [MockFile()];
      final params = ImagesToPdfParams(imageFiles: imageFiles);
      const failure = ToolsFailure(message: 'Failed to convert images to PDF');

      when(() => mockRepository.convertImagesToPdf(params))
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase(params);

      // Assert
      expect(result, const Left(failure));
      verify(() => mockRepository.convertImagesToPdf(params)).called(1);
    });
  });
}
