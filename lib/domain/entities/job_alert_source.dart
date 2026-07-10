import 'package:equatable/equatable.dart';

/// Configured upstream feed the ingestion worker polls for job candidates.
///
/// Stored as a Firestore document so sources can be enabled/disabled and
/// intervals tuned without a code deploy.
class JobAlertSource extends Equatable {
  const JobAlertSource({
    required this.id,
    required this.name,
    required this.url,
    required this.type,
    required this.isActive,
    this.fetchIntervalMinutes = 120,
    this.lastFetchedAt,
    this.lastFetchStatus,
    this.lastError,
    this.itemsFoundLastRun = 0,
  });

  final String id;
  final String name;
  final String url;
  final JobAlertSourceType type;

  /// Master switch. When false the Cloud Function skips this source.
  final bool isActive;

  /// Soft guideline for the scheduled function; used by admin UI only.
  /// The actual schedule is enforced by the Cloud Function cron.
  final int fetchIntervalMinutes;

  final DateTime? lastFetchedAt;
  final JobAlertSourceStatus? lastFetchStatus;
  final String? lastError;
  final int itemsFoundLastRun;

  JobAlertSource copyWith({
    String? id,
    String? name,
    String? url,
    JobAlertSourceType? type,
    bool? isActive,
    int? fetchIntervalMinutes,
    DateTime? lastFetchedAt,
    JobAlertSourceStatus? lastFetchStatus,
    String? lastError,
    int? itemsFoundLastRun,
  }) {
    return JobAlertSource(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      type: type ?? this.type,
      isActive: isActive ?? this.isActive,
      fetchIntervalMinutes: fetchIntervalMinutes ?? this.fetchIntervalMinutes,
      lastFetchedAt: lastFetchedAt ?? this.lastFetchedAt,
      lastFetchStatus: lastFetchStatus ?? this.lastFetchStatus,
      lastError: lastError ?? this.lastError,
      itemsFoundLastRun: itemsFoundLastRun ?? this.itemsFoundLastRun,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        url,
        type,
        isActive,
        fetchIntervalMinutes,
        lastFetchedAt,
        lastFetchStatus,
        lastError,
        itemsFoundLastRun,
      ];
}

/// Supported upstream formats.
enum JobAlertSourceType {
  rss,
  htmlScrape,
  api,
}

/// Health state of the last fetch attempt.
enum JobAlertSourceStatus {
  success,
  error,
  disabled,
}
