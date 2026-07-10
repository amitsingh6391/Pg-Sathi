import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../core/core.dart';
import '../entities/student_document.dart';
import '../failures/student_document_failures.dart';
import '../repositories/student_document_repository.dart';

/// Use case for uploading a student verification document.
/// Validates file count (max 2) and file type before upload.
class UploadStudentDocument
    implements UseCase<StudentDocument, UploadStudentDocumentParams> {
  const UploadStudentDocument({required this.repository});

  final StudentDocumentRepository repository;

  @override
  Future<Either<Failure, StudentDocument>> call(
    UploadStudentDocumentParams params,
  ) async {
    try {
      // Validate file exists
      final file = File(params.filePath);
      if (!await file.exists()) {
        return const Left(StudentDocumentFailure(message: 'File not found'));
      }

      // Determine file type from extension
      final extension = params.fileName.split('.').last;
      final fileType = StudentDocumentType.fromExtension(extension);
      if (fileType == null) {
        return const Left(
          StudentDocumentFailure(
            message: 'Invalid file type. Only images and PDFs are allowed',
          ),
        );
      }

      // Upload document
      final result = await repository.uploadDocument(
        studentId: params.studentId,
        filePath: params.filePath,
        fileName: params.fileName,
        fileType: fileType,
      );

      return result;
    } catch (e) {
      return Left(
        StudentDocumentFailure(
          message: 'Failed to upload document: ${e.toString()}',
        ),
      );
    }
  }
}

/// Parameters for UploadStudentDocument use case.
class UploadStudentDocumentParams extends Equatable {
  const UploadStudentDocumentParams({
    required this.studentId,
    required this.filePath,
    required this.fileName,
  });

  final String studentId;
  final String filePath;
  final String fileName;

  @override
  List<Object?> get props => [studentId, filePath, fileName];
}
