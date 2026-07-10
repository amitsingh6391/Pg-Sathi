import 'package:equatable/equatable.dart';

import 'extracted_job_fields.dart';
import 'job_alert.dart' show JobAlertType;

/// Raw item discovered by the RSS/scraper pipeline and pending admin review.
///
/// A candidate is *not* student-facing. It represents a hint that "something
/// new has been published upstream" and carries the minimum metadata needed
/// for an admin to verify from the official source and then publish a full
/// [JobAlert].
class JobAlertCandidate extends Equatable {
  const JobAlertCandidate({
    required this.id,
    required this.sourceId,
    required this.rawTitle,
    required this.rawLink,
    required this.normalizedKey,
    required this.fetchedAt,
    required this.status,
    this.type = JobAlertType.recruitment,
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

  /// Section the scraper assigned to this candidate
  /// (recruitment / result / admit card). Drives both the inbox tab
  /// the admin sees it under and the [JobAlert.type] the published
  /// alert inherits.
  final JobAlertType type;

  final String id;

  /// Reference back to [JobAlertSource.id] that yielded this candidate.
  final String sourceId;

  final String rawTitle;

  /// Aggregator article URL that yielded this candidate. Never shown
  /// to students — kept so admins can cross-check before publishing.
  final String rawLink;
  final String? rawDescription;

  /// Timestamp parsed from the RSS pubDate element.
  final DateTime? rawPublishedAt;

  /// When the ingestion worker wrote this candidate.
  final DateTime fetchedAt;

  final JobCandidateStatus status;

  /// Bot's best-effort category guess based on keyword matches.
  final String? suggestedCategory;

  /// Bot's best-effort extraction of the canonical official-site URL
  /// from the RSS description (e.g. ssc.nic.in). Null when nothing
  /// plausible was found — admins fall back to manual entry.
  final String? suggestedApplyUrl;

  /// Structured fields the scraper pulled from the source page —
  /// vacancies, fees, dates, age limits, and important links. Null for
  /// candidates ingested via the legacy RSS pipeline (which only had
  /// title + description).
  final ExtractedJobFields? extractedFields;

  /// Set after [status] becomes [JobCandidateStatus.published].
  final String? publishedJobAlertId;

  final String? ignoredReason;
  final String? reviewedBy;
  final DateTime? reviewedAt;

  /// Lower-cased, alphanumeric-only, length-capped identity used for
  /// cross-source deduplication.
  final String normalizedKey;

  JobAlertCandidate copyWith({
    String? id,
    String? sourceId,
    String? rawTitle,
    String? rawLink,
    String? rawDescription,
    DateTime? rawPublishedAt,
    DateTime? fetchedAt,
    JobCandidateStatus? status,
    JobAlertType? type,
    String? suggestedCategory,
    String? suggestedApplyUrl,
    ExtractedJobFields? extractedFields,
    String? publishedJobAlertId,
    String? ignoredReason,
    String? reviewedBy,
    DateTime? reviewedAt,
    String? normalizedKey,
  }) {
    return JobAlertCandidate(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      rawTitle: rawTitle ?? this.rawTitle,
      rawLink: rawLink ?? this.rawLink,
      rawDescription: rawDescription ?? this.rawDescription,
      rawPublishedAt: rawPublishedAt ?? this.rawPublishedAt,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      status: status ?? this.status,
      type: type ?? this.type,
      suggestedCategory: suggestedCategory ?? this.suggestedCategory,
      suggestedApplyUrl: suggestedApplyUrl ?? this.suggestedApplyUrl,
      extractedFields: extractedFields ?? this.extractedFields,
      publishedJobAlertId:
          publishedJobAlertId ?? this.publishedJobAlertId,
      ignoredReason: ignoredReason ?? this.ignoredReason,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      normalizedKey: normalizedKey ?? this.normalizedKey,
    );
  }

  /// Returns a dedup key suitable for equality comparison across sources.
  /// Implementation is colocated so both Flutter and the Cloud Function
  /// (mirrored in JS) stay in sync.
  static String normalizeTitleForKey(String title) {
    final lowered = title.toLowerCase();
    final alnum = lowered.replaceAll(RegExp(r'[^a-z0-9]+'), '');
    return alnum.length > 40 ? alnum.substring(0, 40) : alnum;
  }

  @override
  List<Object?> get props => [
        id,
        sourceId,
        rawTitle,
        rawLink,
        rawDescription,
        rawPublishedAt,
        fetchedAt,
        status,
        type,
        suggestedCategory,
        suggestedApplyUrl,
        extractedFields,
        publishedJobAlertId,
        ignoredReason,
        reviewedBy,
        reviewedAt,
        normalizedKey,
      ];
}

/// Workflow state of an inbox candidate.
enum JobCandidateStatus {
  pending('Pending'),
  published('Published'),
  ignored('Ignored'),
  duplicate('Duplicate');

  const JobCandidateStatus(this.label);
  final String label;
}
