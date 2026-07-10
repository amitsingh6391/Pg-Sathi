import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/extracted_job_fields.dart';
import '../../domain/entities/job_alert.dart' show JobAlertType;
import '../../domain/entities/job_alert_candidate.dart';
import 'extracted_job_fields_dto.dart';

/// Firestore (de)serialization for [JobAlertCandidate].
class JobAlertCandidateModel {
  const JobAlertCandidateModel({
    required this.id,
    required this.sourceId,
    required this.rawTitle,
    required this.rawLink,
    required this.normalizedKey,
    required this.fetchedAt,
    required this.status,
    this.type = 'recruitment',
    this.rawDescription,
    this.rawPublishedAt,
    this.suggestedCategory,
    this.suggestedApplyUrl,
    this.extractedFields,
    this.publishedJobAlertId,
    this.ignoredReason,
    this.reviewedBy,
    this.reviewedAt,
  });

  final String id;
  final String sourceId;
  final String rawTitle;
  final String rawLink;
  final String? rawDescription;
  final DateTime? rawPublishedAt;
  final DateTime fetchedAt;
  final String status;
  final String type;
  final String? suggestedCategory;
  final String? suggestedApplyUrl;
  final ExtractedJobFields? extractedFields;
  final String? publishedJobAlertId;
  final String? ignoredReason;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String normalizedKey;

  factory JobAlertCandidateModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return JobAlertCandidateModel(
      id: doc.id,
      sourceId: (data['sourceId'] as String?) ?? '',
      rawTitle: (data['rawTitle'] as String?) ?? '',
      rawLink: (data['rawLink'] as String?) ?? '',
      rawDescription: data['rawDescription'] as String?,
      rawPublishedAt: (data['rawPublishedAt'] as Timestamp?)?.toDate(),
      fetchedAt:
          (data['fetchedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: (data['status'] as String?) ?? 'pending',
      type: (data['type'] as String?) ?? 'recruitment',
      suggestedCategory: data['suggestedCategory'] as String?,
      suggestedApplyUrl: data['suggestedApplyUrl'] as String?,
      extractedFields: ExtractedJobFieldsModel.fromMap(
        data['extractedFields'] is Map<String, dynamic>
            ? data['extractedFields'] as Map<String, dynamic>
            : null,
      ),
      publishedJobAlertId: data['publishedJobAlertId'] as String?,
      ignoredReason: data['ignoredReason'] as String?,
      reviewedBy: data['reviewedBy'] as String?,
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      normalizedKey: (data['normalizedKey'] as String?) ?? '',
    );
  }

  factory JobAlertCandidateModel.fromEntity(JobAlertCandidate entity) {
    return JobAlertCandidateModel(
      id: entity.id,
      sourceId: entity.sourceId,
      rawTitle: entity.rawTitle,
      rawLink: entity.rawLink,
      rawDescription: entity.rawDescription,
      rawPublishedAt: entity.rawPublishedAt,
      fetchedAt: entity.fetchedAt,
      status: entity.status.name,
      type: entity.type.name,
      suggestedCategory: entity.suggestedCategory,
      suggestedApplyUrl: entity.suggestedApplyUrl,
      extractedFields: entity.extractedFields,
      publishedJobAlertId: entity.publishedJobAlertId,
      ignoredReason: entity.ignoredReason,
      reviewedBy: entity.reviewedBy,
      reviewedAt: entity.reviewedAt,
      normalizedKey: entity.normalizedKey,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'sourceId': sourceId,
      'rawTitle': rawTitle,
      'rawLink': rawLink,
      'rawDescription': rawDescription,
      'rawPublishedAt':
          rawPublishedAt == null ? null : Timestamp.fromDate(rawPublishedAt!),
      'fetchedAt': Timestamp.fromDate(fetchedAt),
      'status': status,
      'type': type,
      'suggestedCategory': suggestedCategory,
      'suggestedApplyUrl': suggestedApplyUrl,
      'extractedFields': ExtractedJobFieldsModel.toMap(extractedFields),
      'publishedJobAlertId': publishedJobAlertId,
      'ignoredReason': ignoredReason,
      'reviewedBy': reviewedBy,
      'reviewedAt':
          reviewedAt == null ? null : Timestamp.fromDate(reviewedAt!),
      'normalizedKey': normalizedKey,
    };
  }

  JobAlertCandidate toEntity() {
    return JobAlertCandidate(
      id: id,
      sourceId: sourceId,
      rawTitle: rawTitle,
      rawLink: rawLink,
      rawDescription: rawDescription,
      rawPublishedAt: rawPublishedAt,
      fetchedAt: fetchedAt,
      status: _parseStatus(status),
      type: _parseType(type),
      suggestedCategory: suggestedCategory,
      suggestedApplyUrl: suggestedApplyUrl,
      extractedFields: extractedFields,
      publishedJobAlertId: publishedJobAlertId,
      ignoredReason: ignoredReason,
      reviewedBy: reviewedBy,
      reviewedAt: reviewedAt,
      normalizedKey: normalizedKey,
    );
  }

  static JobCandidateStatus _parseStatus(String value) {
    return JobCandidateStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => JobCandidateStatus.pending,
    );
  }

  static JobAlertType _parseType(String value) {
    return JobAlertType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => JobAlertType.recruitment,
    );
  }
}
