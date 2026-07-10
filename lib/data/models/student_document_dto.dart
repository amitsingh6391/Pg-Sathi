import 'package:cloud_firestore/cloud_firestore.dart';

/// Data Transfer Object for StudentDocument entity.
class StudentDocumentDto {
  const StudentDocumentDto({
    required this.id,
    required this.studentId,
    required this.fileName,
    required this.downloadUrl,
    required this.fileType,
    required this.uploadedAt,
    this.fileSize,
    this.approvalStatus = 'pending',
    this.approvedAt,
    this.approvedBy,
  });

  final String id;
  final String studentId;
  final String fileName;
  final String downloadUrl;
  final String fileType; // 'image' or 'pdf'
  final Timestamp uploadedAt;
  final int? fileSize;
  final String approvalStatus; // 'pending', 'approved', 'rejected'
  final Timestamp? approvedAt;
  final String? approvedBy;

  factory StudentDocumentDto.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return StudentDocumentDto(
      id: doc.id,
      studentId: data['studentId'] as String,
      fileName: data['fileName'] as String,
      downloadUrl: data['downloadUrl'] as String,
      fileType: data['fileType'] as String,
      uploadedAt: data['uploadedAt'] as Timestamp,
      fileSize: data['fileSize'] as int?,
      approvalStatus: data['approvalStatus'] as String? ?? 'pending',
      approvedAt: data['approvedAt'] as Timestamp?,
      approvedBy: data['approvedBy'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'studentId': studentId,
      'fileName': fileName,
      'downloadUrl': downloadUrl,
      'fileType': fileType,
      'uploadedAt': uploadedAt,
      if (fileSize != null) 'fileSize': fileSize,
      'approvalStatus': approvalStatus,
      if (approvedAt != null) 'approvedAt': approvedAt,
      if (approvedBy != null) 'approvedBy': approvedBy,
    };
  }

  static const String collectionName = 'student_documents';
}
