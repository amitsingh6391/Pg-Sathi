import 'package:dartz/dartz.dart';

import '../core/failure.dart';
import '../entities/quiz_result.dart';

/// Paginated response wrapper for quiz history.
class PaginatedQuizResults {
  const PaginatedQuizResults({
    required this.results,
    required this.hasMore,
    this.lastDocumentId,
  });

  final List<QuizResult> results;

  /// Whether there are more results beyond this page.
  final bool hasMore;

  /// Opaque cursor for the next page (last document ID).
  final String? lastDocumentId;
}

/// Repository interface for persisting quiz results.
abstract class QuizHistoryRepository {
  /// Saves a completed quiz result.
  Future<Either<Failure, void>> saveResult(QuizResult result);

  /// Retrieves a paginated list of quiz results, newest first.
  ///
  /// [limit] — number of results per page.
  /// [startAfterId] — the ID of the last result from the previous page
  /// (null for the first page).
  Future<Either<Failure, PaginatedQuizResults>> getHistory(
    String userId, {
    int limit = 10,
    String? startAfterId,
  });

  /// Deletes a single quiz result.
  Future<Either<Failure, void>> deleteResult({
    required String userId,
    required String resultId,
  });
}
