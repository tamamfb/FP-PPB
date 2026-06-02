import 'dart:math';

class QuestionModel {
  final String category;
  final String type;
  final String difficulty;
  final String question;
  final String correctAnswer;
  final List<String> incorrectAnswers;
  final List<String> allAnswers;

  const QuestionModel({
    required this.category,
    required this.type,
    required this.difficulty,
    required this.question,
    required this.correctAnswer,
    required this.incorrectAnswers,
    required this.allAnswers,
  });

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    final correct = _decodeHtml(json['correct_answer'] as String);
    final incorrect = (json['incorrect_answers'] as List)
        .map((e) => _decodeHtml(e as String))
        .toList();

    final all = [correct, ...incorrect]..shuffle(Random());

    return QuestionModel(
      category: _decodeHtml(json['category'] as String),
      type: json['type'] as String,
      difficulty: json['difficulty'] as String,
      question: _decodeHtml(json['question'] as String),
      correctAnswer: correct,
      incorrectAnswers: List.unmodifiable(incorrect),
      allAnswers: List.unmodifiable(all),
    );
  }

  static String _decodeHtml(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&ldquo;', '“')
        .replaceAll('&rdquo;', '”')
        .replaceAll('&lsquo;', '‘')
        .replaceAll('&rsquo;', '’')
        .replaceAll('&ndash;', '–')
        .replaceAll('&mdash;', '—')
        .replaceAll('&hellip;', '…');
  }
}
