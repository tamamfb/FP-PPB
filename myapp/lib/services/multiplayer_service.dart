import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/multiplayer_room.dart';
import '../models/multiplayer_player.dart';
import '../models/multiplayer_answer.dart';
import '../models/quiz_session.dart';
import '../models/question_model.dart';

class RoomNotFoundException implements Exception {
  const RoomNotFoundException();
}

class RoomNotWaitingException implements Exception {
  const RoomNotWaitingException();
}

class RoomFullException implements Exception {
  const RoomFullException();
}

class MultiplayerService {
  static const int maxPlayers = 10;
  static const int timeLimitMs = 15000;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _rooms =>
      _firestore.collection('rooms');

  DocumentReference<Map<String, dynamic>> _roomRef(String code) =>
      _rooms.doc(code);

  CollectionReference<Map<String, dynamic>> _playersRef(String code) =>
      _roomRef(code).collection('players');

  CollectionReference<Map<String, dynamic>> _answersRef(String code) =>
      _roomRef(code).collection('answers');

  // ── Streams ───────────────────────────────────────────────────────────────

  Stream<MultiplayerRoom?> roomStream(String roomCode) {
    return _roomRef(roomCode).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return MultiplayerRoom.fromFirestore(snap.data()!);
    });
  }

  Stream<List<MultiplayerPlayer>> playersStream(String roomCode) {
    return _playersRef(roomCode)
        .orderBy('joinedAt')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => MultiplayerPlayer.fromFirestore(d.id, d.data()))
            .toList());
  }

  // ── Room code generation ──────────────────────────────────────────────────

  static const _codeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  String _generateCode() {
    final rng = Random.secure();
    return List.generate(
      6,
      (_) => _codeChars[rng.nextInt(_codeChars.length)],
    ).join();
  }

  Future<String> _generateUniqueCode() async {
    while (true) {
      final code = _generateCode();
      final doc = await _roomRef(code).get();
      if (!doc.exists) return code;
    }
  }

  // ── Room lifecycle ────────────────────────────────────────────────────────

  Future<String> createRoom({
    required String hostId,
    required String hostName,
    required QuizSession settings,
  }) async {
    final code = await _generateUniqueCode();

    final batch = _firestore.batch();

    batch.set(_roomRef(code), {
      'roomCode': code,
      'hostId': hostId,
      'hostName': hostName,
      'status': RoomStatus.waiting.name,
      'currentQuestionIndex': -1,
      'questionStartTime': null,
      'settings': settings.toMap(),
      'questions': <dynamic>[],
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.set(_playersRef(code).doc(hostId), {
      'uid': hostId,
      'displayName': hostName,
      'score': 0,
      'streak': 0,
      'hasAnswered': false,
      'selectedAnswer': null,
      'lastPoints': 0,
      'joinedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    return code;
  }

  Future<void> joinRoom({
    required String roomCode,
    required String uid,
    required String displayName,
  }) async {
    final roomSnap = await _roomRef(roomCode).get();
    if (!roomSnap.exists) throw const RoomNotFoundException();

    final data = roomSnap.data()!;
    if (data['status'] != RoomStatus.waiting.name) {
      throw const RoomNotWaitingException();
    }

    final playersSnap = await _playersRef(roomCode).count().get();
    if ((playersSnap.count ?? 0) >= maxPlayers) throw const RoomFullException();

    // Idempotent: already in the room is fine
    final existing = await _playersRef(roomCode).doc(uid).get();
    if (existing.exists) return;

    await _playersRef(roomCode).doc(uid).set({
      'uid': uid,
      'displayName': displayName,
      'score': 0,
      'streak': 0,
      'hasAnswered': false,
      'selectedAnswer': null,
      'lastPoints': 0,
      'joinedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> leaveRoom({
    required String roomCode,
    required String uid,
    required bool isHost,
  }) async {
    final batch = _firestore.batch();
    batch.delete(_playersRef(roomCode).doc(uid));
    if (isHost) {
      batch.update(_roomRef(roomCode), {'status': RoomStatus.finished.name});
    }
    await batch.commit();
  }

  // ── Game start ────────────────────────────────────────────────────────────

  // Host calls this after fetching questions from OpenTDB.
  // Writing questions to Firestore ensures all clients use the same set.
  Future<void> startGame({
    required String roomCode,
    required List<QuestionModel> questions,
  }) async {
    await _roomRef(roomCode).update({
      'questions': questions.map((q) => q.toMap()).toList(),
      'status': RoomStatus.active.name,
      'currentQuestionIndex': 0,
      'questionStartTime': FieldValue.serverTimestamp(),
    });
  }

  // ── Answer submission ─────────────────────────────────────────────────────

  Future<void> submitAnswer({
    required String roomCode,
    required int questionIndex,
    required String uid,
    required String answer,
    required int elapsedMs,
  }) async {
    final batch = _firestore.batch();

    batch.set(
      _answersRef(roomCode).doc('${questionIndex}_$uid'),
      {
        'uid': uid,
        'questionIndex': questionIndex,
        'answer': answer,
        'elapsedMs': elapsedMs,
        'points': 0,
        'isCorrect': false,
      },
    );

    batch.update(_playersRef(roomCode).doc(uid), {
      'hasAnswered': true,
      'selectedAnswer': answer,
    });

    await batch.commit();
  }

  // ── Score tallying & intermission ─────────────────────────────────────────

  // Reads all submitted answers for the question, applies the relative-speed
  // scoring formula, updates player totals, then sets status to intermission.
  //
  // Scoring:
  //   correct answerers only:
  //     basePts  = 500
  //     speedBonus = floor(500 * (1 - (yourElapsedMs - fastestMs) / timeLimitMs))
  //     total    = basePts + speedBonus  (range 500–1000)
  //   wrong / timeout: 0 pts
  Future<void> triggerIntermission({
    required String roomCode,
    required int questionIndex,
    required String correctAnswer,
  }) async {
    final answersSnap = await _answersRef(roomCode)
        .where('questionIndex', isEqualTo: questionIndex)
        .get();

    final allAnswers = answersSnap.docs
        .map((d) => MultiplayerAnswer.fromFirestore(d.data()))
        .toList();

    final correct =
        allAnswers.where((a) => a.answer == correctAnswer).toList();

    final Map<String, int> pointsMap = {};
    if (correct.isNotEmpty) {
      final fastestMs = correct.map((a) => a.elapsedMs).reduce(min);
      for (final a in correct) {
        final speedBonus =
            (500.0 * (1.0 - (a.elapsedMs - fastestMs) / timeLimitMs))
                .floor();
        pointsMap[a.uid] = 500 + speedBonus;
      }
    }

    final playersSnap = await _playersRef(roomCode).get();

    final batch = _firestore.batch();

    for (final playerDoc in playersSnap.docs) {
      final uid = playerDoc.id;
      final currentScore = (playerDoc.data()['score'] as int?) ?? 0;
      final currentStreak = (playerDoc.data()['streak'] as int?) ?? 0;
      final pts = pointsMap[uid] ?? 0;

      batch.update(playerDoc.reference, {
        'score': currentScore + pts,
        'streak': pts > 0 ? currentStreak + 1 : 0,
        'lastPoints': pts,
        // Reset for next question
        'hasAnswered': false,
        'selectedAnswer': null,
      });
    }

    for (final answerDoc in answersSnap.docs) {
      final uid = answerDoc.data()['uid'] as String;
      final pts = pointsMap[uid] ?? 0;
      batch.update(answerDoc.reference, {
        'points': pts,
        'isCorrect': pts > 0,
      });
    }

    batch.update(_roomRef(roomCode), {'status': RoomStatus.intermission.name});

    await batch.commit();
  }

  // ── Question advancement ──────────────────────────────────────────────────

  Future<void> advanceQuestion({
    required String roomCode,
    required int nextIndex,
  }) async {
    await _roomRef(roomCode).update({
      'currentQuestionIndex': nextIndex,
      'status': RoomStatus.active.name,
      'questionStartTime': FieldValue.serverTimestamp(),
    });
  }

  Future<void> endGame(String roomCode) async {
    await _roomRef(roomCode).update({'status': RoomStatus.finished.name});
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<List<MultiplayerAnswer>> fetchAnswersForQuestion({
    required String roomCode,
    required int questionIndex,
  }) async {
    final snap = await _answersRef(roomCode)
        .where('questionIndex', isEqualTo: questionIndex)
        .get();
    return snap.docs
        .map((d) => MultiplayerAnswer.fromFirestore(d.data()))
        .toList();
  }
}
