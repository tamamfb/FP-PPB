import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/friend_model.dart';
import '../models/notification_model.dart';
import '../models/user_model.dart';
import '../services/friend_service.dart';
import '../services/notification_service.dart';

class FriendProvider extends ChangeNotifier {
  final FriendService _service = FriendService();
  final NotificationService _notifService = NotificationService();

  List<FriendModel> _friends = [];
  List<FriendModel> _incomingRequests = [];
  List<FriendModel> _outgoingRequests = [];
  List<NotificationModel> _notifications = [];
  String? _error;

  StreamSubscription? _friendsSub;
  StreamSubscription? _incomingSub;
  StreamSubscription? _outgoingSub;
  StreamSubscription? _notifsSub;
  StreamSubscription<User?>? _authSub;

  Set<String> _seenIncomingIds = {};
  Set<String> _seenNotifIds = {};
  bool _incomingFirstEmit = true;
  bool _notifsFirstEmit = true;

  FriendProvider() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _subscribe(user.uid);
      } else {
        _cancelSubscriptions();
        _friends = [];
        _incomingRequests = [];
        _outgoingRequests = [];
        _notifications = [];
        notifyListeners();
      }
    });
  }

  List<FriendModel> get friends => _friends;
  List<FriendModel> get incomingRequests => _incomingRequests;
  List<FriendModel> get outgoingRequests => _outgoingRequests;
  List<NotificationModel> get notifications => _notifications;
  int get unreadCount =>
      _notifications.where((n) => !n.read).length +
      _incomingRequests.length;
  String? get error => _error;

  void _subscribe(String uid) {
    _cancelSubscriptions();

    _friendsSub = _service.friendsStream(uid).listen((v) {
      _friends = v;
      notifyListeners();
    });

    _incomingSub = _service.incomingRequestsStream(uid).listen((v) {
      if (_incomingFirstEmit) {
        _incomingFirstEmit = false;
        _seenIncomingIds = v.map((r) => r.friendUid).toSet();
        _incomingRequests = v;
        notifyListeners();
        return;
      }
      for (final req in v) {
        if (!_seenIncomingIds.contains(req.friendUid)) {
          _notifService.showFriendRequestNotification(
            fromUid: req.friendUid,
            fromDisplayName: req.friendDisplayName,
          );
        }
      }
      _seenIncomingIds = v.map((r) => r.friendUid).toSet();
      _incomingRequests = v;
      notifyListeners();
    });

    _outgoingSub = _service.outgoingRequestsStream(uid).listen((v) {
      _outgoingRequests = v;
      notifyListeners();
    });

    _notifsSub = _service.notificationsStream(uid).listen((v) {
      if (_notifsFirstEmit) {
        _notifsFirstEmit = false;
        _seenNotifIds = v.map((n) => n.id).toSet();
        _notifications = v;
        notifyListeners();
        return;
      }
      for (final notif in v) {
        if (!_seenNotifIds.contains(notif.id) &&
            notif.type == 'game_challenge') {
          _notifService.showGameChallengeNotification(
            fromUid: notif.fromUid,
            fromDisplayName: notif.fromDisplayName,
          );
        }
      }
      _seenNotifIds = v.map((n) => n.id).toSet();
      _notifications = v;
      notifyListeners();
    });
  }

  void _cancelSubscriptions() {
    _friendsSub?.cancel();
    _incomingSub?.cancel();
    _outgoingSub?.cancel();
    _notifsSub?.cancel();
    _friendsSub = _incomingSub = _outgoingSub = _notifsSub = null;
    _seenIncomingIds = {};
    _seenNotifIds = {};
    _incomingFirstEmit = true;
    _notifsFirstEmit = true;
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _cancelSubscriptions();
    super.dispose();
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> sendRequest(UserModel me, UserModel target) async {
    _error = null;
    final blocked = await _service.canSendRequest(target.uid);
    if (blocked != null) {
      _error = blocked;
      notifyListeners();
      return;
    }
    try {
      await _service.sendFriendRequest(me: me, target: target);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> acceptRequest(String fromUid) async {
    _error = null;
    try {
      await _service.acceptFriendRequest(fromUid: fromUid);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> declineRequest(String fromUid) async {
    _error = null;
    try {
      await _service.declineFriendRequest(fromUid: fromUid);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> unfriend(String friendUid) async {
    _error = null;
    try {
      await _service.unfriend(friendUid);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> sendChallenge({
    required UserModel me,
    required String targetUid,
    required String roomCode,
    required Map<String, dynamic> roomSettings,
  }) async {
    _error = null;
    try {
      await _service.sendGameChallenge(
        me: me,
        targetUid: targetUid,
        roomCode: roomCode,
        roomSettings: roomSettings,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteNotification(String uid, String notifId) async {
    _error = null;
    try {
      await _service.deleteNotification(uid, notifId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}
