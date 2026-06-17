import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String type; // 'friend_request' | 'game_challenge'
  final String fromUid;
  final String fromUsername;
  final String fromDisplayName;
  final bool read;
  final DateTime createdAt;
  final String? roomCode;
  final Map<String, dynamic>? roomSettings;

  const NotificationModel({
    required this.id,
    required this.type,
    required this.fromUid,
    required this.fromUsername,
    required this.fromDisplayName,
    required this.read,
    required this.createdAt,
    this.roomCode,
    this.roomSettings,
  });

  factory NotificationModel.fromFirestore(String id, Map<String, dynamic> data) {
    return NotificationModel(
      id: id,
      type: data['type'] as String? ?? '',
      fromUid: data['fromUid'] as String? ?? '',
      fromUsername: data['fromUsername'] as String? ?? '',
      fromDisplayName: data['fromDisplayName'] as String? ?? '',
      read: data['read'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      roomCode: data['roomCode'] as String?,
      roomSettings: (data['roomSettings'] as Map<String, dynamic>?),
    );
  }
}
