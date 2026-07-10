import 'package:equatable/equatable.dart';

import 'admin_dashboard_stats.dart';
import 'library_summary.dart';

/// Combined dashboard data returned from a single optimized read.
/// Eliminates duplicate Firestore reads that occurred when
/// [AdminDashboardStats] and [LibrarySummary] were fetched separately.
class AdminDashboardData extends Equatable {
  const AdminDashboardData({
    required this.stats,
    required this.librarySummaries,
  });

  /// Platform-wide statistics (library counts, growth, user counts).
  final AdminDashboardStats stats;

  /// All library summaries with owner info, occupancy, and subscription status.
  final List<LibrarySummary> librarySummaries;

  @override
  List<Object?> get props => [stats, librarySummaries];
}
