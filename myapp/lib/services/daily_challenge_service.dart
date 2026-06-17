import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/question_model.dart';
import 'trivia_service.dart';

class DailyChallengeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TriviaService _trivia = TriviaService();

  static String get todayKey {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<List<QuestionModel>> fetchOrCreateTodayQuestions() async {
    final docRef = _firestore.collection('dailyChallenge').doc(todayKey);
    final doc = await docRef.get();

    if (doc.exists) {
      final rawList = doc.data()!['questions'] as List;
      return rawList
          .map((q) => QuestionModel.fromMap(q as Map<String, dynamic>))
          .toList();
    }

    // First player of the day: fetch from OpenTDB and store for everyone
    final questions = await _trivia.fetchQuestions(amount: 10);

    await docRef.set({
      'questions': questions.map((q) => q.toMap()).toList(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    return questions;
  }
}
