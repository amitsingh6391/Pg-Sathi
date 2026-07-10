import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/quiz.dart';
import 'package:pg_manager/domain/entities/quiz_result.dart';
import 'package:pg_manager/domain/repositories/quiz_history_repository.dart';
import 'package:pg_manager/domain/usecases/ai/ai_usecases.dart';
import 'package:pg_manager/domain/usecases/quiz/quiz_history_usecases.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'quiz_history_usecases_test.mocks.dart';

@GenerateMocks([QuizHistoryRepository])
void main() {
  late MockQuizHistoryRepository mockRepository;

  setUp(() {
    mockRepository = MockQuizHistoryRepository();
  });

  const userId = 'test-user-123';

  final testQuiz = Quiz(
    questions: const [
      QuizQuestion(
        question: 'What is 2+2?',
        options: ['3', '4', '5', '6'],
        correctIndex: 1,
        explanation: 'Basic arithmetic.',
      ),
      QuizQuestion(
        question: 'Capital of India?',
        options: ['Mumbai', 'Delhi', 'Bangalore', 'Chennai'],
        correctIndex: 1,
        explanation: 'New Delhi is the capital.',
      ),
    ],
    sourceText: 'Sample study material for testing',
    generatedAt: DateTime(2026, 2, 8),
  );

  final testQuizResult = QuizResult(
    id: 'result-1',
    userId: userId,
    questions: testQuiz.questions,
    selectedAnswers: const [1, 0],
    score: 1,
    totalQuestions: 2,
    completedAt: DateTime(2026, 2, 8, 14, 30),
    sourceTextPreview: 'Sample study material for testing',
  );

  // ===========================================================================
  // SaveQuizResult
  // ===========================================================================

  group('SaveQuizResult', () {
    late SaveQuizResult useCase;

    setUp(() {
      useCase = SaveQuizResult(repository: mockRepository);
    });

    test('should_save_result_when_repository_succeeds', () async {
      when(mockRepository.saveResult(any))
          .thenAnswer((_) async => const Right(null));

      final result = await useCase(
        userId: userId,
        quiz: testQuiz,
        selectedAnswers: const [1, 0],
        score: 1,
      );

      expect(result.isRight(), true);
      verify(mockRepository.saveResult(any)).called(1);
    });

    test('should_return_failure_when_repository_fails', () async {
      when(mockRepository.saveResult(any)).thenAnswer(
        (_) async => const Left(AiFailure(message: 'Save failed')),
      );

      final result = await useCase(
        userId: userId,
        quiz: testQuiz,
        selectedAnswers: const [1, 0],
        score: 1,
      );

      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure.message, 'Save failed'),
        (_) => fail('Should not succeed'),
      );
    });

    test('should_construct_quiz_result_with_correct_fields', () async {
      late QuizResult captured;
      when(mockRepository.saveResult(any)).thenAnswer((invocation) async {
        captured = invocation.positionalArguments[0] as QuizResult;
        return const Right(null);
      });

      await useCase(
        userId: userId,
        quiz: testQuiz,
        selectedAnswers: const [1, 1],
        score: 2,
      );

      expect(captured.userId, userId);
      expect(captured.score, 2);
      expect(captured.totalQuestions, 2);
      expect(captured.questions.length, 2);
      expect(captured.selectedAnswers, [1, 1]);
      expect(captured.sourceTextPreview, testQuiz.sourceText);
      expect(captured.id, startsWith(userId));
    });
  });

  // ===========================================================================
  // GetQuizHistory (paginated)
  // ===========================================================================

  group('GetQuizHistory', () {
    late GetQuizHistory useCase;

    setUp(() {
      useCase = GetQuizHistory(repository: mockRepository);
    });

    test('should_return_first_page_of_results', () async {
      final page = PaginatedQuizResults(
        results: [testQuizResult],
        hasMore: false,
        lastDocumentId: testQuizResult.id,
      );
      when(mockRepository.getHistory(
        userId,
        limit: 10,
        startAfterId: null,
      )).thenAnswer((_) async => Right(page));

      final result = await useCase(userId);

      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should not fail'),
        (p) {
          expect(p.results.length, 1);
          expect(p.results.first.id, 'result-1');
          expect(p.hasMore, false);
        },
      );
    });

    test('should_pass_custom_limit_and_cursor', () async {
      final page = PaginatedQuizResults(
        results: [testQuizResult],
        hasMore: true,
        lastDocumentId: 'result-1',
      );
      when(mockRepository.getHistory(
        userId,
        limit: 5,
        startAfterId: 'prev-cursor',
      )).thenAnswer((_) async => Right(page));

      final result = await useCase(
        userId,
        limit: 5,
        startAfterId: 'prev-cursor',
      );

      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should not fail'),
        (p) {
          expect(p.hasMore, true);
          expect(p.lastDocumentId, 'result-1');
        },
      );
      verify(mockRepository.getHistory(
        userId,
        limit: 5,
        startAfterId: 'prev-cursor',
      )).called(1);
    });

    test('should_return_empty_page_when_no_results', () async {
      const page = PaginatedQuizResults(
        results: [],
        hasMore: false,
      );
      when(mockRepository.getHistory(
        userId,
        limit: 10,
        startAfterId: null,
      )).thenAnswer((_) async => const Right(page));

      final result = await useCase(userId);

      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should not fail'),
        (p) => expect(p.results.isEmpty, true),
      );
    });

    test('should_return_failure_when_repository_fails', () async {
      when(mockRepository.getHistory(
        userId,
        limit: 10,
        startAfterId: null,
      )).thenAnswer(
        (_) async => const Left(AiFailure(message: 'Load failed')),
      );

      final result = await useCase(userId);

      expect(result.isLeft(), true);
    });
  });

  // ===========================================================================
  // DeleteQuizResult
  // ===========================================================================

  group('DeleteQuizResult', () {
    late DeleteQuizResult useCase;

    setUp(() {
      useCase = DeleteQuizResult(repository: mockRepository);
    });

    test('should_delete_result_when_repository_succeeds', () async {
      when(mockRepository.deleteResult(
        userId: userId,
        resultId: 'result-1',
      )).thenAnswer((_) async => const Right(null));

      final result = await useCase(
        userId: userId,
        resultId: 'result-1',
      );

      expect(result.isRight(), true);
      verify(mockRepository.deleteResult(
        userId: userId,
        resultId: 'result-1',
      )).called(1);
    });

    test('should_return_failure_when_delete_fails', () async {
      when(mockRepository.deleteResult(
        userId: userId,
        resultId: 'result-1',
      )).thenAnswer(
        (_) async => const Left(AiFailure(message: 'Delete failed')),
      );

      final result = await useCase(
        userId: userId,
        resultId: 'result-1',
      );

      expect(result.isLeft(), true);
    });
  });

  // ===========================================================================
  // QuizResult Entity
  // ===========================================================================

  group('QuizResult', () {
    test('should_calculate_score_percentage_correctly', () {
      expect(testQuizResult.scorePercentage, 50.0);

      final perfect = QuizResult(
        id: 'r2',
        userId: userId,
        questions: testQuiz.questions,
        selectedAnswers: const [1, 1],
        score: 2,
        totalQuestions: 2,
        completedAt: DateTime.now(),
      );
      expect(perfect.scorePercentage, 100.0);
    });

    test('should_return_correct_score_label', () {
      expect(testQuizResult.scoreLabel, 'Average');

      final excellent = testQuizResult._copyWithScore(score: 2);
      expect(excellent.scoreLabel, 'Excellent');

      final good = testQuizResult._copyWithScore(score: 2, total: 3);
      expect(good.scoreLabel, 'Good');
    });

    test('should_serialize_and_deserialize_correctly', () {
      final map = testQuizResult.toMap();
      final deserialized = QuizResult.fromMap(map);

      expect(deserialized.id, testQuizResult.id);
      expect(deserialized.userId, testQuizResult.userId);
      expect(deserialized.score, testQuizResult.score);
      expect(deserialized.totalQuestions, testQuizResult.totalQuestions);
      expect(deserialized.questions.length, testQuizResult.questions.length);
      expect(deserialized.selectedAnswers, testQuizResult.selectedAnswers);
      expect(deserialized.sourceTextPreview, testQuizResult.sourceTextPreview);
    });

    test('should_handle_zero_total_questions_gracefully', () {
      final empty = QuizResult(
        id: 'empty',
        userId: userId,
        questions: const [],
        selectedAnswers: const [],
        score: 0,
        totalQuestions: 0,
        completedAt: DateTime.now(),
      );
      expect(empty.scorePercentage, 0.0);
    });
  });
}

extension on QuizResult {
  QuizResult _copyWithScore({required int score, int? total}) {
    return QuizResult(
      id: this.id,
      userId: userId,
      questions: questions,
      selectedAnswers: selectedAnswers,
      score: score,
      totalQuestions: total ?? totalQuestions,
      completedAt: completedAt,
      sourceTextPreview: sourceTextPreview,
    );
  }
}
