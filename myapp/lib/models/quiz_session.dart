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
}
