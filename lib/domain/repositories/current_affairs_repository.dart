import 'package:dartz/dartz.dart';

import '../core/failure.dart';
import '../entities/current_affair.dart';

/// Paginated response for current affairs.
class PaginatedCurrentAffairs {
  const PaginatedCurrentAffairs({
    required this.items,
    required this.hasMore,
    this.lastDocumentId,
  });

  final List<CurrentAffair> items;
  final bool hasMore;

  /// Cursor for the next page (last document ID).
  final String? lastDocumentId;
}

/// Repository interface for current affairs CRUD and notifications.
abstract class CurrentAffairsRepository {
  /// Creates a new current affair and optionally notifies all students.
  Future<Either<Failure, CurrentAffair>> create({
    required String title,
    required String summary,
    required String content,
    required CurrentAffairsCategory category,
    String? source,
    String? imageUrl,
    required String createdBy,
    bool sendNotification = true,
  });

  /// Fetches a paginated list of current affairs, newest first.
  /// [startAfterId] — cursor for next page.
  Future<Either<Failure, PaginatedCurrentAffairs>> getAll({
    CurrentAffairsCategory? category,
    int limit = 10,
    String? startAfterId,
  });

  /// Fetches a single current affair by ID.
  Future<Either<Failure, CurrentAffair>> getById(String id);

  /// Toggles bookmark status for a student.
  Future<Either<Failure, void>> toggleBookmark({
    required String currentAffairId,
    required String userId,
    required bool isBookmarked,
  });

  /// Gets all bookmarked current affair IDs for a student.
  Future<Either<Failure, Set<String>>> getBookmarkedIds(String userId);

  /// Records a unique view for an article by a user.
  /// Uses a sub-collection to deduplicate; increments viewCount atomically.
  Future<Either<Failure, void>> recordView({
    required String currentAffairId,
    required String userId,
  });

  /// Toggles like status for a student on an article.
  /// Atomically increments/decrements likeCount.
  Future<Either<Failure, bool>> toggleLike({
    required String currentAffairId,
    required String userId,
    required bool isLiked,
  });

  /// Gets all liked current affair IDs for a student.
  Future<Either<Failure, Set<String>>> getLikedIds(String userId);

  /// Deletes a current affair by ID.
  Future<Either<Failure, void>> delete(String id);
}
