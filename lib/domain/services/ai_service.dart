import 'dart:typed_data';

import '../entities/quiz.dart';

/// Abstract AI service interface.
/// Framework-agnostic contract for AI operations.
/// Implementations may use Groq, OpenAI, or any other provider.
abstract class AiService {
  /// Sends a message and receives a response in a conversational context.
  ///
  /// [message] is the user's input.
  /// [conversationHistory] provides prior messages for context.
  /// [systemInstruction] scopes the AI's behavior (e.g., exam tutor).
  Future<String> chat({
    required String message,
    List<AiChatTurn> conversationHistory = const [],
    String? systemInstruction,
  });

  /// Sends a message with an image attachment.
  ///
  /// [imageBytes] is the raw image data.
  /// [mimeType] e.g. "image/jpeg", "image/png", "application/pdf".
  Future<String> chatWithImage({
    required String message,
    required Uint8List imageBytes,
    required String mimeType,
    List<AiChatTurn> conversationHistory = const [],
    String? systemInstruction,
  });

  /// Generates quiz questions from source text.
  ///
  /// [text] is the study material to generate questions from.
  /// [questionCount] is how many questions to generate.
  Future<Quiz> generateQuiz({
    required String text,
    int questionCount = 10,
  });

  /// Summarizes text into concise bullet points.
  Future<String> summarize({required String text});
}

/// Represents a single turn in an AI conversation.
class AiChatTurn {
  const AiChatTurn({
    required this.role,
    required this.content,
  });

  /// 'user' or 'model'
  final String role;
  final String content;
}
