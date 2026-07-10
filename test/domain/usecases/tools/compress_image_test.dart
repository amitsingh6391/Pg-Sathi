import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:pg_manager/domain/failures/tools_failures.dart';
import 'package:pg_manager/domain/entities/tool_params.dart';
import 'package:pg_manager/domain/entities/tool_result.dart';
import 'package:pg_manager/domain/repositories/tools_repository.dart';
import 'package:pg_manager/domain/usecases/tools/compress_image.dart';

class MockToolsRepository extends Mock implements ToolsRepository {}

class MockFile extends Mock implements File {}

void main() {
  late CompressImage useCase;
  late MockToolsRepository mockRepository;
  late MockFile mockFile;
  late MockFile mockCompressedFile;

  setUp(() {
    mockRepository = MockToolsRepository();
    useCase = CompressImage(repository: mockRepository);
    mockFile = MockFile();
    mockCompressedFile = MockFile();
  });

  group('CompressImage', () {
    test('should_compress_image_successfully_when_params_are_valid', () async {
      // Arrange
      final params = ImageCompressionParams(
        imageFile: mockFile,
        targetSizeKb: 100,
      );
      final expectedResult = ImageCompressionResult(
        originalFile: mockFile,
        compressedFile: mockCompressedFile,
        originalSizeBytes: 500000,
        compressedSizeBytes: 100000,
      );

      when(() => mockRepository.compressImage(params))
          .thenAnswer((_) async => Right(expectedResult));

      // Act
      final result = await useCase(params);

      // Assert
      expect(result, Right(expectedResult));
      verify(() => mockRepository.compressImage(params)).called(1);
    });

    test('should_return_failure_when_compression_fails', () async {
      // Arrange
      final params = ImageCompressionParams(
        imageFile: mockFile,
        targetSizeKb: 100,
      );
      const failure = ToolsFailure(message: 'Failed to compress image');

      when(() => mockRepository.compressImage(params))
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase(params);

      // Assert
      expect(result, const Left(failure));
      verify(() => mockRepository.compressImage(params)).called(1);
    });

    test('should_calculate_reduction_percentage_correctly', () {
      // Arrange
      final result = ImageCompressionResult(
        originalFile: mockFile,
        compressedFile: mockCompressedFile,
        originalSizeBytes: 1000000,
        compressedSizeBytes: 250000,
      );

      // Act & Assert
      expect(result.reductionPercentage, 75.0);
    });

    test('should_format_file_sizes_correctly', () {
      // Arrange & Act
      final resultBytes = ImageCompressionResult(
        originalFile: mockFile,
        compressedFile: mockCompressedFile,
        originalSizeBytes: 512,
        compressedSizeBytes: 256,
      );

      final resultKB = ImageCompressionResult(
        originalFile: mockFile,
        compressedFile: mockCompressedFile,
        originalSizeBytes: 51200,
        compressedSizeBytes: 25600,
      );

      final resultMB = ImageCompressionResult(
        originalFile: mockFile,
        compressedFile: mockCompressedFile,
        originalSizeBytes: 5242880,
        compressedSizeBytes: 2621440,
      );

      // Assert
      expect(resultBytes.originalSizeFormatted, '512 B');
      expect(resultKB.originalSizeFormatted, '50.0 KB');
      expect(resultMB.originalSizeFormatted, '5.0 MB');
    });
  });
}
