import 'package:dartz/dartz.dart';

import '../core/failure.dart';
import '../entities/admin_dashboard_data.dart';
import '../entities/invoice.dart';
import '../entities/user_activity_detail.dart';
import '../entities/user_activity_stats.dart';

/// Repository interface for admin analytics operations.
/// Provides read-only access to platform-wide metrics.
abstract class AdminAnalyticsRepository {
  /// Gets combined dashboard data (stats + library summaries) in a single
  /// optimized read. Shared Firestore collections (libraries, owners,
  /// memberships) are read once instead of being duplicated across separate
  /// calls.
  Future<Either<Failure, AdminDashboardData>> getDashboardData();

  /// Gets user activity statistics.
  /// Includes DAU/WAU/MAU and time-based insights.
  Future<Either<Failure, UserActivityStats>> getUserActivityStats();

  /// Gets all invoices with optional filters.
  /// Admin has read-only access to all invoices.
  Future<Either<Failure, List<Invoice>>> getInvoices({
    String? libraryId,
    String? ownerId,
    DateTime? startDate,
    DateTime? endDate,
  });

  /// Gets all owner IDs for broadcast notifications.
  Future<Either<Failure, List<String>>> getAllOwnerIds();

  /// Gets all student IDs for broadcast notifications.
  Future<Either<Failure, List<String>>> getAllStudentIds();

  /// Gets owner IDs for specific libraries.
  Future<Either<Failure, List<String>>> getOwnerIdsForLibraries(
    List<String> libraryIds,
  );

  /// Gets owner IDs for owners who already have a library.
  Future<Either<Failure, List<String>>> getOwnerIdsWithLibrary();

  /// Gets owner IDs for owners who have not created a library yet.
  Future<Either<Failure, List<String>>> getOwnerIdsWithoutLibrary();

  /// Gets student IDs that have at least one active membership.
  Future<Either<Failure, List<String>>> getStudentIdsWithActiveMembership();

  /// Gets student IDs with recent activity (attendance in last 30 days).
  Future<Either<Failure, List<String>>> getActiveStudentIds({
    Duration window,
  });

  /// Gets student IDs for specific libraries.
  Future<Either<Failure, List<String>>> getStudentIdsForLibraries(
    List<String> libraryIds,
  );

  /// Gets list of users active in a specific hour on a given date.
  /// Used for hourly activity drill-down.
  Future<Either<Failure, List<UserActivityDetail>>> getHourlyActiveUsers({
    required DateTime date,
    required int hour,
  });

  /// Gets detailed activity timeline for a specific user.
  /// Returns sessions grouped by date.
  Future<Either<Failure, List<UserActivityTimeline>>> getUserActivityDetails({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  });
}
