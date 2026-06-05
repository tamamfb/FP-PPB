import 'package:cloud_firestore/cloud_firestore.dart';

class MultiplayerPlayer {
  final String uid;
  final String displayName;
  final int score;
  final int streak;
  final bool hasAnswered;
  final String? selectedAnswer;
  final int lastPoints;
  final DateTime joinedAt;

  const MultiplayerPlayer({
    required this.uid,
    required this.displayName,
    required this.score,
    required this.streak,
    required this.hasAnswered,
    this.selectedAnswer,
    required this.lastPoints,
    required this.joinedAt,
  });

  factory MultiplayerPlayer.fromFirestore(
      String uid, Map<String, dynamic> data) {
    return MultiplayerPlayer(
      uid: uid,
      displayName: data['displayName'] as String,
      score: data['score'] as int? ?? 0,
      streak: data['streak'] as int? ?? 0,
      hasAnswered: data['hasAnswered'] as bool? ?? false,
      selectedAnswer: data['selectedAnswer'] as String?,
      lastPoints: data['lastPoints'] as int? ?? 0,
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'uid': uid,
        'displayName': displayName,
        'score': score,
        'streak': streak,
        'hasAnswered': hasAnswered,
        'selectedAnswer': selectedAnswer,
        'lastPoints': lastPoints,
        'joinedAt': Timestamp.fromDate(joinedAt),
      };
}
