import 'package:dartz/dartz.dart';
import 'package:pg_manager/data/failures/data_failures.dart';
import 'package:pg_manager/domain/core/failure.dart';
import 'package:pg_manager/domain/entities/user_activity_detail.dart';
import 'package:pg_manager/domain/repositories/admin_analytics_repository.dart';

/// Use case to fetch detailed activity timeline for a specific user.
/// Used for drill-down from user activity lists.
class GetUserActivityDetails {
  const GetUserActivityDetails(this._repository);

  final AdminAnalyticsRepository _repository;

  /// Fetches activity timeline for a user in a date range.
  ///
  /// [userId]: The user ID to fetch activity for.
  /// [startDate]: Start of date range (inclusive).
  /// [endDate]: End of date range (inclusive).
  ///
  /// Returns list of [UserActivityTimeline] grouped by date.
  Future<Either<Failure, List<UserActivityTimeline>>> call({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (userId.isEmpty) {
      return const Left(
        ValidationFailure(message: 'User ID cannot be empty'),
      );
    }

    if (endDate.isBefore(startDate)) {
      return const Left(
        ValidationFailure(message: 'End date must be after start date'),
      );
    }

    return _repository.getUserActivityDetails(
      userId: userId,
      startDate: startDate,
      endDate: endDate,
    );
  }
}
