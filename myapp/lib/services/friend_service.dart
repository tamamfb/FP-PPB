import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/friend_model.dart';
import '../models/notification_model.dart';
import '../models/user_model.dart';

class FriendService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? get _myUid => FirebaseAuth.instance.currentUser?.uid;

  // ── Search ────────────────────────────────────────────────────────────────

  Future<List<UserModel>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];
    final lq = query.toLowerCase().trim();
    if (lq.isEmpty) return [];
    // Prefix query: find usernames that start with lq
    final end = lq.substring(0, lq.length - 1) +
        String.fromCharCode(lq.codeUnitAt(lq.length - 1) + 1);
    final snapshot = await _db
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: lq)
        .where('username', isLessThan: end)
        .limit(20)
        .get();
    return snapshot.docs
        .map((d) => UserModel.fromFirestore(d.data()))
        .where((u) => u.uid != _myUid)
        .toList();
  }

  // ── Friend request guards ─────────────────────────────────────────────────

  /// Returns null if a request can be sent, or an error string if blocked.
  Future<String?> canSendRequest(String targetUid) async {
    final uid = _myUid;
    if (uid == null) return 'Not logged in';

    final doc = await _db
        .collection('users')
        .doc(uid)
        .collection('friends')
        .doc(targetUid)
        .get();

    if (!doc.exists) return null;

    final status = doc.data()!['status'] as String?;
    if (status == 'pending') return 'Permintaan sudah dikirim';
    if (status == 'accepted') return 'Sudah berteman';
    if (status == 'declined') {
      final declinedAt = (doc.data()!['declinedAt'] as Timestamp?)?.toDate();
      if (declinedAt != null &&
          DateTime.now().difference(declinedAt).inHours < 24) {
        final hoursLeft = 24 - DateTime.now().difference(declinedAt).inHours;
        return 'Coba lagi dalam $hoursLeft jam';
      }
    }
    return null;
  }

  // ── Send friend request ───────────────────────────────────────────────────

  Future<void> sendFriendRequest({
    required UserModel me,
    required UserModel target,
  }) async {
    final now = Timestamp.now();
    final batch = _db.batch();

    // My outgoing doc
    batch.set(
      _db
          .collection('users')
          .doc(me.uid)
          .collection('friends')
          .doc(target.uid),
      {
        'status': 'pending',
        'initiatedBy': me.uid,
        'friendDisplayName': target.displayName,
        'friendUsername': target.username,
        'friendPhotoURL': target.photoURL,
        'createdAt': now,
        'updatedAt': now,
      },
    );

    // Target's incoming doc
    batch.set(
      _db
          .collection('users')
          .doc(target.uid)
          .collection('friends')
          .doc(me.uid),
      {
        'status': 'pending',
        'initiatedBy': me.uid,
        'friendDisplayName': me.displayName,
        'friendUsername': me.username,
        'friendPhotoURL': me.photoURL,
        'createdAt': now,
        'updatedAt': now,
      },
    );

    // Notification to target
    batch.set(
      _db
          .collection('users')
          .doc(target.uid)
          .collection('notifications')
          .doc(),
      {
        'type': 'friend_request',
        'fromUid': me.uid,
        'fromUsername': me.username,
        'fromDisplayName': me.displayName,
        'read': false,
        'createdAt': now,
      },
    );

    await batch.commit();
  }

  // ── Accept friend request ─────────────────────────────────────────────────

  Future<void> acceptFriendRequest({required String fromUid}) async {
    final uid = _myUid;
    if (uid == null) return;

    final now = Timestamp.now();

    // Query matching notifications before building the batch
    final notifQuery = await _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('type', isEqualTo: 'friend_request')
        .where('fromUid', isEqualTo: fromUid)
        .get();

    final batch = _db.batch();

    batch.update(
      _db.collection('users').doc(uid).collection('friends').doc(fromUid),
      {'status': 'accepted', 'updatedAt': now},
    );

    batch.update(
      _db.collection('users').doc(fromUid).collection('friends').doc(uid),
      {'status': 'accepted', 'updatedAt': now},
    );

    for (final doc in notifQuery.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  // ── Decline friend request ────────────────────────────────────────────────

  Future<void> declineFriendRequest({required String fromUid}) async {
    final uid = _myUid;
    if (uid == null) return;

    final now = Timestamp.now();

    final notifQuery = await _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('type', isEqualTo: 'friend_request')
        .where('fromUid', isEqualTo: fromUid)
        .get();

    final batch = _db.batch();

    // Keep requester's doc as declined (they're on cooldown for 24h)
    batch.update(
      _db.collection('users').doc(fromUid).collection('friends').doc(uid),
      {'status': 'declined', 'updatedAt': now, 'declinedAt': now},
    );

    // Delete our own doc so we're free to send if we want
    batch.delete(
      _db.collection('users').doc(uid).collection('friends').doc(fromUid),
    );

    for (final doc in notifQuery.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  // ── Unfriend ──────────────────────────────────────────────────────────────

  Future<void> unfriend(String friendUid) async {
    final uid = _myUid;
    if (uid == null) return;

    final batch = _db.batch();
    batch.delete(
        _db.collection('users').doc(uid).collection('friends').doc(friendUid));
    batch.delete(
        _db.collection('users').doc(friendUid).collection('friends').doc(uid));
    await batch.commit();
  }

  // ── Game challenge ────────────────────────────────────────────────────────

  Future<void> sendGameChallenge({
    required UserModel me,
    required String targetUid,
    required String roomCode,
    required Map<String, dynamic> roomSettings,
  }) async {
    await _db
        .collection('users')
        .doc(targetUid)
        .collection('notifications')
        .add({
      'type': 'game_challenge',
      'fromUid': me.uid,
      'fromUsername': me.username,
      'fromDisplayName': me.displayName,
      'read': false,
      'createdAt': Timestamp.now(),
      'roomCode': roomCode,
      'roomSettings': roomSettings,
    });
  }

  // ── Notification actions ──────────────────────────────────────────────────

  Future<void> deleteNotification(String uid, String notifId) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(notifId)
        .delete();
  }

  // ── Streams ───────────────────────────────────────────────────────────────

  Stream<List<FriendModel>> friendsStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('friends')
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .map((s) => s.docs
            .map((d) => FriendModel.fromFirestore(d.id, d.data()))
            .toList());
  }

  Stream<List<FriendModel>> incomingRequestsStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('friends')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((s) => s.docs
            .map((d) => FriendModel.fromFirestore(d.id, d.data()))
            .where((f) => f.initiatedBy != uid)
            .toList());
  }

  Stream<List<FriendModel>> outgoingRequestsStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('friends')
        .where('status', isEqualTo: 'pending')
        .where('initiatedBy', isEqualTo: uid)
        .snapshots()
        .map((s) => s.docs
            .map((d) => FriendModel.fromFirestore(d.id, d.data()))
            .toList());
  }

  Stream<List<NotificationModel>> notificationsStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => NotificationModel.fromFirestore(d.id, d.data()))
            .toList());
  }
}
