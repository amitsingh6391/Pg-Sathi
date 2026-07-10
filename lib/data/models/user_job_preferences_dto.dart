import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/job_alert.dart';
import '../../domain/entities/user_job_preferences.dart';

/// Firestore (de)serialization for [UserJobPreferences].
class UserJobPreferencesModel {
  const UserJobPreferencesModel({
    required this.userId,
    required this.categories,
    required this.states,
    required this.pushEnabled,
    required this.frequency,
    this.updatedAt,
  });

  final String userId;
  final List<String> categories;
  final List<String> states;
  final bool pushEnabled;
  final String frequency;
  final DateTime? updatedAt;

  factory UserJobPreferencesModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return UserJobPreferencesModel(
      userId: doc.id,
      categories: _readStringList(data['categories']),
      states: _readStringList(data['states']),
      pushEnabled: (data['pushEnabled'] as bool?) ?? true,
      frequency: (data['frequency'] as String?) ?? 'instant',
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory UserJobPreferencesModel.fromEntity(UserJobPreferences entity) {
    return UserJobPreferencesModel(
      userId: entity.userId,
      categories:
          entity.categories.map((c) => c.name).toList(growable: false),
      states: entity.states.toList(growable: false),
      pushEnabled: entity.pushEnabled,
      frequency: entity.frequency.name,
      updatedAt: entity.updatedAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'categories': categories,
      'states': states,
      'pushEnabled': pushEnabled,
      'frequency': frequency,
      'updatedAt':
          updatedAt == null ? FieldValue.serverTimestamp() : Timestamp.fromDate(updatedAt!),
    };
  }

  UserJobPreferences toEntity() {
    return UserJobPreferences(
      userId: userId,
      categories: categories
          .map(_parseCategory)
          .whereType<JobCategory>()
          .toSet(),
      states: states.toSet(),
      pushEnabled: pushEnabled,
      frequency: _parseFrequency(frequency),
      updatedAt: updatedAt,
    );
  }

  static List<String> _readStringList(dynamic raw) {
    if (raw is List) {
      return raw.whereType<String>().toList(growable: false);
    }
    return const <String>[];
  }

  static JobCategory? _parseCategory(String value) {
    for (final c in JobCategory.values) {
      if (c.name == value) return c;
    }
    return null;
  }

  static JobPushFrequency _parseFrequency(String value) {
    return JobPushFrequency.values.firstWhere(
      (e) => e.name == value,
      // Unknown values fall back to the conservative daily digest —
      // matches `UserJobPreferences.defaultFor` so a corrupt doc never
      // silently escalates a user to instant push.
      orElse: () => JobPushFrequency.digest9am,
    );
  }
}
