import '../../domain/entities/analytics_summary.dart';

/// Repository for fetching analytics dashboard data.
abstract class AnalyticsDashboardRepository {
  /// Get event counts grouped by event name.
  Future<Map<String, int>> getEventCounts({
    String? role,
    DateTime? startDate,
    DateTime? endDate,
  });

  /// Get event counts grouped by platform.
  Future<Map<String, int>> getPlatformCounts({
    String? role,
    DateTime? startDate,
    DateTime? endDate,
  });

  /// Get event counts grouped by role.
  Future<Map<String, int>> getRoleCounts({
    DateTime? startDate,
    DateTime? endDate,
  });

  /// Get recent analytics events.
  Stream<List<AnalyticsSummary>> getRecentEvents({
    int limit = 10,
  });
}
