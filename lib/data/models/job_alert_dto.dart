import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/job_alert.dart';
import '../../domain/entities/labeled_link.dart';

/// Firestore (de)serialization for [JobAlert].
class JobAlertModel {
  const JobAlertModel({
    required this.id,
    required this.title,
    required this.organization,
    required this.category,
    required this.status,
    required this.postedAt,
    required this.updatedAt,
    required this.isActive,
    this.type = 'recruitment',
    this.state,
    this.vacancies,
    this.eligibility,
    this.ageLimit,
    this.applicationStartDate,
    this.applicationEndDate,
    this.examDate,
    this.applicationFeeGeneralPaise,
    this.applicationFeeReservedPaise,
    this.summary,
    this.detailsMarkdown,
    this.coverImageUrl,
    this.importantLinks = const [],
    this.sponsoredByPartnerId,
    this.priority = 5,
    this.viewCount = 0,
    this.applyClickCount = 0,
    this.bookmarkCount = 0,
    this.sourceCandidateId,
    this.createdBy,
  });

  final String id;
  final String title;
  final String organization;
  final String category;
  final String type;
  final String? state;
  final String status;
  final int? vacancies;
  final String? eligibility;
  final String? ageLimit;
  final DateTime? applicationStartDate;
  final DateTime? applicationEndDate;
  final DateTime? examDate;
  final int? applicationFeeGeneralPaise;
  final int? applicationFeeReservedPaise;
  final String? summary;
  final String? detailsMarkdown;
  final String? coverImageUrl;
  final List<Map<String, dynamic>> importantLinks;
  final String? sponsoredByPartnerId;
  final int priority;
  final int viewCount;
  final int applyClickCount;
  final int bookmarkCount;
  final DateTime postedAt;
  final DateTime updatedAt;
  final bool isActive;
  final String? sourceCandidateId;
  final String? createdBy;

  factory JobAlertModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final linksRaw = data['importantLinks'];
    return JobAlertModel(
      id: doc.id,
      title: (data['title'] as String?) ?? '',
      organization: (data['organization'] as String?) ?? '',
      category: (data['category'] as String?) ?? 'other',
      // Legacy docs predating the type field default to recruitment so
      // the historical inbox of govt-jobs items keeps showing up under
      // the Jobs tab.
      type: (data['type'] as String?) ?? 'recruitment',
      state: data['state'] as String?,
      status: (data['status'] as String?) ?? 'openForApplication',
      vacancies: data['vacancies'] as int?,
      eligibility: data['eligibility'] as String?,
      ageLimit: data['ageLimit'] as String?,
      applicationStartDate:
          (data['applicationStartDate'] as Timestamp?)?.toDate(),
      applicationEndDate:
          (data['applicationEndDate'] as Timestamp?)?.toDate(),
      examDate: (data['examDate'] as Timestamp?)?.toDate(),
      applicationFeeGeneralPaise:
          data['applicationFeeGeneralPaise'] as int?,
      applicationFeeReservedPaise:
          data['applicationFeeReservedPaise'] as int?,
      summary: data['summary'] as String?,
      detailsMarkdown: data['detailsMarkdown'] as String?,
      coverImageUrl: data['coverImageUrl'] as String?,
      importantLinks: linksRaw is List
          ? linksRaw
              .whereType<Map<String, dynamic>>()
              .toList(growable: false)
          : const [],
      sponsoredByPartnerId: data['sponsoredByPartnerId'] as String?,
      priority: (data['priority'] as int?) ?? 5,
      viewCount: (data['viewCount'] as int?) ?? 0,
      applyClickCount: (data['applyClickCount'] as int?) ?? 0,
      bookmarkCount: (data['bookmarkCount'] as int?) ?? 0,
      postedAt: (data['postedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      isActive: (data['isActive'] as bool?) ?? true,
      sourceCandidateId: data['sourceCandidateId'] as String?,
      createdBy: data['createdBy'] as String?,
    );
  }

  factory JobAlertModel.fromEntity(JobAlert entity) {
    return JobAlertModel(
      id: entity.id,
      title: entity.title,
      organization: entity.organization,
      category: entity.category.name,
      type: entity.type.name,
      state: entity.state,
      status: entity.status.name,
      vacancies: entity.vacancies,
      eligibility: entity.eligibility,
      ageLimit: entity.ageLimit,
      applicationStartDate: entity.applicationStartDate,
      applicationEndDate: entity.applicationEndDate,
      examDate: entity.examDate,
      applicationFeeGeneralPaise: entity.applicationFeeGeneralPaise,
      applicationFeeReservedPaise: entity.applicationFeeReservedPaise,
      summary: entity.summary,
      detailsMarkdown: entity.detailsMarkdown,
      coverImageUrl: entity.coverImageUrl,
      importantLinks:
          entity.importantLinks.map((l) => l.toMap()).toList(growable: false),
      sponsoredByPartnerId: entity.sponsoredByPartnerId,
      priority: entity.priority,
      viewCount: entity.viewCount,
      applyClickCount: entity.applyClickCount,
      bookmarkCount: entity.bookmarkCount,
      postedAt: entity.postedAt,
      updatedAt: entity.updatedAt,
      isActive: entity.isActive,
      sourceCandidateId: entity.sourceCandidateId,
      createdBy: entity.createdBy,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'organization': organization,
      'category': category,
      'type': type,
      'state': state,
      'status': status,
      'vacancies': vacancies,
      'eligibility': eligibility,
      'ageLimit': ageLimit,
      'applicationStartDate': _ts(applicationStartDate),
      'applicationEndDate': _ts(applicationEndDate),
      'examDate': _ts(examDate),
      'applicationFeeGeneralPaise': applicationFeeGeneralPaise,
      'applicationFeeReservedPaise': applicationFeeReservedPaise,
      'summary': summary,
      'detailsMarkdown': detailsMarkdown,
      'coverImageUrl': coverImageUrl,
      'importantLinks': importantLinks,
      'sponsoredByPartnerId': sponsoredByPartnerId,
      'priority': priority,
      'viewCount': viewCount,
      'applyClickCount': applyClickCount,
      'bookmarkCount': bookmarkCount,
      'postedAt': Timestamp.fromDate(postedAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
      'sourceCandidateId': sourceCandidateId,
      'createdBy': createdBy,
    };
  }

  JobAlert toEntity() {
    return JobAlert(
      id: id,
      title: title,
      organization: organization,
      category: _parseCategory(category),
      type: _parseType(type),
      state: state,
      status: _parseStatus(status),
      vacancies: vacancies,
      eligibility: eligibility,
      ageLimit: ageLimit,
      applicationStartDate: applicationStartDate,
      applicationEndDate: applicationEndDate,
      examDate: examDate,
      applicationFeeGeneralPaise: applicationFeeGeneralPaise,
      applicationFeeReservedPaise: applicationFeeReservedPaise,
      summary: summary,
      detailsMarkdown: detailsMarkdown,
      coverImageUrl: coverImageUrl,
      importantLinks: importantLinks
          .map((m) => LabeledLink.fromMap(m))
          .toList(growable: false),
      sponsoredByPartnerId: sponsoredByPartnerId,
      priority: priority,
      viewCount: viewCount,
      applyClickCount: applyClickCount,
      bookmarkCount: bookmarkCount,
      postedAt: postedAt,
      updatedAt: updatedAt,
      isActive: isActive,
      sourceCandidateId: sourceCandidateId,
      createdBy: createdBy,
    );
  }

  static Timestamp? _ts(DateTime? d) => d == null ? null : Timestamp.fromDate(d);

  static JobCategory _parseCategory(String value) {
    return JobCategory.values.firstWhere(
      (e) => e.name == value,
      orElse: () => JobCategory.other,
    );
  }

  static JobStatus _parseStatus(String value) {
    return JobStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => JobStatus.openForApplication,
    );
  }

  static JobAlertType _parseType(String value) {
    return JobAlertType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => JobAlertType.recruitment,
    );
  }
}
