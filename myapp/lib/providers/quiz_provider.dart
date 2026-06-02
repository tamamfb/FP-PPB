import 'package:flutter/foundation.dart';
import '../models/question_model.dart';
import '../models/quiz_session.dart';
import '../models/trivia_category.dart';
import '../services/trivia_service.dart';

enum QuizStatus { idle, loading, active, finished, error }

class QuizProvider extends ChangeNotifier {
  final TriviaService _trivia = TriviaService();

  // ── Category loading state ───────────────────────────────────────────────
  List<TriviaCategory> _categories = [];
  bool _isLoadingCategories = false;
  CategoryQuestionCount? _categoryCount;
  bool _isLoadingCount = false;

  List<TriviaCategory> get categories => List.unmodifiable(_categories);
  bool get isLoadingCategories => _isLoadingCategories;
  CategoryQuestionCount? get categoryCount => _categoryCount;
  bool get isLoadingCount => _isLoadingCount;

  Future<void> loadCategories() async {
    if (_isLoadingCategories || _categories.isNotEmpty) return;
    _isLoadingCategories = true;
    notifyListeners();
    try {
      _categories = await _trivia.fetchCategories();
    } catch (_) {
      // leave _categories empty; UI shows retry state
    }
    _isLoadingCategories = false;
    notifyListeners();
  }

  Future<void> loadCategoryCount(int categoryId) async {
    _categoryCount = null;
    _isLoadingCount = true;
    notifyListeners();
    try {
      _categoryCount = await _trivia.fetchCategoryCount(categoryId);
    } catch (_) {
      // leave _categoryCount null; UI falls back to no constraints
    }
    _isLoadingCount = false;
    notifyListeners();
  }

  void clearCategoryCount() {
    _categoryCount = null;
    _isLoadingCount = false;
    notifyListeners();
  }

  // ── Quiz session state ───────────────────────────────────────────────────
  QuizStatus _status = QuizStatus.idle;
  QuizSession? _session;
  List<QuestionModel> _questions = [];
  int _currentIndex = 0;
  int _score = 0;
  List<String?> _selectedAnswers = [];
  String? _errorMessage;

  QuizStatus get status => _status;
  QuizSession? get session => _session;
  List<QuestionModel> get questions => List.unmodifiable(_questions);
  int get currentIndex => _currentIndex;
  int get score => _score;
  List<String?> get selectedAnswers => List.unmodifiable(_selectedAnswers);
  String? get errorMessage => _errorMessage;

  QuestionModel? get currentQuestion =>
      _questions.isNotEmpty ? _questions[_currentIndex] : null;

  bool get isLastQuestion =>
      _questions.isNotEmpty && _currentIndex == _questions.length - 1;

  Future<void> startQuiz(QuizSession session) async {
    _status = QuizStatus.loading;
    _session = session;
    _errorMessage = null;
    notifyListeners();

    try {
      _questions = await _trivia.fetchQuestions(
        categoryId: session.categoryId,
        difficulty: session.difficulty,
        type: session.type,
        amount: session.amount,
      );
      _currentIndex = 0;
      _score = 0;
      _selectedAnswers = List.filled(_questions.length, null);
      _status = QuizStatus.active;
    } on TriviaException catch (e) {
      _errorMessage = e.message;
      _status = QuizStatus.error;
    } catch (_) {
      _errorMessage = 'An unexpected error occurred. Please try again.';
      _status = QuizStatus.error;
    }

    notifyListeners();
  }

  // Records the answer and updates the score. Does nothing if already answered.
  void answerQuestion(String answer) {
    if (_status != QuizStatus.active) return;
    if (_selectedAnswers[_currentIndex] != null) return;

    _selectedAnswers[_currentIndex] = answer;
    if (answer == _questions[_currentIndex].correctAnswer) {
      _score++;
    }
    notifyListeners();
  }

  // Advances to the next question, or marks the quiz finished if on the last one.
  void nextQuestion() {
    if (_selectedAnswers[_currentIndex] == null) return;

    if (isLastQuestion) {
      _status = QuizStatus.finished;
    } else {
      _currentIndex++;
    }
    notifyListeners();
  }

  void reset() {
    _status = QuizStatus.idle;
    _session = null;
    _questions = [];
    _currentIndex = 0;
    _score = 0;
    _selectedAnswers = [];
    _errorMessage = null;
    notifyListeners();
  }
}
