import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../core/core.dart';
import '../entities/student_document.dart';
import '../failures/student_document_failures.dart';
import '../repositories/student_document_repository.dart';

/// Use case for approving a student document.
class ApproveStudentDocument
    implements UseCase<StudentDocument, ApproveStudentDocumentParams> {
  const ApproveStudentDocument({required this.repository});

  final StudentDocumentRepository repository;

  @override
  Future<Either<Failure, StudentDocument>> call(
    ApproveStudentDocumentParams params,
  ) async {
    try {
      final result = await repository.approveDocument(
        documentId: params.documentId,
        approvedBy: params.approvedBy,
      );

      return result;
    } catch (e) {
      return Left(
        StudentDocumentFailure(
          message: 'Failed to approve document: ${e.toString()}',
        ),
      );
    }
  }
}

/// Parameters for ApproveStudentDocument use case.
class ApproveStudentDocumentParams extends Equatable {
  const ApproveStudentDocumentParams({
    required this.documentId,
    required this.approvedBy,
  });

  final String documentId;
  final String approvedBy;

  @override
  List<Object?> get props => [documentId, approvedBy];
}
