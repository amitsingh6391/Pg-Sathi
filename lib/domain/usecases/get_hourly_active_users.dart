import 'package:dartz/dartz.dart';
import 'package:pg_manager/data/failures/data_failures.dart';
import 'package:pg_manager/domain/core/failure.dart';
import 'package:pg_manager/domain/entities/user_activity_detail.dart';
import 'package:pg_manager/domain/repositories/admin_analytics_repository.dart';

/// Use case to fetch list of users active in a specific hour.
/// Used for drill-down from hourly activity charts.
class GetHourlyActiveUsers {
  const GetHourlyActiveUsers(this._repository);

  final AdminAnalyticsRepository _repository;

  /// Fetches users who were active in the specified hour on the given date.
  ///
  /// [date]: The date to query (time component is normalized to midnight).
  /// [hour]: Hour of day (0-23).
  ///
  /// Returns list of [UserActivityDetail] with check-in/out times.
  Future<Either<Failure, List<UserActivityDetail>>> call({
    required DateTime date,
    required int hour,
  }) async {
    if (hour < 0 || hour > 23) {
      return const Left(
        ValidationFailure(message: 'Hour must be between 0 and 23'),
      );
    }

    return _repository.getHourlyActiveUsers(date: date, hour: hour);
  }
}
