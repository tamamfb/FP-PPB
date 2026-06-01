class TriviaCategory {
  final int id;
  final String name;

  const TriviaCategory({required this.id, required this.name});

  factory TriviaCategory.fromJson(Map<String, dynamic> json) {
    return TriviaCategory(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }
}

class CategoryQuestionCount {
  final int categoryId;
  final int total;
  final int easy;
  final int medium;
  final int hard;

  const CategoryQuestionCount({
    required this.categoryId,
    required this.total,
    required this.easy,
    required this.medium,
    required this.hard,
  });

  factory CategoryQuestionCount.fromJson(Map<String, dynamic> json) {
    final counts = json['category_question_count'] as Map<String, dynamic>;
    return CategoryQuestionCount(
      categoryId: json['category_id'] as int,
      total: counts['total_question_count'] as int,
      easy: counts['total_easy_question_count'] as int,
      medium: counts['total_medium_question_count'] as int,
      hard: counts['total_hard_question_count'] as int,
    );
  }
}
