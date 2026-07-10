import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/quiz.dart';
import 'package:pg_manager/domain/services/ai_service.dart';
import 'package:pg_manager/domain/usecases/ai/ai_usecases.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'generate_quiz_test.mocks.dart';

@GenerateMocks([AiService])
void main() {
  late GenerateQuiz useCase;
  late MockAiService mockAiService;

  setUp(() {
    mockAiService = MockAiService();
    useCase = GenerateQuiz(aiService: mockAiService);
  });

  final testQuiz = Quiz(
    questions: const [
      QuizQuestion(
        question: 'What is the capital of India?',
        options: ['Mumbai', 'New Delhi', 'Kolkata', 'Chennai'],
        correctIndex: 1,
        explanation: 'New Delhi is the capital of India.',
      ),
      QuizQuestion(
        question: 'Which river is the longest in India?',
        options: ['Yamuna', 'Godavari', 'Ganga', 'Krishna'],
        correctIndex: 2,
        explanation: 'The Ganga is the longest river in India.',
      ),
    ],
    sourceText: 'India is a country...',
    generatedAt: DateTime.now(),
  );

  group('GenerateQuiz', () {
    test(
      'should_return_quiz_when_text_is_valid_and_ai_succeeds',
      () async {
        // Arrange
        const text = 'India is a democratic republic with a parliamentary '
            'system of government. New Delhi is the capital.';
        when(mockAiService.generateQuiz(
          text: anyNamed('text'),
          questionCount: anyNamed('questionCount'),
        )).thenAnswer((_) async => testQuiz);

        // Act
        final result = await useCase(text: text);

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (_) => fail('Expected Right'),
          (quiz) {
            expect(quiz.questions.length, 2);
            expect(quiz.questions.first.options.length, 4);
          },
        );
      },
    );

    test(
      'should_return_failure_when_text_is_too_short',
      () async {
        // Act
        final result = await useCase(text: 'Short text');

        // Assert
        expect(result.isLeft(), true);
        result.fold(
          (failure) => expect(failure.message, contains('too short')),
          (_) => fail('Expected Left'),
        );

        // Verify AI was never called
        verifyNever(mockAiService.generateQuiz(
          text: anyNamed('text'),
          questionCount: anyNamed('questionCount'),
        ));
      },
    );

    test(
      'should_return_failure_when_ai_returns_empty_quiz',
      () async {
        // Arrange
        const text = 'This is a sufficiently long text for generating quiz '
            'questions from the provided study material.';
        final emptyQuiz = Quiz(
          questions: const [],
          sourceText: text,
          generatedAt: DateTime.now(),
        );
        when(mockAiService.generateQuiz(
          text: anyNamed('text'),
          questionCount: anyNamed('questionCount'),
        )).thenAnswer((_) async => emptyQuiz);

        // Act
        final result = await useCase(text: text);

        // Assert
        expect(result.isLeft(), true);
        result.fold(
          (failure) => expect(failure.message, contains('Could not generate')),
          (_) => fail('Expected Left'),
        );
      },
    );

    test(
      'should_return_failure_when_ai_throws_exception',
      () async {
        // Arrange
        const text = 'This is a sufficiently long text for generating quiz '
            'questions from the provided study material.';
        when(mockAiService.generateQuiz(
          text: anyNamed('text'),
          questionCount: anyNamed('questionCount'),
        )).thenThrow(Exception('API error'));

        // Act
        final result = await useCase(text: text);

        // Assert
        expect(result.isLeft(), true);
        result.fold(
          (failure) => expect(failure, isA<AiFailure>()),
          (_) => fail('Expected Left'),
        );
      },
    );

    test(
      'should_pass_custom_question_count',
      () async {
        // Arrange
        const text = 'This is a sufficiently long text for generating quiz '
            'questions from the provided study material.';
        when(mockAiService.generateQuiz(
          text: anyNamed('text'),
          questionCount: anyNamed('questionCount'),
        )).thenAnswer((_) async => testQuiz);

        // Act
        await useCase(text: text, questionCount: 5);

        // Assert
        verify(mockAiService.generateQuiz(
          text: text,
          questionCount: 5,
        )).called(1);
      },
    );
  });
}
