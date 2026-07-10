import 'package:dartz/dartz.dart';

import '../core/core.dart';
import '../entities/admin_dashboard_data.dart';
import '../repositories/admin_analytics_repository.dart';

/// Fetches combined dashboard data (stats + library summaries) in a single
/// optimized call. Replaces separate [GetAdminDashboardStats] and
/// [GetAdminLibraryAnalytics] to avoid duplicate Firestore reads.
class GetAdminDashboardData
    implements UseCase<AdminDashboardData, NoParams> {
  const GetAdminDashboardData({required this.repository});

  final AdminAnalyticsRepository repository;

  @override
  Future<Either<Failure, AdminDashboardData>> call(NoParams params) {
    return repository.getDashboardData();
  }
}
