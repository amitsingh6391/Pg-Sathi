import 'package:dartz/dartz.dart';

import '../core/core.dart';
import '../entities/user_activity_stats.dart';
import '../repositories/admin_analytics_repository.dart';

/// Use case for fetching user activity statistics.
/// Provides DAU, WAU, MAU and time-based insights.
class GetAdminUserActivity implements UseCase<UserActivityStats, NoParams> {
  const GetAdminUserActivity({required this.repository});

  final AdminAnalyticsRepository repository;

  @override
  Future<Either<Failure, UserActivityStats>> call(NoParams params) {
    return repository.getUserActivityStats();
  }
}
