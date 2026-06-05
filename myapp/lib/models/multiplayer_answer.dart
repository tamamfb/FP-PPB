class MultiplayerAnswer {
  final String uid;
  final int questionIndex;
  final String answer;
  final int elapsedMs;
  final int points;
  final bool isCorrect;

  const MultiplayerAnswer({
    required this.uid,
    required this.questionIndex,
    required this.answer,
    required this.elapsedMs,
    required this.points,
    required this.isCorrect,
  });

  factory MultiplayerAnswer.fromFirestore(Map<String, dynamic> data) {
    return MultiplayerAnswer(
      uid: data['uid'] as String,
      questionIndex: data['questionIndex'] as int,
      answer: data['answer'] as String,
      elapsedMs: data['elapsedMs'] as int,
      points: data['points'] as int? ?? 0,
      isCorrect: data['isCorrect'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'uid': uid,
        'questionIndex': questionIndex,
        'answer': answer,
        'elapsedMs': elapsedMs,
        'points': points,
        'isCorrect': isCorrect,
      };
}
