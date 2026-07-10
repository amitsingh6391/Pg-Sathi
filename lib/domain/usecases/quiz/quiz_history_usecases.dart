import 'package:dartz/dartz.dart';

import '../../core/failure.dart';
import '../../entities/quiz.dart';
import '../../entities/quiz_result.dart';
import '../../repositories/quiz_history_repository.dart';

// =============================================================================
// Save Quiz Result
// =============================================================================

/// Persists a completed quiz result for future review.
class SaveQuizResult {
  const SaveQuizResult({required this.repository});

  final QuizHistoryRepository repository;

  Future<Either<Failure, void>> call({
    required String userId,
    required Quiz quiz,
    required List<int> selectedAnswers,
    required int score,
  }) {
    final result = QuizResult(
      id: '${userId}_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      questions: quiz.questions,
      selectedAnswers: selectedAnswers,
      score: score,
      totalQuestions: quiz.totalQuestions,
      completedAt: DateTime.now(),
      sourceTextPreview: quiz.sourceText,
    );

    return repository.saveResult(result);
  }
}

// =============================================================================
// Get Quiz History (paginated)
// =============================================================================

/// Retrieves a page of saved quiz results for a user.
///
/// Supports cursor-based pagination to minimize Firestore reads.
/// Pass [startAfterId] from the previous page's [PaginatedQuizResults.lastDocumentId].
class GetQuizHistory {
  const GetQuizHistory({required this.repository});

  final QuizHistoryRepository repository;

  Future<Either<Failure, PaginatedQuizResults>> call(
    String userId, {
    int limit = 10,
    String? startAfterId,
  }) {
    return repository.getHistory(
      userId,
      limit: limit,
      startAfterId: startAfterId,
    );
  }
}

// =============================================================================
// Delete Quiz Result
// =============================================================================

/// Deletes a single saved quiz result.
class DeleteQuizResult {
  const DeleteQuizResult({required this.repository});

  final QuizHistoryRepository repository;

  Future<Either<Failure, void>> call({
    required String userId,
    required String resultId,
  }) {
    return repository.deleteResult(userId: userId, resultId: resultId);
  }
}
