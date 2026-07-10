import 'package:equatable/equatable.dart';

import 'quiz.dart';

/// A persisted quiz result that the student can review later.
///
/// Stored in Firestore at: quiz_results/{userId}/results/{id}
class QuizResult extends Equatable {
  const QuizResult({
    required this.id,
    required this.userId,
    required this.questions,
    required this.selectedAnswers,
    required this.score,
    required this.totalQuestions,
    required this.completedAt,
    this.sourceTextPreview = '',
  });

  final String id;
  final String userId;

  /// All questions with options, correct index, and explanations.
  final List<QuizQuestion> questions;

  /// The student's selected option index for each question (-1 = skipped).
  final List<int> selectedAnswers;

  final int score;
  final int totalQuestions;
  final DateTime completedAt;

  /// Truncated source text preview for display in history list.
  final String sourceTextPreview;

  double get scorePercentage =>
      totalQuestions > 0 ? (score / totalQuestions) * 100 : 0;

  String get scoreLabel {
    final pct = scorePercentage;
    if (pct >= 80) return 'Excellent';
    if (pct >= 60) return 'Good';
    if (pct >= 40) return 'Average';
    return 'Needs Improvement';
  }

  // Serialization

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'questions': questions.map(_questionToMap).toList(),
      'selectedAnswers': selectedAnswers,
      'score': score,
      'totalQuestions': totalQuestions,
      'completedAt': completedAt.toIso8601String(),
      'sourceTextPreview': sourceTextPreview,
    };
  }

  factory QuizResult.fromMap(Map<String, dynamic> map) {
    return QuizResult(
      id: map['id'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      questions: (map['questions'] as List?)
              ?.map((q) =>
                  QuizQuestion.fromMap(q as Map<String, dynamic>))
              .toList() ??
          [],
      selectedAnswers:
          List<int>.from(map['selectedAnswers'] as List? ?? []),
      score: map['score'] as int? ?? 0,
      totalQuestions: map['totalQuestions'] as int? ?? 0,
      completedAt: map['completedAt'] != null
          ? DateTime.parse(map['completedAt'] as String)
          : DateTime.now(),
      sourceTextPreview: map['sourceTextPreview'] as String? ?? '',
    );
  }

  static Map<String, dynamic> _questionToMap(QuizQuestion q) {
    return {
      'question': q.question,
      'options': q.options,
      'correctIndex': q.correctIndex,
      'explanation': q.explanation,
    };
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        questions,
        selectedAnswers,
        score,
        totalQuestions,
        completedAt,
        sourceTextPreview,
      ];
}
