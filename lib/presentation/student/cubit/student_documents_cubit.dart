import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/repositories/student_document_repository.dart';
import '../../../domain/usecases/get_student_documents.dart';
import '../../../domain/usecases/upload_student_document.dart';
import 'student_documents_state.dart';

/// Cubit for managing student document upload and viewing.
class StudentDocumentsCubit extends Cubit<StudentDocumentsState> {
  StudentDocumentsCubit({
    required this.uploadDocument,
    required this.getDocuments,
    required this.repository,
  }) : super(const StudentDocumentsState());

  final UploadStudentDocument uploadDocument;
  final GetStudentDocuments getDocuments;
  final StudentDocumentRepository repository;

  /// Loads all documents for a student.
  Future<void> loadDocuments(String studentId) async {
    emit(state.copyWith(status: StudentDocumentsStatus.loading));

    final documentsResult = await getDocuments(
      GetStudentDocumentsParams(studentId: studentId),
    );

    documentsResult.fold(
      (failure) => emit(
        state.copyWith(
          status: StudentDocumentsStatus.error,
          errorMessage: failure.message,
        ),
      ),
      (documents) => emit(
        state.copyWith(
          status: StudentDocumentsStatus.loaded,
          documents: documents,
        ),
      ),
    );
  }

  /// Uploads a new document.
  Future<void> uploadNewDocument({
    required String studentId,
    required String filePath,
    required String fileName,
  }) async {
    // Check if already at limit
    if (state.documents.length >= 2) {
      emit(
        state.copyWith(
          status: StudentDocumentsStatus.error,
          errorMessage: 'Maximum 2 documents allowed',
        ),
      );
      return;
    }

    emit(state.copyWith(status: StudentDocumentsStatus.uploading));

    final result = await uploadDocument(
      UploadStudentDocumentParams(
        studentId: studentId,
        filePath: filePath,
        fileName: fileName,
      ),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: StudentDocumentsStatus.error,
          errorMessage: failure.message,
        ),
      ),
      (document) {
        // Reload documents to get updated list
        loadDocuments(studentId);
      },
    );
  }

  /// Deletes a document.
  Future<void> deleteDocument(String documentId) async {
    emit(state.copyWith(status: StudentDocumentsStatus.loading));

    final result = await repository.deleteDocument(documentId);

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: StudentDocumentsStatus.error,
          errorMessage: failure.message,
        ),
      ),
      (_) {
        // Remove document from state
        final updatedDocuments = state.documents
            .where((doc) => doc.id != documentId)
            .toList();
        emit(
          state.copyWith(
            status: StudentDocumentsStatus.loaded,
            documents: updatedDocuments,
          ),
        );
      },
    );
  }

  /// Refreshes the documents list.
  Future<void> refresh(String studentId) async {
    await loadDocuments(studentId);
  }
}
