part of 'student_details_cubit.dart';

/// State for StudentDetailsCubit.
class StudentDetailsState extends Equatable {
  const StudentDetailsState({
    this.status = StudentDetailsStatus.initial,
    this.student,
    this.invoices = const [],
    this.documents = const [],
    this.errorMessage,
    this.isUploading = false,
  });

  final StudentDetailsStatus status;
  final User? student;
  final List<Invoice> invoices;
  final List<StudentDocument> documents;
  final String? errorMessage;
  final bool isUploading;

  bool get isLoading => status == StudentDetailsStatus.loading;
  bool get isLoaded => status == StudentDetailsStatus.loaded;
  bool get hasError => status == StudentDetailsStatus.error;
  bool get canUploadMore => documents.length < 2 && !isUploading;

  StudentDetailsState copyWith({
    StudentDetailsStatus? status,
    User? student,
    List<Invoice>? invoices,
    List<StudentDocument>? documents,
    String? errorMessage,
    bool? isUploading,
  }) {
    return StudentDetailsState(
      status: status ?? this.status,
      student: student ?? this.student,
      invoices: invoices ?? this.invoices,
      documents: documents ?? this.documents,
      errorMessage: errorMessage ?? this.errorMessage,
      isUploading: isUploading ?? this.isUploading,
    );
  }

  @override
  List<Object?> get props => [
    status,
    student,
    invoices,
    documents,
    errorMessage,
    isUploading,
  ];
}

/// Status for student details loading.
enum StudentDetailsStatus { initial, loading, loaded, error }
