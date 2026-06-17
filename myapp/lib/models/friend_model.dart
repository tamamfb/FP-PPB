import 'package:cloud_firestore/cloud_firestore.dart';

class FriendModel {
  final String friendUid;
  final String friendDisplayName;
  final String friendUsername;
  final String? friendPhotoURL;
  final String status; // 'pending' | 'accepted' | 'declined'
  final String initiatedBy;
  final DateTime createdAt;
  final DateTime? declinedAt;

  const FriendModel({
    required this.friendUid,
    required this.friendDisplayName,
    required this.friendUsername,
    this.friendPhotoURL,
    required this.status,
    required this.initiatedBy,
    required this.createdAt,
    this.declinedAt,
  });

  factory FriendModel.fromFirestore(String docId, Map<String, dynamic> data) {
    return FriendModel(
      friendUid: docId,
      friendDisplayName: data['friendDisplayName'] as String? ?? '',
      friendUsername: data['friendUsername'] as String? ?? '',
      friendPhotoURL: data['friendPhotoURL'] as String?,
      status: data['status'] as String? ?? 'pending',
      initiatedBy: data['initiatedBy'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      declinedAt: (data['declinedAt'] as Timestamp?)?.toDate(),
    );
  }
}
