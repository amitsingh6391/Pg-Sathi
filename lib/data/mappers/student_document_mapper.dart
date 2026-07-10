import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/student_document.dart';
import '../models/student_document_dto.dart';

/// Mapper for StudentDocument entity <-> StudentDocumentDto conversion.
class StudentDocumentMapper {
  const StudentDocumentMapper._();

  static StudentDocument toEntity(StudentDocumentDto dto) {
    DocumentApprovalStatus status;
    switch (dto.approvalStatus) {
      case 'approved':
        status = DocumentApprovalStatus.approved;
        break;
      case 'rejected':
        status = DocumentApprovalStatus.rejected;
        break;
      default:
        status = DocumentApprovalStatus.pending;
    }

    return StudentDocument(
      id: dto.id,
      studentId: dto.studentId,
      fileName: dto.fileName,
      downloadUrl: dto.downloadUrl,
      fileType: dto.fileType == 'image'
          ? StudentDocumentType.image
          : StudentDocumentType.pdf,
      uploadedAt: dto.uploadedAt.toDate(),
      fileSize: dto.fileSize,
      approvalStatus: status,
      approvedAt: dto.approvedAt?.toDate(),
      approvedBy: dto.approvedBy,
    );
  }

  static StudentDocumentDto toDto(StudentDocument entity) {
    String status;
    switch (entity.approvalStatus) {
      case DocumentApprovalStatus.approved:
        status = 'approved';
        break;
      case DocumentApprovalStatus.rejected:
        status = 'rejected';
        break;
      default:
        status = 'pending';
    }

    return StudentDocumentDto(
      id: entity.id,
      studentId: entity.studentId,
      fileName: entity.fileName,
      downloadUrl: entity.downloadUrl,
      fileType: entity.fileType == StudentDocumentType.image ? 'image' : 'pdf',
      uploadedAt: Timestamp.fromDate(entity.uploadedAt),
      fileSize: entity.fileSize,
      approvalStatus: status,
      approvedAt: entity.approvedAt != null
          ? Timestamp.fromDate(entity.approvedAt!)
          : null,
      approvedBy: entity.approvedBy,
    );
  }
}
