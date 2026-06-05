class QuizSession {
  final int? categoryId;     // null = any category
  final String categoryName;
  final String difficulty;   // 'easy' | 'medium' | 'hard' | 'any'
  final String type;         // 'multiple' | 'boolean' | 'any'
  final int amount;

  const QuizSession({
    required this.categoryId,
    required this.categoryName,
    required this.difficulty,
    required this.type,
    required this.amount,
  });

  Map<String, dynamic> toMap() => {
        'categoryId': categoryId,
        'categoryName': categoryName,
        'difficulty': difficulty,
        'type': type,
        'amount': amount,
      };

  factory QuizSession.fromMap(Map<String, dynamic> map) {
    return QuizSession(
      categoryId: map['categoryId'] as int?,
      categoryName: map['categoryName'] as String,
      difficulty: map['difficulty'] as String,
      type: map['type'] as String,
      amount: map['amount'] as int,
    );
  }
}
