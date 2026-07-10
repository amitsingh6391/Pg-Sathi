import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';

import '../../domain/core/failure.dart';
import '../../domain/entities/quiz_result.dart';
import '../../domain/repositories/quiz_history_repository.dart';
import '../../domain/usecases/ai/ai_usecases.dart';

/// Firestore-backed implementation of [QuizHistoryRepository].
///
/// Collection structure:
/// quiz_results/{userId}/results/{resultId}
///
/// Uses cursor-based pagination to minimize read operations.
class QuizHistoryRepositoryImpl implements QuizHistoryRepository {
  const QuizHistoryRepositoryImpl({required this.firestore});

  final FirebaseFirestore firestore;

  CollectionReference<Map<String, dynamic>> _resultsCollection(String userId) {
    return firestore
        .collection('quiz_results')
        .doc(userId)
        .collection('results');
  }

  @override
  Future<Either<Failure, void>> saveResult(QuizResult result) async {
    try {
      await _resultsCollection(result.userId)
          .doc(result.id)
          .set(result.toMap());
      return const Right(null);
    } catch (e) {
      return Left(AiFailure(message: 'Failed to save quiz result: $e'));
    }
  }

  @override
  Future<Either<Failure, PaginatedQuizResults>> getHistory(
    String userId, {
    int limit = 10,
    String? startAfterId,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _resultsCollection(userId)
          .orderBy('completedAt', descending: true);

      // Cursor-based pagination: start after the last document of the
      // previous page to avoid offset-based reads.
      if (startAfterId != null) {
        final lastDoc =
            await _resultsCollection(userId).doc(startAfterId).get();
        if (lastDoc.exists) {
          query = query.startAfterDocument(lastDoc);
        }
      }

      // Fetch limit+1 to determine if there are more results.
      final snapshot = await query.limit(limit + 1).get();

      final docs = snapshot.docs;
      final hasMore = docs.length > limit;
      final pageDocs = hasMore ? docs.sublist(0, limit) : docs;

      final results =
          pageDocs.map((doc) => QuizResult.fromMap(doc.data())).toList();

      return Right(PaginatedQuizResults(
        results: results,
        hasMore: hasMore,
        lastDocumentId: results.isNotEmpty ? results.last.id : null,
      ));
    } catch (e) {
      return Left(AiFailure(message: 'Failed to load quiz history: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteResult({
    required String userId,
    required String resultId,
  }) async {
    try {
      await _resultsCollection(userId).doc(resultId).delete();
      return const Right(null);
    } catch (e) {
      return Left(AiFailure(message: 'Failed to delete quiz result: $e'));
    }
  }
}
