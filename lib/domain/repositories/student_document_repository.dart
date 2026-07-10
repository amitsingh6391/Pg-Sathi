import 'package:dartz/dartz.dart';

import '../core/failure.dart';
import '../entities/student_document.dart';

/// Repository interface for student documents and ID cards.
/// Abstracts data operations for student verification documents.
abstract class StudentDocumentRepository {
  /// Uploads a student document to Firebase Storage.
  /// Returns the created StudentDocument entity.
  Future<Either<Failure, StudentDocument>> uploadDocument({
    required String studentId,
    required String filePath,
    required String fileName,
    required StudentDocumentType fileType,
  });

  /// Gets all documents for a student.
  Future<Either<Failure, List<StudentDocument>>> getStudentDocuments(
    String studentId,
  );

  /// Deletes a student document.
  Future<Either<Failure, void>> deleteDocument(String documentId);

  /// Approves a student document.
  Future<Either<Failure, StudentDocument>> approveDocument({
    required String documentId,
    required String approvedBy,
  });

  /// Rejects a student document.
  Future<Either<Failure, StudentDocument>> rejectDocument({
    required String documentId,
    required String rejectedBy,
  });

  /// Batch updates documents to link them to a user ID.
  /// Updates documents where studentId matches the phone number.
  /// Used when student registers and documents need to be linked.
  Future<Either<Failure, void>> batchLinkDocumentsToUser({
    required String phoneNumber,
    required String userId,
  });
}
