import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../domain/entities/quiz.dart';
import '../../domain/services/ai_service.dart';

/// Groq-powered implementation of [AiService].
///
/// Uses Groq's free tier API (OpenAI-compatible).
/// Free tier limits: 30 RPM, 14,400 RPD — no billing required.
/// Get a free API key at: https://console.groq.com
class GroqAiService implements AiService {
  static const defaultModel = 'llama-3.3-70b-versatile';
  // Llama 4 Scout: Multimodal model supporting images (up to 4MB base64)
  static const visionModel = 'meta-llama/llama-4-scout-17b-16e-instruct';
  static const _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';

  GroqAiService({required this.apiKey, this.model = defaultModel});

  final String apiKey;
  final String model;

  @override
  Future<String> chat({
    required String message,
    List<AiChatTurn> conversationHistory = const [],
    String? systemInstruction,
  }) async {
    final messages = <Map<String, String>>[];

    if (systemInstruction != null && systemInstruction.isNotEmpty) {
      messages.add({'role': 'system', 'content': systemInstruction});
    }

    for (final turn in conversationHistory) {
      messages.add({
        'role': turn.role == 'model' ? 'assistant' : turn.role,
        'content': turn.content,
      });
    }

    messages.add({'role': 'user', 'content': message});

    return _callGroq(messages);
  }

  @override
  Future<String> chatWithImage({
    required String message,
    required Uint8List imageBytes,
    required String mimeType,
    List<AiChatTurn> conversationHistory = const [],
    String? systemInstruction,
  }) async {
    // Handle PDFs: Extract text and use regular text model
    if (mimeType == 'application/pdf') {
      return _handlePdfChat(
        message: message,
        pdfBytes: imageBytes,
        conversationHistory: conversationHistory,
        systemInstruction: systemInstruction,
      );
    }
    
    // Handle images: Use vision model
    final base64Image = base64Encode(imageBytes);
    final imageUrl = 'data:$mimeType;base64,$base64Image';
    
    final messages = <Map<String, dynamic>>[];

    if (systemInstruction != null && systemInstruction.isNotEmpty) {
      messages.add({'role': 'system', 'content': systemInstruction});
    }

    // Add conversation history (text only)
    for (final turn in conversationHistory) {
      messages.add({
        'role': turn.role == 'model' ? 'assistant' : turn.role,
        'content': turn.content,
      });
    }

    // Add multimodal user message with image
    messages.add({
      'role': 'user',
      'content': [
        {
          'type': 'text',
          'text': message.isNotEmpty 
              ? message 
              : 'Please analyze this image and explain what you see.',
        },
        {
          'type': 'image_url',
          'image_url': {
            'url': imageUrl,
          },
        },
      ],
    });

    return _callGroqVision(messages);
  }
  
  /// Handles PDF documents by extracting text and using the text model.
  Future<String> _handlePdfChat({
    required String message,
    required Uint8List pdfBytes,
    List<AiChatTurn> conversationHistory = const [],
    String? systemInstruction,
  }) async {
    // Extract text from PDF
    String pdfText = '';
    try {
      final document = PdfDocument(inputBytes: pdfBytes);
      final extractor = PdfTextExtractor(document);
      pdfText = extractor.extractText();
      document.dispose();
    } catch (e) {
      pdfText = '[Unable to extract text from PDF]';
    }
    
    // Truncate if too long (keep first 8000 chars)
    if (pdfText.length > 8000) {
      pdfText = '${pdfText.substring(0, 8000)}...[truncated]';
    }
    
    // Build prompt with PDF content
    final userMessage = message.isNotEmpty
        ? '$message\n\n--- PDF CONTENT ---\n$pdfText'
        : 'Please analyze this PDF document and summarize the key points:\n\n--- PDF CONTENT ---\n$pdfText';
    
    return chat(
      message: userMessage,
      conversationHistory: conversationHistory,
      systemInstruction: systemInstruction,
    );
  }

  @override
  Future<Quiz> generateQuiz({
    required String text,
    int questionCount = 10,
  }) async {
    final truncatedText = text.length > 8000 ? text.substring(0, 8000) : text;

    final prompt = '''
Generate exactly $questionCount multiple choice questions from the following study material.

RULES:
- Each question must have exactly 4 options
- Only one option should be correct
- Include a brief explanation for the correct answer
- Questions should test understanding, not just memorization
- Vary difficulty levels

Return ONLY valid JSON in this exact format (no markdown, no extra text):
{"questions":[{"question":"What is...?","options":["Option A","Option B","Option C","Option D"],"correctIndex":0,"explanation":"The correct answer is Option A because..."}]}

STUDY MATERIAL:
$truncatedText
''';

    final messages = [
      {
        'role': 'system',
        'content':
            'You are a quiz generator. Return only valid JSON, no markdown.',
      },
      {'role': 'user', 'content': prompt},
    ];

    final responseText = await _callGroq(messages, jsonMode: true);
    return _parseQuizResponse(responseText, truncatedText);
  }

  @override
  Future<String> summarize({required String text}) async {
    final prompt = '''
Summarize the following text into clear, concise bullet points suitable for exam revision.
Focus on key facts, dates, names, and concepts.

TEXT:
$text
''';

    return chat(message: prompt);
  }

  /// Calls the Groq API and returns the response text.
  Future<String> _callGroq(
    List<Map<String, String>> messages, {
    bool jsonMode = false,
  }) async {
    final body = <String, dynamic>{
      'model': model,
      'messages': messages,
      'temperature': 0.7,
      'max_tokens': 4096,
    };

    if (jsonMode) {
      body['response_format'] = {'type': 'json_object'};
    }

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final text =
          data['choices']?[0]?['message']?['content'] as String? ?? '';
      return text.trim();
    } else {
      final error = jsonDecode(response.body);
      final msg = error['error']?['message'] ?? 'Unknown error';
      throw Exception('Groq API error (${response.statusCode}): $msg');
    }
  }

  /// Calls the Groq Vision API for image analysis.
  Future<String> _callGroqVision(List<Map<String, dynamic>> messages) async {
    final body = <String, dynamic>{
      'model': visionModel,
      'messages': messages,
      'temperature': 0.7,
      'max_tokens': 4096,
    };

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final text =
          data['choices']?[0]?['message']?['content'] as String? ?? '';
      return text.trim();
    } else {
      final error = jsonDecode(response.body);
      final msg = error['error']?['message'] ?? 'Unknown error';
      throw Exception('Groq Vision API error (${response.statusCode}): $msg');
    }
  }

  /// Parses the JSON response into a [Quiz] object.
  Quiz _parseQuizResponse(String responseText, String sourceText) {
    try {
      var cleaned = responseText.trim();
      if (cleaned.contains('```json')) {
        cleaned =
            cleaned.replaceAll('```json', '').replaceAll('```', '').trim();
      } else if (cleaned.contains('```')) {
        cleaned = cleaned.replaceAll('```', '').trim();
      }

      final json = jsonDecode(cleaned) as Map<String, dynamic>;
      final questionsJson = json['questions'] as List<dynamic>;

      final questions = questionsJson.map((q) {
        final map = q as Map<String, dynamic>;
        return QuizQuestion.fromMap(map);
      }).toList();

      return Quiz(
        questions: questions,
        sourceText: sourceText.length > 200
            ? '${sourceText.substring(0, 200)}...'
            : sourceText,
        generatedAt: DateTime.now(),
      );
    } catch (e) {
      throw FormatException('Failed to parse quiz response: $e');
    }
  }
}
