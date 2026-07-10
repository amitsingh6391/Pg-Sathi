import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../core/core.dart';
import '../entities/student_document.dart';
import '../failures/student_document_failures.dart';
import '../repositories/student_document_repository.dart';

/// Use case for getting all documents uploaded by a student.
class GetStudentDocuments
    implements UseCase<List<StudentDocument>, GetStudentDocumentsParams> {
  const GetStudentDocuments({required this.repository});

  final StudentDocumentRepository repository;

  @override
  Future<Either<Failure, List<StudentDocument>>> call(
    GetStudentDocumentsParams params,
  ) async {
    try {
      final result = await repository.getStudentDocuments(params.studentId);

      return result.fold((failure) => Left(failure), (documents) {
        // Sort by upload date (newest first)
        final sorted = List<StudentDocument>.from(documents);
        sorted.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
        return Right(sorted);
      });
    } catch (e) {
      return Left(
        StudentDocumentFailure(
          message: 'Failed to fetch documents: ${e.toString()}',
        ),
      );
    }
  }
}

/// Parameters for GetStudentDocuments use case.
class GetStudentDocumentsParams extends Equatable {
  const GetStudentDocumentsParams({required this.studentId});

  final String studentId;

  @override
  List<Object?> get props => [studentId];
}
