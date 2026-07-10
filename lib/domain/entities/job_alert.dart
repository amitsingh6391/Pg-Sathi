import 'package:equatable/equatable.dart';

import 'labeled_link.dart';

/// A published govt exam / job notification visible to students.
///
/// Invariants:
/// - [id] is non-empty once persisted.
/// - [applicationEndDate] >= [applicationStartDate] when both present.
/// - [priority] is in [0, 10]; higher is shown first.
/// - Monetary fees are stored in paise (₹1 = 100 paise).
class JobAlert extends Equatable {
  const JobAlert({
    required this.id,
    required this.title,
    required this.organization,
    required this.category,
    required this.status,
    required this.postedAt,
    required this.updatedAt,
    required this.isActive,
    this.type = JobAlertType.recruitment,
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
  final JobCategory category;

  /// Top-level segmentation (recruitment / result / admit card). Drives
  /// the student-facing tabs, type-aware list sections, and admin
  /// validation rules. Defaults to [JobAlertType.recruitment] for
  /// pre-existing docs that were written before this field existed.
  final JobAlertType type;

  /// Indian state code, populated only when [category] is [JobCategory.statePsc]
  /// or for state-specific police/teaching recruitments.
  final String? state;

  final JobStatus status;
  final int? vacancies;
  final String? eligibility;
  final String? ageLimit;

  final DateTime? applicationStartDate;
  final DateTime? applicationEndDate;
  final DateTime? examDate;

  final int? applicationFeeGeneralPaise;
  final int? applicationFeeReservedPaise;

  /// Short 1–2 line summary used in list/card view.
  final String? summary;

  /// Full details body in markdown.
  final String? detailsMarkdown;

  final String? coverImageUrl;
  final List<LabeledLink> importantLinks;

  /// Optional paid sponsorship attribution (drives the "Prep for this exam"
  /// sponsored slot on the detail screen).
  final String? sponsoredByPartnerId;

  /// 0–10, higher sorts first and drives push urgency.
  final int priority;

  final int viewCount;
  final int applyClickCount;
  final int bookmarkCount;

  final DateTime postedAt;
  final DateTime updatedAt;
  final bool isActive;

  /// Traceability back to the [JobAlertCandidate] this was published from.
  final String? sourceCandidateId;

  /// Admin who published this alert.
  final String? createdBy;

  /// True if the student can currently apply.
  bool get isApplyOpen =>
      status == JobStatus.openForApplication &&
      (applicationEndDate == null ||
          applicationEndDate!.isAfter(DateTime.now()));

  /// True if the last date is within 3 days (used to show urgency chip).
  bool get isEndingSoon {
    final end = applicationEndDate;
    if (end == null || !isApplyOpen) return false;
    final diff = end.difference(DateTime.now()).inHours;
    return diff >= 0 && diff <= 72;
  }

  /// Whole days remaining to apply. Returns null when open-ended, negative
  /// when already closed.
  int? get daysRemainingToApply {
    final end = applicationEndDate;
    if (end == null) return null;
    return end.difference(DateTime.now()).inDays;
  }

  JobAlert copyWith({
    String? id,
    String? title,
    String? organization,
    JobCategory? category,
    JobAlertType? type,
    String? state,
    JobStatus? status,
    int? vacancies,
    String? eligibility,
    String? ageLimit,
    DateTime? applicationStartDate,
    DateTime? applicationEndDate,
    DateTime? examDate,
    int? applicationFeeGeneralPaise,
    int? applicationFeeReservedPaise,
    String? summary,
    String? detailsMarkdown,
    String? coverImageUrl,
    List<LabeledLink>? importantLinks,
    String? sponsoredByPartnerId,
    int? priority,
    int? viewCount,
    int? applyClickCount,
    int? bookmarkCount,
    DateTime? postedAt,
    DateTime? updatedAt,
    bool? isActive,
    String? sourceCandidateId,
    String? createdBy,
  }) {
    return JobAlert(
      id: id ?? this.id,
      title: title ?? this.title,
      organization: organization ?? this.organization,
      category: category ?? this.category,
      type: type ?? this.type,
      state: state ?? this.state,
      status: status ?? this.status,
      vacancies: vacancies ?? this.vacancies,
      eligibility: eligibility ?? this.eligibility,
      ageLimit: ageLimit ?? this.ageLimit,
      applicationStartDate:
          applicationStartDate ?? this.applicationStartDate,
      applicationEndDate: applicationEndDate ?? this.applicationEndDate,
      examDate: examDate ?? this.examDate,
      applicationFeeGeneralPaise:
          applicationFeeGeneralPaise ?? this.applicationFeeGeneralPaise,
      applicationFeeReservedPaise:
          applicationFeeReservedPaise ?? this.applicationFeeReservedPaise,
      summary: summary ?? this.summary,
      detailsMarkdown: detailsMarkdown ?? this.detailsMarkdown,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      importantLinks: importantLinks ?? this.importantLinks,
      sponsoredByPartnerId:
          sponsoredByPartnerId ?? this.sponsoredByPartnerId,
      priority: priority ?? this.priority,
      viewCount: viewCount ?? this.viewCount,
      applyClickCount: applyClickCount ?? this.applyClickCount,
      bookmarkCount: bookmarkCount ?? this.bookmarkCount,
      postedAt: postedAt ?? this.postedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      sourceCandidateId: sourceCandidateId ?? this.sourceCandidateId,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        organization,
        category,
        type,
        state,
        status,
        vacancies,
        eligibility,
        ageLimit,
        applicationStartDate,
        applicationEndDate,
        examDate,
        applicationFeeGeneralPaise,
        applicationFeeReservedPaise,
        summary,
        detailsMarkdown,
        coverImageUrl,
        importantLinks,
        sponsoredByPartnerId,
        priority,
        viewCount,
        applyClickCount,
        bookmarkCount,
        postedAt,
        updatedAt,
        isActive,
        sourceCandidateId,
        createdBy,
      ];
}

/// High-level exam family. Drives filtering, push targeting, and
/// sponsored-slot pricing.
enum JobCategory {
  ssc('SSC'),
  banking('Banking'),
  railway('Railway'),
  upsc('UPSC'),
  statePsc('State PSC'),
  teaching('Teaching'),
  defense('Defense'),
  police('Police'),
  other('Other');

  const JobCategory(this.label);
  final String label;
}

/// Top-level segmentation seen by students as the three primary tabs.
///
/// This is intentionally separate from [JobStatus] (which is a lifecycle
/// state). A "Result" notification has type=result and status=resultDeclared;
/// a recruitment alert that's about to release admit cards stays
/// type=recruitment until a separate admit-card post is published.
///
/// Persisted as the lowercase enum name (`recruitment` / `result` /
/// `admitCard`); legacy docs without this field default to recruitment
/// in the DTO layer.
enum JobAlertType {
  recruitment('Jobs'),
  result('Results'),
  admitCard('Admit Cards');

  const JobAlertType(this.label);
  final String label;
}

/// Lifecycle state of a job alert.
enum JobStatus {
  upcoming('Upcoming'),
  openForApplication('Apply Now'),
  closed('Closed'),
  admitCardOut('Admit Card'),
  answerKeyOut('Answer Key'),
  resultDeclared('Result Out');

  const JobStatus(this.label);
  final String label;
}
