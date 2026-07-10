part of 'feature_analytics_cubit.dart';

class FeatureAnalyticsState extends Equatable {
  final bool isLoading;
  final String? errorMessage;
  final Map<String, int> eventCounts;
  final Map<String, int> platformCounts;
  final Map<String, int> roleCounts;
  final List<AnalyticsSummary> recentEvents;

  const FeatureAnalyticsState({
    this.isLoading = false,
    this.errorMessage,
    this.eventCounts = const {},
    this.platformCounts = const {},
    this.roleCounts = const {},
    this.recentEvents = const [],
  });

  FeatureAnalyticsState copyWith({
    bool? isLoading,
    String? errorMessage,
    Map<String, int>? eventCounts,
    Map<String, int>? platformCounts,
    Map<String, int>? roleCounts,
    List<AnalyticsSummary>? recentEvents,
  }) {
    return FeatureAnalyticsState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      eventCounts: eventCounts ?? this.eventCounts,
      platformCounts: platformCounts ?? this.platformCounts,
      roleCounts: roleCounts ?? this.roleCounts,
      recentEvents: recentEvents ?? this.recentEvents,
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        errorMessage,
        eventCounts,
        platformCounts,
        roleCounts,
        recentEvents,
      ];
}
