import 'dart:typed_data';

import 'package:dartz/dartz.dart';

import '../../../core/constants/app_support_context.dart';
import '../../core/failure.dart';
import '../../entities/chat_message.dart';
import '../../entities/quiz.dart';
import '../../repositories/ai_chat_repository.dart';
import '../../services/ai_service.dart';

// =============================================================================
// Send AI Message
// =============================================================================

/// Sends a message to the AI and persists both the user message and AI response.
class SendAiMessage {
  const SendAiMessage({
    required this.aiService,
    required this.chatRepository,
  });

  final AiService aiService;
  final AiChatRepository chatRepository;

  Future<Either<Failure, ChatMessage>> call({
    required String userId,
    required String message,
    required List<ChatMessage> history,
    String? examContext,
    Uint8List? imageBytes,
    String? imageMimeType,
  }) async {
    try {
      // Save user message.
      final userMessage = ChatMessage(
        id: '${userId}_${DateTime.now().millisecondsSinceEpoch}',
        userId: userId,
        content: message,
        role: ChatRole.user,
        timestamp: DateTime.now(),
      );
      await chatRepository.saveMessage(userMessage);

      // Build conversation history for context.
      final turns = history.map((m) {
        return AiChatTurn(
          role: m.role == ChatRole.user ? 'user' : 'model',
          content: m.content,
        );
      }).toList();

      final systemInstruction = _buildSystemInstruction(examContext);

      // Call AI service — with or without image.
      final String responseText;
      if (imageBytes != null && imageMimeType != null) {
        responseText = await aiService.chatWithImage(
          message: message,
          imageBytes: imageBytes,
          mimeType: imageMimeType,
          conversationHistory: turns,
          systemInstruction: systemInstruction,
        );
      } else {
        responseText = await aiService.chat(
          message: message,
          conversationHistory: turns,
          systemInstruction: systemInstruction,
        );
      }

      // Save assistant response.
      final assistantMessage = ChatMessage(
        id: '${userId}_${DateTime.now().millisecondsSinceEpoch}_resp',
        userId: userId,
        content: responseText,
        role: ChatRole.assistant,
        timestamp: DateTime.now(),
      );
      await chatRepository.saveMessage(assistantMessage);

      return Right(assistantMessage);
    } catch (e) {
      return Left(AiFailure(message: 'Failed to get response: $e'));
    }
  }

  String _buildSystemInstruction(String? examContext) {
    // Include PG Sathi app context for in-app support
    final appContext = libraryTrackSupportContext;
    
    final studyBase = '''
You are PG Sathi AI - a helpful assistant that can:
1. Answer questions about the PG Sathi app (features, how-to, pricing, troubleshooting)
2. Help with study doubts for Indian competitive exams (UPSC/SSC/Banking)

RULES:
- For app questions: Use the PG Sathi knowledge provided below
- For study questions: Provide clear, concise, accurate answers with examples
- Use simple language, be friendly and helpful
- If unsure, suggest contacting WhatsApp support: 9548582776

$appContext
''';

    if (examContext != null && examContext.isNotEmpty) {
      return '$studyBase\n\nThe student is preparing for: $examContext. '
          'Tailor study answers to this exam\'s syllabus and difficulty level.';
    }
    return studyBase;
  }
}

// =============================================================================
// Get Chat History (paginated)
// =============================================================================

/// Retrieves paginated chat history for a user.
///
/// Loads only [limit] messages per page to minimize Firestore reads.
/// Pass [beforeMessageId] from the previous page to load older messages.
class GetChatHistory {
  const GetChatHistory({required this.chatRepository});

  final AiChatRepository chatRepository;

  Future<Either<Failure, PaginatedChatMessages>> call(
    String userId, {
    int limit = 6,
    String? beforeMessageId,
  }) {
    return chatRepository.getChatHistory(
      userId,
      limit: limit,
      beforeMessageId: beforeMessageId,
    );
  }
}

// =============================================================================
// Clear Chat History
// =============================================================================

/// Clears all chat history for a user.
class ClearChatHistory {
  const ClearChatHistory({required this.chatRepository});

  final AiChatRepository chatRepository;

  Future<Either<Failure, void>> call(String userId) {
    return chatRepository.clearHistory(userId);
  }
}

// =============================================================================
// Generate Quiz
// =============================================================================

/// Generates a quiz from study material text using AI.
class GenerateQuiz {
  const GenerateQuiz({required this.aiService});

  final AiService aiService;

  Future<Either<Failure, Quiz>> call({
    required String text,
    int questionCount = 10,
  }) async {
    try {
      if (text.trim().length < 50) {
        return const Left(AiFailure(
          message: 'Text is too short. Provide at least 50 characters '
              'of study material.',
        ));
      }

      final quiz = await aiService.generateQuiz(
        text: text,
        questionCount: questionCount,
      );

      if (quiz.questions.isEmpty) {
        return const Left(AiFailure(
          message: 'Could not generate questions from the provided text. '
              'Try with different study material.',
        ));
      }

      return Right(quiz);
    } catch (e) {
      return Left(AiFailure(message: 'Quiz generation failed: $e'));
    }
  }
}

// =============================================================================
// AI-specific Failure
// =============================================================================

/// Failure type for AI operations.
class AiFailure extends Failure {
  const AiFailure({super.message});
}
