import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/job_alert_source.dart';

/// Firestore (de)serialization for [JobAlertSource].
class JobAlertSourceModel {
  const JobAlertSourceModel({
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
  final String type;
  final bool isActive;
  final int fetchIntervalMinutes;
  final DateTime? lastFetchedAt;
  final String? lastFetchStatus;
  final String? lastError;
  final int itemsFoundLastRun;

  factory JobAlertSourceModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return JobAlertSourceModel(
      id: doc.id,
      name: (data['name'] as String?) ?? '',
      url: (data['url'] as String?) ?? '',
      type: (data['type'] as String?) ?? 'rss',
      isActive: (data['isActive'] as bool?) ?? false,
      fetchIntervalMinutes: (data['fetchIntervalMinutes'] as int?) ?? 120,
      lastFetchedAt: (data['lastFetchedAt'] as Timestamp?)?.toDate(),
      lastFetchStatus: data['lastFetchStatus'] as String?,
      lastError: data['lastError'] as String?,
      itemsFoundLastRun: (data['itemsFoundLastRun'] as int?) ?? 0,
    );
  }

  factory JobAlertSourceModel.fromEntity(JobAlertSource entity) {
    return JobAlertSourceModel(
      id: entity.id,
      name: entity.name,
      url: entity.url,
      type: entity.type.name,
      isActive: entity.isActive,
      fetchIntervalMinutes: entity.fetchIntervalMinutes,
      lastFetchedAt: entity.lastFetchedAt,
      lastFetchStatus: entity.lastFetchStatus?.name,
      lastError: entity.lastError,
      itemsFoundLastRun: entity.itemsFoundLastRun,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'url': url,
      'type': type,
      'isActive': isActive,
      'fetchIntervalMinutes': fetchIntervalMinutes,
      'lastFetchedAt':
          lastFetchedAt == null ? null : Timestamp.fromDate(lastFetchedAt!),
      'lastFetchStatus': lastFetchStatus,
      'lastError': lastError,
      'itemsFoundLastRun': itemsFoundLastRun,
    };
  }

  JobAlertSource toEntity() {
    return JobAlertSource(
      id: id,
      name: name,
      url: url,
      type: _parseType(type),
      isActive: isActive,
      fetchIntervalMinutes: fetchIntervalMinutes,
      lastFetchedAt: lastFetchedAt,
      lastFetchStatus: _parseStatus(lastFetchStatus),
      lastError: lastError,
      itemsFoundLastRun: itemsFoundLastRun,
    );
  }

  static JobAlertSourceType _parseType(String value) {
    return JobAlertSourceType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => JobAlertSourceType.rss,
    );
  }

  static JobAlertSourceStatus? _parseStatus(String? value) {
    if (value == null) return null;
    for (final s in JobAlertSourceStatus.values) {
      if (s.name == value) return s;
    }
    return null;
  }
}
