part of 'student_details_cubit.dart';

/// State for StudentDetailsCubit.
class StudentDetailsState extends Equatable {
  const StudentDetailsState({
    this.status = StudentDetailsStatus.initial,
    this.student,
    this.attendance = const [],
    this.invoices = const [],
    this.documents = const [],
    this.errorMessage,
    this.isUploading = false,
  });

  final StudentDetailsStatus status;
  final User? student;
  final List<Attendance> attendance;
  final List<Invoice> invoices;
  final List<StudentDocument> documents;
  final String? errorMessage;
  final bool isUploading;

  bool get isLoading => status == StudentDetailsStatus.loading;
  bool get isLoaded => status == StudentDetailsStatus.loaded;
  bool get hasError => status == StudentDetailsStatus.error;
  bool get canUploadMore => documents.length < 2 && !isUploading;

  /// Calculate attendance statistics.
  AttendanceStats get attendanceStats {
    final completed = attendance.where((a) => a.isCheckedOut).length;
    final total = attendance.length;
    final percentage = total > 0 ? (completed / total * 100).round() : 0;
    return AttendanceStats(
      totalDays: total,
      completedDays: completed,
      percentage: percentage,
    );
  }

  StudentDetailsState copyWith({
    StudentDetailsStatus? status,
    User? student,
    List<Attendance>? attendance,
    List<Invoice>? invoices,
    List<StudentDocument>? documents,
    String? errorMessage,
    bool? isUploading,
  }) {
    return StudentDetailsState(
      status: status ?? this.status,
      student: student ?? this.student,
      attendance: attendance ?? this.attendance,
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
    attendance,
    invoices,
    documents,
    errorMessage,
    isUploading,
  ];
}

/// Status for student details loading.
enum StudentDetailsStatus { initial, loading, loaded, error }

/// Simple attendance statistics.
class AttendanceStats {
  const AttendanceStats({
    required this.totalDays,
    required this.completedDays,
    required this.percentage,
  });

  final int totalDays;
  final int completedDays;
  final int percentage;
}
