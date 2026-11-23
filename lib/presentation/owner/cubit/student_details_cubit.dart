import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/invoice.dart';
import '../../../domain/entities/student_document.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/repositories/invoice_repository.dart';
import '../../../domain/repositories/student_document_repository.dart';
import '../../../domain/repositories/user_repository.dart';
import '../../../domain/usecases/get_invoices_for_student.dart';
import '../../../domain/usecases/get_student_documents.dart';
import '../../../domain/usecases/upload_student_document.dart';

part 'student_details_state.dart';

/// Cubit for managing student details view (invoices, documents).
class StudentDetailsCubit extends Cubit<StudentDetailsState> {
  StudentDetailsCubit({
    required this.getInvoicesForStudent,
    required this.getStudentDocuments,
    required this.uploadDocument,
    required this.repository,
    required this.userRepository,
    required this.invoiceRepository,
  }) : super(const StudentDetailsState());

  final GetInvoicesForStudent getInvoicesForStudent;
  final GetStudentDocuments getStudentDocuments;
  final UploadStudentDocument uploadDocument;
  final StudentDocumentRepository repository;
  final UserRepository userRepository;
  final InvoiceRepository invoiceRepository;

  /// Load all student data (profile, invoices, documents).
  Future<void> loadStudentData({
    required String studentId,
    required String libraryId,
  }) async {
    emit(state.copyWith(status: StudentDetailsStatus.loading));

    // Load student profile
    final studentResult = await userRepository.getUserById(studentId);

    // Load invoices
    final invoicesResult = await getInvoicesForStudent(
      GetInvoicesForStudentParams(studentId: studentId),
    );

    // Load documents
    final documentsResult = await getStudentDocuments(
      GetStudentDocumentsParams(studentId: studentId),
    );

    // Process results
    final student = studentResult.fold((_) => null, (s) => s);
    final invoices = invoicesResult.fold((_) => <Invoice>[], (i) => i);
    final documents = documentsResult.fold(
      (_) => <StudentDocument>[],
      (d) => d,
    );

    emit(
      state.copyWith(
        status: StudentDetailsStatus.loaded,
        student: student,
        invoices: invoices,
        documents: documents,
      ),
    );
  }

  /// Load data for unregistered students (no userId).
  /// Fetches invoices by membershipId and documents by phone number.
  /// Profile info comes from seatInfo.
  Future<void> loadUnregisteredData({
    required String membershipId,
    required String phoneNumber,
  }) async {
    emit(state.copyWith(status: StudentDetailsStatus.loading));

    // Fetch invoices by membershipId (1 read)
    final invoicesResult = await invoiceRepository.getInvoicesByMembershipIds([
      membershipId,
    ]);

    // Fetch documents using phone number as studentId key (1 read)
    final documentsResult = await getStudentDocuments(
      GetStudentDocumentsParams(studentId: phoneNumber),
    );

    final invoices = invoicesResult.fold(
      (_) => <Invoice>[],
      (invoices) => invoices,
    );

    final documents = documentsResult.fold(
      (_) => <StudentDocument>[],
      (d) => d,
    );

    emit(
      state.copyWith(
        status: StudentDetailsStatus.loaded,
        invoices: invoices,
        documents: documents,
        // student remains null
      ),
    );
  }

  /// Refresh all data.
  Future<void> refresh({
    required String studentId,
    required String libraryId,
  }) async {
    await loadStudentData(studentId: studentId, libraryId: libraryId);
  }

  /// Refresh for unregistered students.
  Future<void> refreshUnregistered({
    required String membershipId,
    required String phoneNumber,
  }) async {
    await loadUnregisteredData(
      membershipId: membershipId,
      phoneNumber: phoneNumber,
    );
  }

  /// Upload a document for the student (owner uploads on behalf of student).
  Future<void> uploadNewDocument({
    required String studentId,
    required String filePath,
    required String fileName,
    required String libraryId,
  }) async {
    // Check if already at limit
    if (state.documents.length >= 2) {
      emit(
        state.copyWith(
          status: StudentDetailsStatus.error,
          errorMessage: 'Maximum 2 documents allowed',
        ),
      );
      return;
    }

    emit(state.copyWith(isUploading: true));

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
          status: StudentDetailsStatus.error,
          errorMessage: failure.message,
          isUploading: false,
        ),
      ),
      (_) {
        // Reset uploading flag and reload documents
        emit(state.copyWith(isUploading: false));
        loadStudentData(studentId: studentId, libraryId: libraryId);
      },
    );
  }

  /// Delete a document (owner can delete student documents).
  Future<void> deleteDocument(
    String documentId,
    String studentId,
    String libraryId,
  ) async {
    emit(state.copyWith(isUploading: true));

    final result = await repository.deleteDocument(documentId);

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: StudentDetailsStatus.error,
          errorMessage: failure.message ?? 'Failed to delete document',
          isUploading: false,
        ),
      ),
      (_) {
        // Reset uploading flag and reload documents
        emit(state.copyWith(isUploading: false));
        loadStudentData(studentId: studentId, libraryId: libraryId);
      },
    );
  }
}
