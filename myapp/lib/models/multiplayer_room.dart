import 'package:cloud_firestore/cloud_firestore.dart';
import 'quiz_session.dart';
import 'question_model.dart';

enum RoomStatus { waiting, active, intermission, finished }

class MultiplayerRoom {
  final String roomCode;
  final String hostId;
  final String hostName;
  final RoomStatus status;
  final int currentQuestionIndex;
  final DateTime? questionStartTime;
  final QuizSession settings;
  final List<QuestionModel> questions;
  final DateTime createdAt;

  const MultiplayerRoom({
    required this.roomCode,
    required this.hostId,
    required this.hostName,
    required this.status,
    required this.currentQuestionIndex,
    this.questionStartTime,
    required this.settings,
    required this.questions,
    required this.createdAt,
  });

  factory MultiplayerRoom.fromFirestore(Map<String, dynamic> data) {
    return MultiplayerRoom(
      roomCode: data['roomCode'] as String,
      hostId: data['hostId'] as String,
      hostName: data['hostName'] as String,
      status: RoomStatus.values.firstWhere(
        (s) => s.name == (data['status'] as String),
        orElse: () => RoomStatus.waiting,
      ),
      currentQuestionIndex: data['currentQuestionIndex'] as int? ?? -1,
      questionStartTime:
          (data['questionStartTime'] as Timestamp?)?.toDate(),
      settings:
          QuizSession.fromMap(data['settings'] as Map<String, dynamic>),
      questions: (data['questions'] as List<dynamic>? ?? [])
          .map((q) => QuestionModel.fromMap(q as Map<String, dynamic>))
          .toList(),
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'roomCode': roomCode,
        'hostId': hostId,
        'hostName': hostName,
        'status': status.name,
        'currentQuestionIndex': currentQuestionIndex,
        'questionStartTime': questionStartTime != null
            ? Timestamp.fromDate(questionStartTime!)
            : null,
        'settings': settings.toMap(),
        'questions': questions.map((q) => q.toMap()).toList(),
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
