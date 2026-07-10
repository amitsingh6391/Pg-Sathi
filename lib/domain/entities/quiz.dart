import 'package:equatable/equatable.dart';

/// Represents an AI-generated quiz from study material.
class Quiz extends Equatable {
  const Quiz({
    required this.questions,
    required this.sourceText,
    required this.generatedAt,
  });

  final List<QuizQuestion> questions;

  /// Truncated source text for reference.
  final String sourceText;
  final DateTime generatedAt;

  int get totalQuestions => questions.length;

  @override
  List<Object?> get props => [questions, sourceText, generatedAt];
}

/// A single multiple-choice question within a quiz.
class QuizQuestion extends Equatable {
  const QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  final String question;
  final List<String> options;

  /// Zero-based index of the correct option.
  final int correctIndex;

  /// Explanation of why the correct answer is correct.
  final String explanation;

  String get correctAnswer =>
      correctIndex >= 0 && correctIndex < options.length
          ? options[correctIndex]
          : '';

  factory QuizQuestion.fromMap(Map<String, dynamic> map) {
    return QuizQuestion(
      question: map['question'] as String? ?? '',
      options: List<String>.from(map['options'] as List? ?? []),
      correctIndex: map['correctIndex'] as int? ?? 0,
      explanation: map['explanation'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [question, options, correctIndex, explanation];
}
