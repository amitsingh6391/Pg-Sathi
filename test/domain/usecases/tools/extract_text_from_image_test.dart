import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:pg_manager/domain/failures/tools_failures.dart';
import 'package:pg_manager/domain/entities/tool_params.dart';
import 'package:pg_manager/domain/entities/tool_result.dart';
import 'package:pg_manager/domain/repositories/tools_repository.dart';
import 'package:pg_manager/domain/usecases/tools/extract_text_from_image.dart';

class MockToolsRepository extends Mock implements ToolsRepository {}

class MockFile extends Mock implements File {}

void main() {
  late ExtractTextFromImage useCase;
  late MockToolsRepository mockRepository;
  late MockFile mockFile;

  setUp(() {
    mockRepository = MockToolsRepository();
    useCase = ExtractTextFromImage(repository: mockRepository);
    mockFile = MockFile();
  });

  group('ExtractTextFromImage', () {
    test('should_extract_text_successfully_when_image_is_valid', () async {
      // Arrange
      final params = OcrParams(imageFile: mockFile);
      final expectedResult = OcrResult(
        text: 'Sample extracted text',
        confidence: 0.95,
        imageFile: mockFile,
      );

      when(() => mockRepository.extractTextFromImage(params))
          .thenAnswer((_) async => Right(expectedResult));

      // Act
      final result = await useCase(params);

      // Assert
      expect(result, Right(expectedResult));
      verify(() => mockRepository.extractTextFromImage(params)).called(1);
    });

    test('should_return_failure_when_ocr_fails', () async {
      // Arrange
      final params = OcrParams(imageFile: mockFile);
      const failure = ToolsFailure(message: 'Failed to extract text');

      when(() => mockRepository.extractTextFromImage(params))
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase(params);

      // Assert
      expect(result, const Left(failure));
      verify(() => mockRepository.extractTextFromImage(params)).called(1);
    });
  });
}
