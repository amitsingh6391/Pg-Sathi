import 'package:equatable/equatable.dart';

import '../../../domain/entities/student_document.dart';

/// State for student documents cubit.
class StudentDocumentsState extends Equatable {
  const StudentDocumentsState({
    this.status = StudentDocumentsStatus.initial,
    this.documents = const [],
    this.errorMessage,
  });

  final StudentDocumentsStatus status;
  final List<StudentDocument> documents;
  final String? errorMessage;

  bool get isLoading => status == StudentDocumentsStatus.loading;
  bool get isUploading => status == StudentDocumentsStatus.uploading;
  bool get isLoaded => status == StudentDocumentsStatus.loaded;
  bool get isError => status == StudentDocumentsStatus.error;
  bool get canUploadMore => documents.length < 2;

  /// Whether all documents are approved
  bool get areAllDocumentsApproved {
    if (documents.isEmpty) return false;
    return documents.every((doc) => doc.isApproved);
  }

  /// Whether documents need approval
  bool get hasPendingDocuments {
    return documents.any((doc) => doc.isPending);
  }

  StudentDocumentsState copyWith({
    StudentDocumentsStatus? status,
    List<StudentDocument>? documents,
    String? errorMessage,
    bool clearError = false,
  }) {
    return StudentDocumentsState(
      status: status ?? this.status,
      documents: documents ?? this.documents,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, documents, errorMessage];
}

/// Status for student documents operations.
enum StudentDocumentsStatus { initial, loading, uploading, loaded, error }
