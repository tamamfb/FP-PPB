import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/multiplayer_room.dart';
import '../models/multiplayer_player.dart';
import '../models/question_model.dart';
import '../models/quiz_session.dart';
import '../services/multiplayer_service.dart';
import '../services/trivia_service.dart';

enum MultiplayerStatus {
  idle,
  creating,
  joining,
  lobby,
  loadingQuestions,
  active,
  answered,
  intermission,
  finished,
  error,
}

class MultiplayerProvider extends ChangeNotifier {
  final MultiplayerService _service = MultiplayerService();
  final TriviaService _trivia = TriviaService();

  MultiplayerStatus _status = MultiplayerStatus.idle;
  MultiplayerRoom? _room;
  List<MultiplayerPlayer> _players = [];
  String? _myUid;
  String? _error;

  // Local countdown derived from server timestamp
  Timer? _countdownTimer;
  int _timeLeftMs = MultiplayerService.timeLimitMs;

  // Incremented each time _startCountdown fires with a confirmed timestamp.
  // Used as QuizTimerBar's resetKey so the bar only restarts when the server
  // time is actually known (avoids the host's pending-write snapshot problem).
  int _questionKey = 0;

  // Guards against double-triggering intermission
  bool _intermissionTriggered = false;
  // Guards against submitting a blank answer more than once per question
  bool _hasAutoSubmitted = false;

  // Intermission auto-advance
  static const int intermissionSeconds = 5;
  Timer? _intermissionTimer;
  int _intermissionCountdown = 0;
  bool _autoAdvanceStarted = false;

  StreamSubscription<MultiplayerRoom?>? _roomSub;
  StreamSubscription<List<MultiplayerPlayer>>? _playersSub;

  // ── Getters ───────────────────────────────────────────────────────────────

  MultiplayerStatus get status => _status;
  MultiplayerRoom? get room => _room;
  List<MultiplayerPlayer> get players => List.unmodifiable(_players);
  String? get error => _error;
  bool get isHost => _room != null && _room!.hostId == _myUid;

  int get timeLeftMs => _timeLeftMs;
  int get timeLeftSeconds => (_timeLeftMs / 1000).ceil().clamp(0, 15);
  int get questionKey => _questionKey;
  int get intermissionCountdown => _intermissionCountdown;

  List<MultiplayerPlayer> get leaderboard =>
      (List.of(_players)..sort((a, b) => b.score.compareTo(a.score)));

  MultiplayerPlayer? get myPlayer {
    final matches = _players.where((p) => p.uid == _myUid);
    return matches.isEmpty ? null : matches.first;
  }

  int get answeredCount => _players.where((p) => p.hasAnswered).length;
  bool get allAnswered =>
      _players.isNotEmpty && answeredCount == _players.length;

  bool get isLastQuestion {
    final room = _room;
    if (room == null || room.questions.isEmpty) return false;
    return room.currentQuestionIndex == room.questions.length - 1;
  }

  // Returns null when in lobby (index == -1) or questions not yet loaded.
  QuestionModel? get currentQuestion {
    final room = _room;
    if (room == null) return null;
    final idx = room.currentQuestionIndex;
    if (idx < 0 || idx >= room.questions.length) return null;
    return room.questions[idx];
  }

  // ── Room creation ─────────────────────────────────────────────────────────

  Future<void> createRoom({
    required String uid,
    required String displayName,
    required QuizSession settings,
  }) async {
    _myUid = uid;
    _error = null;
    _status = MultiplayerStatus.creating;
    notifyListeners();

    try {
      final code = await _service.createRoom(
        hostId: uid,
        hostName: displayName,
        settings: settings,
      );
      _subscribeToRoom(code);
    } catch (_) {
      _error = 'Failed to create room. Please try again.';
      _status = MultiplayerStatus.error;
      notifyListeners();
    }
  }

  // ── Room joining ──────────────────────────────────────────────────────────

  Future<void> joinRoom({
    required String roomCode,
    required String uid,
    required String displayName,
  }) async {
    _myUid = uid;
    _error = null;
    _status = MultiplayerStatus.joining;
    notifyListeners();

    try {
      await _service.joinRoom(
        roomCode: roomCode,
        uid: uid,
        displayName: displayName,
      );
      _subscribeToRoom(roomCode);
    } on RoomNotFoundException {
      _error = 'Room not found. Check the code and try again.';
      _status = MultiplayerStatus.error;
      notifyListeners();
    } on RoomNotWaitingException {
      _error = 'This game has already started.';
      _status = MultiplayerStatus.error;
      notifyListeners();
    } on RoomFullException {
      _error = 'This room is full (max ${MultiplayerService.maxPlayers} players).';
      _status = MultiplayerStatus.error;
      notifyListeners();
    } catch (_) {
      _error = 'Failed to join room. Please try again.';
      _status = MultiplayerStatus.error;
      notifyListeners();
    }
  }

  // ── Stream subscriptions ──────────────────────────────────────────────────

  void _subscribeToRoom(String roomCode) {
    _roomSub?.cancel();
    _playersSub?.cancel();

    _roomSub = _service.roomStream(roomCode).listen(
      _onRoomChanged,
      onError: (_) {
        _error = 'Connection lost.';
        _status = MultiplayerStatus.error;
        notifyListeners();
      },
    );

    _playersSub = _service.playersStream(roomCode).listen(
      _onPlayersChanged,
      onError: (_) {
        // Stream died (e.g. Firestore permission denied). Resubscribe once so
        // a transient error doesn't permanently freeze the player list.
        Future.delayed(const Duration(seconds: 2), () {
          if (_room != null) _subscribeToRoom(roomCode);
        });
      },
    );
  }

  void _onRoomChanged(MultiplayerRoom? room) {
    if (room == null) return;

    final prevRoom = _room;
    _room = room;

    switch (room.status) {
      case RoomStatus.waiting:
        _status = MultiplayerStatus.lobby;

      case RoomStatus.active:
        _intermissionTimer?.cancel();
        final answered = myPlayer?.hasAnswered ?? false;
        _status =
            answered ? MultiplayerStatus.answered : MultiplayerStatus.active;

        final questionChanged =
            prevRoom?.currentQuestionIndex != room.currentQuestionIndex ||
                prevRoom?.status != RoomStatus.active;

        // Reset per-question guards only when the question actually changed.
        if (questionChanged) {
          _intermissionTriggered = false;
          _hasAutoSubmitted = false;
          _autoAdvanceStarted = false;
        }

        // Start countdown when the question changes OR when the server
        // timestamp finally resolves (first event may deliver null).
        final timestampResolved =
            prevRoom?.questionStartTime == null && room.questionStartTime != null;
        if ((questionChanged || timestampResolved) &&
            room.questionStartTime != null) {
          _startCountdown(room.questionStartTime!);
        }

      case RoomStatus.intermission:
        _countdownTimer?.cancel();
        _status = MultiplayerStatus.intermission;
        if (!_autoAdvanceStarted) {
          _autoAdvanceStarted = true;
          _startIntermissionCountdown();
        }

      case RoomStatus.finished:
        _countdownTimer?.cancel();
        _status = MultiplayerStatus.finished;
    }

    notifyListeners();
  }

  void _onPlayersChanged(List<MultiplayerPlayer> players) {
    _players = players;

    // Keep local status in sync when our answered state changes
    if (_room?.status == RoomStatus.active) {
      final answered = myPlayer?.hasAnswered ?? false;
      if (answered && _status == MultiplayerStatus.active) {
        _status = MultiplayerStatus.answered;
      }
    }

    // Host triggers intermission as soon as every player has answered
    if (isHost &&
        _room?.status == RoomStatus.active &&
        allAnswered &&
        !_intermissionTriggered) {
      _triggerIntermission();
    }

    notifyListeners();
  }

  // ── Countdown timer ───────────────────────────────────────────────────────

  void _startCountdown(DateTime questionStartTime) {
    _countdownTimer?.cancel();
    _questionKey++;

    // Helper — milliseconds elapsed since the question started on the server.
    int msElapsed() =>
        DateTime.now().difference(questionStartTime).inMilliseconds;

    // Compute the actual remaining time immediately so the timer bar
    // initialises from the correct server-relative position on first render,
    // including for players who arrive late due to lag.
    _timeLeftMs =
        (MultiplayerService.timeLimitMs - msElapsed()).clamp(0, MultiplayerService.timeLimitMs).toInt();

    _countdownTimer =
        Timer.periodic(const Duration(milliseconds: 100), (_) {
      _timeLeftMs =
          (MultiplayerService.timeLimitMs - msElapsed()).clamp(0, MultiplayerService.timeLimitMs).toInt();

      if (_timeLeftMs == 0) {
        _countdownTimer?.cancel();
        _onTimerExpired();
      }

      notifyListeners();
    });
  }

  // Runs on every device. Host is the only one who actually calls advanceToNext.
  void _startIntermissionCountdown() {
    _intermissionTimer?.cancel();
    _intermissionCountdown = intermissionSeconds;
    _intermissionTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_intermissionCountdown > 0) {
        _intermissionCountdown--;
        notifyListeners();
      }
      if (_intermissionCountdown <= 0) {
        t.cancel();
        if (isHost) advanceToNext();
      }
    });
  }

  void _onTimerExpired() {
    // Auto-submit blank for this player if they haven't answered
    if (_myUid != null &&
        _room != null &&
        !(myPlayer?.hasAnswered ?? false) &&
        !_hasAutoSubmitted) {
      _hasAutoSubmitted = true;
      _service.submitAnswer(
        roomCode: _room!.roomCode,
        questionIndex: _room!.currentQuestionIndex,
        uid: _myUid!,
        answer: '',
        elapsedMs: MultiplayerService.timeLimitMs,
      );
    }

    // Host triggers intermission after the timer expires
    if (isHost && !_intermissionTriggered) {
      _triggerIntermission();
    }
  }

  // ── Answer submission ─────────────────────────────────────────────────────

  Future<void> submitAnswer(String answer) async {
    final room = _room;
    final uid = _myUid;
    if (room == null || uid == null) return;
    if (myPlayer?.hasAnswered ?? false) return;

    _countdownTimer?.cancel();

    final elapsedMs = room.questionStartTime != null
        ? DateTime.now()
            .difference(room.questionStartTime!)
            .inMilliseconds
            .clamp(0, MultiplayerService.timeLimitMs)
        : MultiplayerService.timeLimitMs;

    await _service.submitAnswer(
      roomCode: room.roomCode,
      questionIndex: room.currentQuestionIndex,
      uid: uid,
      answer: answer,
      elapsedMs: elapsedMs,
    );

    _status = MultiplayerStatus.answered;
    notifyListeners();
  }

  // ── Host-only actions ─────────────────────────────────────────────────────

  // Fetches questions from OpenTDB and starts the game.
  Future<void> startGame() async {
    final room = _room;
    if (room == null || !isHost) return;

    _status = MultiplayerStatus.loadingQuestions;
    _error = null;
    notifyListeners();

    try {
      final questions = await _trivia.fetchQuestions(
        categoryId: room.settings.categoryId,
        difficulty: room.settings.difficulty,
        type: room.settings.type,
        amount: room.settings.amount,
      );
      await _service.startGame(roomCode: room.roomCode, questions: questions);
    } on TriviaException catch (e) {
      _error = e.message;
      _status = MultiplayerStatus.lobby;
      notifyListeners();
    } catch (_) {
      _error = 'Failed to load questions. Please try again.';
      _status = MultiplayerStatus.lobby;
      notifyListeners();
    }
  }

  Future<void> _triggerIntermission() async {
    final room = _room;
    if (room == null || !isHost || _intermissionTriggered) return;
    final question = currentQuestion;
    if (question == null) return;

    _intermissionTriggered = true;

    await _service.triggerIntermission(
      roomCode: room.roomCode,
      questionIndex: room.currentQuestionIndex,
      correctAnswer: question.correctAnswer,
    );
  }

  // Host advances to the next question, or ends the game after the last one.
  Future<void> advanceToNext() async {
    final room = _room;
    if (room == null || !isHost) return;

    if (isLastQuestion) {
      await _service.endGame(room.roomCode);
    } else {
      await _service.advanceQuestion(
        roomCode: room.roomCode,
        nextIndex: room.currentQuestionIndex + 1,
      );
    }
  }

  // ── Leave / cleanup ───────────────────────────────────────────────────────

  Future<void> leaveRoom() async {
    final room = _room;
    final uid = _myUid;
    if (room != null && uid != null) {
      await _service.leaveRoom(
        roomCode: room.roomCode,
        uid: uid,
        isHost: isHost,
      );
    }
    reset();
  }

  void reset() {
    _countdownTimer?.cancel();
    _intermissionTimer?.cancel();
    _roomSub?.cancel();
    _playersSub?.cancel();

    _status = MultiplayerStatus.idle;
    _room = null;
    _players = [];
    _myUid = null;
    _error = null;
    _timeLeftMs = MultiplayerService.timeLimitMs;
    _questionKey = 0;
    _intermissionTriggered = false;
    _hasAutoSubmitted = false;
    _autoAdvanceStarted = false;
    _intermissionCountdown = 0;
    _countdownTimer = null;
    _intermissionTimer = null;
    _roomSub = null;
    _playersSub = null;

    notifyListeners();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _intermissionTimer?.cancel();
    _roomSub?.cancel();
    _playersSub?.cancel();
    super.dispose();
  }
}
