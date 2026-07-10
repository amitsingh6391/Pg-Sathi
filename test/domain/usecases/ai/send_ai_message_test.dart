import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/domain/entities/chat_message.dart';
import 'package:pg_manager/domain/repositories/ai_chat_repository.dart';
import 'package:pg_manager/domain/services/ai_service.dart';
import 'package:pg_manager/domain/usecases/ai/ai_usecases.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'send_ai_message_test.mocks.dart';

/// Max daily AI queries allowed per user.
/// Keep in sync with the value enforced in the production use case.
const int kMaxDailyAiQueries = 20;

@GenerateMocks([AiService, AiChatRepository])
void main() {
  late SendAiMessage useCase;
  late MockAiService mockAiService;
  late MockAiChatRepository mockChatRepo;

  setUp(() {
    mockAiService = MockAiService();
    mockChatRepo = MockAiChatRepository();
    useCase = SendAiMessage(
      aiService: mockAiService,
      chatRepository: mockChatRepo,
    );
  });

  const testUserId = 'user-123';
  const testMessage = 'What is the capital of India?';
  const testResponse = 'The capital of India is New Delhi.';

  group('SendAiMessage', () {
    test(
      'should_return_assistant_message_when_ai_responds_successfully',
      () async {
        // Arrange
        when(mockChatRepo.getTodayQueryCount(testUserId))
            .thenAnswer((_) async => const Right(0));
        when(mockChatRepo.saveMessage(any))
            .thenAnswer((_) async => const Right(null));
        when(mockChatRepo.incrementTodayQueryCount(testUserId))
            .thenAnswer((_) async {});
        when(mockAiService.chat(
          message: anyNamed('message'),
          conversationHistory: anyNamed('conversationHistory'),
          systemInstruction: anyNamed('systemInstruction'),
        )).thenAnswer((_) async => testResponse);

        // Act
        final result = await useCase(
          userId: testUserId,
          message: testMessage,
          history: const [],
        );

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (_) => fail('Expected Right'),
          (message) {
            expect(message.role, ChatRole.assistant);
            expect(message.content, testResponse);
            expect(message.userId, testUserId);
          },
        );

        // Verify messages were saved (user + assistant) and counter incremented
        verify(mockChatRepo.saveMessage(any)).called(2);
        verify(mockChatRepo.incrementTodayQueryCount(testUserId)).called(1);
      },
    );

    test(
      'should_return_failure_when_daily_limit_reached',
      () async {
        // Arrange
        when(mockChatRepo.getTodayQueryCount(testUserId))
            .thenAnswer((_) async => const Right(kMaxDailyAiQueries));

        // Act
        final result = await useCase(
          userId: testUserId,
          message: testMessage,
          history: const [],
        );

        // Assert
        expect(result.isLeft(), true);
        result.fold(
          (failure) => expect(failure.message, contains('Daily limit')),
          (_) => fail('Expected Left'),
        );

        // Verify AI was NOT called
        verifyNever(mockAiService.chat(
          message: anyNamed('message'),
          conversationHistory: anyNamed('conversationHistory'),
          systemInstruction: anyNamed('systemInstruction'),
        ));
      },
    );

    test(
      'should_return_failure_when_ai_service_throws',
      () async {
        // Arrange
        when(mockChatRepo.getTodayQueryCount(testUserId))
            .thenAnswer((_) async => const Right(0));
        when(mockChatRepo.saveMessage(any))
            .thenAnswer((_) async => const Right(null));
        when(mockChatRepo.incrementTodayQueryCount(testUserId))
            .thenAnswer((_) async {});
        when(mockAiService.chat(
          message: anyNamed('message'),
          conversationHistory: anyNamed('conversationHistory'),
          systemInstruction: anyNamed('systemInstruction'),
        )).thenThrow(Exception('Network error'));

        // Act
        final result = await useCase(
          userId: testUserId,
          message: testMessage,
          history: const [],
        );

        // Assert
        expect(result.isLeft(), true);
        result.fold(
          (failure) => expect(failure, isA<AiFailure>()),
          (_) => fail('Expected Left'),
        );
      },
    );

    test(
      'should_pass_exam_context_to_system_instruction',
      () async {
        // Arrange
        when(mockChatRepo.getTodayQueryCount(testUserId))
            .thenAnswer((_) async => const Right(0));
        when(mockChatRepo.saveMessage(any))
            .thenAnswer((_) async => const Right(null));
        when(mockChatRepo.incrementTodayQueryCount(testUserId))
            .thenAnswer((_) async {});
        when(mockAiService.chat(
          message: anyNamed('message'),
          conversationHistory: anyNamed('conversationHistory'),
          systemInstruction: anyNamed('systemInstruction'),
        )).thenAnswer((_) async => testResponse);

        // Act
        await useCase(
          userId: testUserId,
          message: testMessage,
          history: const [],
          examContext: 'UPSC CSE',
        );

        // Assert - verify system instruction contains exam context
        verify(mockAiService.chat(
          message: testMessage,
          conversationHistory: anyNamed('conversationHistory'),
          systemInstruction: argThat(
            contains('UPSC CSE'),
            named: 'systemInstruction',
          ),
        )).called(1);
      },
    );
  });
}
