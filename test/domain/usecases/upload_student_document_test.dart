import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/student_document.dart';
import 'package:pg_manager/domain/failures/student_document_failures.dart';
import 'package:pg_manager/domain/repositories/student_document_repository.dart';
import 'package:pg_manager/domain/usecases/upload_student_document.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'upload_student_document_test.mocks.dart';

@GenerateMocks([StudentDocumentRepository])
void main() {
  late UploadStudentDocument useCase;
  late MockStudentDocumentRepository mockRepository;

  setUp(() {
    mockRepository = MockStudentDocumentRepository();
    useCase = UploadStudentDocument(repository: mockRepository);
  });

  const testStudentId = 'student-123';
  const testFilePath = '/path/to/document.pdf';
  const testFileName = 'document.pdf';

  final testDocument = StudentDocument(
    id: 'doc-123',
    studentId: testStudentId,
    fileName: testFileName,
    downloadUrl: 'https://storage.example.com/doc.pdf',
    fileType: StudentDocumentType.pdf,
    uploadedAt: DateTime.now(),
  );

  group('UploadStudentDocument', () {
    test('should_return_document_when_file_exists_and_valid_type', () async {
      // Arrange
      when(
        mockRepository.uploadDocument(
          studentId: testStudentId,
          filePath: testFilePath,
          fileName: testFileName,
          fileType: StudentDocumentType.pdf,
        ),
      ).thenAnswer((_) async => Right(testDocument));

      // Act
      final result = await useCase(
        UploadStudentDocumentParams(
          studentId: testStudentId,
          filePath: testFilePath,
          fileName: testFileName,
        ),
      );

      // Assert
      expect(result.isRight(), true);
      result.fold((l) => fail('Should not return failure'), (r) {
        expect(r.id, testDocument.id);
        expect(r.studentId, testStudentId);
        expect(r.fileName, testFileName);
      });
      verify(
        mockRepository.uploadDocument(
          studentId: testStudentId,
          filePath: testFilePath,
          fileName: testFileName,
          fileType: StudentDocumentType.pdf,
        ),
      ).called(1);
    });

    test('should_return_failure_when_file_type_invalid', () async {
      // Arrange
      const invalidFileName = 'document.txt';

      // Act
      final result = await useCase(
        UploadStudentDocumentParams(
          studentId: testStudentId,
          filePath: testFilePath,
          fileName: invalidFileName,
        ),
      );

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<StudentDocumentFailure>()),
        (r) => fail('Should return failure'),
      );
      verifyNever(
        mockRepository.uploadDocument(
          studentId: anyNamed('studentId'),
          filePath: anyNamed('filePath'),
          fileName: anyNamed('fileName'),
          fileType: anyNamed('fileType'),
        ),
      );
    });

    test('should_return_failure_when_repository_fails', () async {
      // Arrange
      when(
        mockRepository.uploadDocument(
          studentId: testStudentId,
          filePath: testFilePath,
          fileName: testFileName,
          fileType: StudentDocumentType.pdf,
        ),
      ).thenAnswer(
        (_) async =>
            const Left(StudentDocumentFailure(message: 'Upload failed')),
      );

      // Act
      final result = await useCase(
        UploadStudentDocumentParams(
          studentId: testStudentId,
          filePath: testFilePath,
          fileName: testFileName,
        ),
      );

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<StudentDocumentFailure>()),
        (r) => fail('Should return failure'),
      );
    });
  });
}
