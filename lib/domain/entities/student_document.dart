import 'package:equatable/equatable.dart';

/// Represents a verification document uploaded by a student.
/// Documents are stored in Firebase Storage at `/students/{studentId}/documents/{docId}`
class StudentDocument extends Equatable {
  const StudentDocument({
    required this.id,
    required this.studentId,
    required this.fileName,
    required this.downloadUrl,
    required this.fileType,
    required this.uploadedAt,
    this.documentCategory,
    this.fileSize,
    this.approvalStatus = DocumentApprovalStatus.pending,
    this.approvedAt,
    this.approvedBy,
  });

  /// Unique document ID
  final String id;

  /// Student user ID who uploaded this document
  final String studentId;

  /// Original file name
  final String fileName;

  /// Firebase Storage download URL
  final String downloadUrl;

  /// File type: 'image' or 'pdf'
  final StudentDocumentType fileType;

  /// Document category (Aadhar, PAN, etc.) - optional for backward compatibility
  final DocumentCategory? documentCategory;

  /// Upload timestamp
  final DateTime uploadedAt;

  /// File size in bytes (optional)
  final int? fileSize;

  /// Approval status of the document
  final DocumentApprovalStatus approvalStatus;

  /// When the document was approved (if approved)
  final DateTime? approvedAt;

  /// Owner ID who approved the document (if approved)
  final String? approvedBy;

  /// Whether the document is approved
  bool get isApproved => approvalStatus == DocumentApprovalStatus.approved;

  /// Whether the document is pending approval
  bool get isPending => approvalStatus == DocumentApprovalStatus.pending;

  @override
  List<Object?> get props => [
    id,
    studentId,
    fileName,
    downloadUrl,
    fileType,
    uploadedAt,
    documentCategory,
    fileSize,
    approvalStatus,
    approvedAt,
    approvedBy,
  ];

  StudentDocument copyWith({
    String? id,
    String? studentId,
    String? fileName,
    String? downloadUrl,
    StudentDocumentType? fileType,
    DateTime? uploadedAt,
    DocumentCategory? documentCategory,
    int? fileSize,
    DocumentApprovalStatus? approvalStatus,
    DateTime? approvedAt,
    String? approvedBy,
  }) {
    return StudentDocument(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      fileName: fileName ?? this.fileName,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      fileType: fileType ?? this.fileType,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      documentCategory: documentCategory ?? this.documentCategory,
      fileSize: fileSize ?? this.fileSize,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedBy: approvedBy ?? this.approvedBy,
    );
  }
}

/// Document category for verification documents
enum DocumentCategory {
  aadhar,
  pan,
  voterId,
  drivingLicence,
  studentId;

  String get displayName {
    switch (this) {
      case DocumentCategory.aadhar:
        return 'Aadhar Card';
      case DocumentCategory.pan:
        return 'PAN Card';
      case DocumentCategory.voterId:
        return 'Voter ID';
      case DocumentCategory.drivingLicence:
        return 'Driving Licence';
      case DocumentCategory.studentId:
        return 'Student ID Card';
    }
  }

  String get icon {
    switch (this) {
      case DocumentCategory.aadhar:
        return '🆔';
      case DocumentCategory.pan:
        return '💳';
      case DocumentCategory.voterId:
        return '🗳️';
      case DocumentCategory.drivingLicence:
        return '🚗';
      case DocumentCategory.studentId:
        return '🎓';
    }
  }
}

/// Type of student document
enum StudentDocumentType {
  image,
  pdf;

  /// Returns file extension
  String get extension {
    switch (this) {
      case StudentDocumentType.image:
        return 'jpg';
      case StudentDocumentType.pdf:
        return 'pdf';
    }
  }

  /// Returns MIME type
  String get mimeType {
    switch (this) {
      case StudentDocumentType.image:
        return 'image/jpeg';
      case StudentDocumentType.pdf:
        return 'application/pdf';
    }
  }

  /// Creates from file extension
  static StudentDocumentType? fromExtension(String extension) {
    final ext = extension.toLowerCase().replaceAll('.', '');
    switch (ext) {
      case 'jpg':
      case 'jpeg':
      case 'png':
        return StudentDocumentType.image;
      case 'pdf':
        return StudentDocumentType.pdf;
      default:
        return null;
    }
  }
}

/// Approval status for student documents
enum DocumentApprovalStatus {
  pending,
  approved,
  rejected;

  String get displayName {
    switch (this) {
      case DocumentApprovalStatus.pending:
        return 'Pending';
      case DocumentApprovalStatus.approved:
        return 'Approved';
      case DocumentApprovalStatus.rejected:
        return 'Rejected';
    }
  }
}
