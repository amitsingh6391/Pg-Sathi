import 'package:equatable/equatable.dart';

import 'job_alert.dart';

/// Per-user filter + notification preferences for job alerts.
///
/// A missing document in Firestore is treated as [defaultFor], so the UI
/// never blocks on whether the user has opened the preferences screen.
class UserJobPreferences extends Equatable {
  const UserJobPreferences({
    required this.userId,
    required this.categories,
    required this.states,
    required this.pushEnabled,
    required this.frequency,
    this.updatedAt,
  });

  final String userId;

  /// Empty means "show all categories" (same as selecting every enum value).
  final Set<JobCategory> categories;

  /// Empty means "all states". Only relevant when [categories] contains
  /// [JobCategory.statePsc] or state-specific police/teaching.
  final Set<String> states;

  final bool pushEnabled;
  final JobPushFrequency frequency;
  final DateTime? updatedAt;

  /// Conservative defaults for a new user: push on, **once-a-day
  /// digest at 9 AM IST**, no filters (see everything).
  ///
  /// We deliberately default to [JobPushFrequency.digest9am] rather
  /// than instant — a fresh student typically has no category filters
  /// set, so an instant default would push them every published alert
  /// across SSC / Banking / UPSC / Railway. The digest collapses that
  /// into one daily ping; users who genuinely want every alert can
  /// flip to instant from the preferences screen.
  factory UserJobPreferences.defaultFor(String userId) {
    return UserJobPreferences(
      userId: userId,
      categories: const {},
      states: const {},
      pushEnabled: true,
      frequency: JobPushFrequency.digest9am,
    );
  }

  /// True when this preference subscribes to the given [category].
  /// Empty [categories] means "subscribe to all".
  bool isSubscribedTo(JobCategory category) {
    if (!pushEnabled) return false;
    if (categories.isEmpty) return true;
    return categories.contains(category);
  }

  UserJobPreferences copyWith({
    String? userId,
    Set<JobCategory>? categories,
    Set<String>? states,
    bool? pushEnabled,
    JobPushFrequency? frequency,
    DateTime? updatedAt,
  }) {
    return UserJobPreferences(
      userId: userId ?? this.userId,
      categories: categories ?? this.categories,
      states: states ?? this.states,
      pushEnabled: pushEnabled ?? this.pushEnabled,
      frequency: frequency ?? this.frequency,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        userId,
        categories,
        states,
        pushEnabled,
        frequency,
        updatedAt,
      ];
}

/// How often a user wants push notifications delivered.
enum JobPushFrequency {
  /// Instant push on every new job matching preferences.
  instant,

  /// Single daily digest push at 9 AM IST with top 3 matching jobs.
  digest9am,

  /// Muted. Jobs tab still updates; no pushes sent.
  off,
}
