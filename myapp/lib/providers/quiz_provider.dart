import 'dart:async';
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

  // ── Timer ────────────────────────────────────────────────────────────────
  Timer? _timer;
  static const int secondsPerQuestion = 15;
  int _timeLeft = secondsPerQuestion;

  // ── Scoring & streak (Week 2 B) ──────────────────────────────────────────
  // Base 100 pts per correct + up to 50 speed bonus based on time remaining.
  int _totalPoints = 0;
  List<int> _pointsPerQuestion = [];
  int _streak = 0;
  int _maxStreak = 0;

  QuizStatus get status => _status;
  QuizSession? get session => _session;
  List<QuestionModel> get questions => List.unmodifiable(_questions);
  int get currentIndex => _currentIndex;
  int get score => _score;
  List<String?> get selectedAnswers => List.unmodifiable(_selectedAnswers);
  String? get errorMessage => _errorMessage;
  int get timeLeft => _timeLeft;
  int get totalPoints => _totalPoints;
  int get streak => _streak;
  int get maxStreak => _maxStreak;
  List<int> get pointsPerQuestion => List.unmodifiable(_pointsPerQuestion);

  QuestionModel? get currentQuestion =>
      _questions.isNotEmpty ? _questions[_currentIndex] : null;

  bool get isLastQuestion =>
      _questions.isNotEmpty && _currentIndex == _questions.length - 1;

  // ── Timer management ─────────────────────────────────────────────────────

  void _startTimer() {
    _timer?.cancel();
    _timeLeft = secondsPerQuestion;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      _timeLeft--;
      if (_timeLeft <= 0) {
        _timeLeft = 0;
        t.cancel();
        _onTimeout();
        return;
      }
      notifyListeners();
    });
  }

  void _onTimeout() {
    if (_selectedAnswers[_currentIndex] != null) return;
    // Empty string = timeout marker; no answer matches it so no red highlight.
    _selectedAnswers[_currentIndex] = '';
    _streak = 0;
    _pointsPerQuestion.add(0);
    notifyListeners();
  }

  // ── Quiz lifecycle ───────────────────────────────────────────────────────

  Future<void> startQuiz(QuizSession session) async {
    _status = QuizStatus.loading;
    _session = session;
    _errorMessage = null;
    _totalPoints = 0;
    _pointsPerQuestion = [];
    _streak = 0;
    _maxStreak = 0;
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
      _startTimer();
    } on TriviaException catch (e) {
      _errorMessage = e.message;
      _status = QuizStatus.error;
    } catch (_) {
      _errorMessage = 'An unexpected error occurred. Please try again.';
      _status = QuizStatus.error;
    }

    notifyListeners();
  }

  // Starts a quiz with a pre-fetched question list (skips the OpenTDB fetch).
  Future<void> startQuizWithQuestions(List<QuestionModel> questions) async {
    _status = QuizStatus.loading;
    _session = null;
    _errorMessage = null;
    _totalPoints = 0;
    _pointsPerQuestion = [];
    _streak = 0;
    _maxStreak = 0;
    notifyListeners();

    _questions = questions;
    _currentIndex = 0;
    _score = 0;
    _selectedAnswers = List.filled(_questions.length, null);
    _status = QuizStatus.active;
    _startTimer();
    notifyListeners();
  }

  // Records the answer, stops the timer, and calculates points with speed bonus.
  void answerQuestion(String answer) {
    if (_status != QuizStatus.active) return;
    if (_selectedAnswers[_currentIndex] != null) return;

    _timer?.cancel();
    _selectedAnswers[_currentIndex] = answer;

    if (answer == _questions[_currentIndex].correctAnswer) {
      _score++;
      _streak++;
      if (_streak > _maxStreak) _maxStreak = _streak;
      // Speed bonus: proportional to time remaining (max +50 pts).
      final speedBonus = (50 * _timeLeft / secondsPerQuestion).floor();
      _totalPoints += 100 + speedBonus;
      _pointsPerQuestion.add(100 + speedBonus);
    } else {
      _streak = 0;
      _pointsPerQuestion.add(0);
    }
    notifyListeners();
  }

  // Advances to the next question, or marks the quiz finished if on the last one.
  void nextQuestion() {
    if (_selectedAnswers[_currentIndex] == null) return;

    if (isLastQuestion) {
      _timer?.cancel();
      _status = QuizStatus.finished;
    } else {
      _currentIndex++;
      _startTimer();
    }
    notifyListeners();
  }

  void reset() {
    _timer?.cancel();
    _timer = null;
    _status = QuizStatus.idle;
    _session = null;
    _questions = [];
    _currentIndex = 0;
    _score = 0;
    _selectedAnswers = [];
    _errorMessage = null;
    _timeLeft = secondsPerQuestion;
    _totalPoints = 0;
    _pointsPerQuestion = [];
    _streak = 0;
    _maxStreak = 0;
    notifyListeners();
  }
}
