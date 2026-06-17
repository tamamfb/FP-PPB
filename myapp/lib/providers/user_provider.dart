import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_model.dart';

class UserProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  UserModel? _user;
  bool _isLoading = false;
  StreamSubscription<User?>? _authSubscription;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;

  UserProvider() {
    _authSubscription = _auth.authStateChanges().listen((firebaseUser) {
      if (firebaseUser != null) {
        fetchCurrentUser();
      } else {
        clearUser();
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  /// FETCH CURRENT USER
  Future<void> fetchCurrentUser() async {
    _isLoading = true;
    notifyListeners();
    try {
      final currentUser = _auth.currentUser;

      if (currentUser == null) {
        _user = null;
        _isLoading = false;
        notifyListeners();
        return;
      }

      final doc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;

        _user = UserModel(
          uid: data['uid'] ?? '',
          displayName: data['displayName'] ?? data['username'] ?? '',
          username: data['username'] ?? '',
          photoURL: data['photoURL'],
          email: data['email'],
          totalXp: data['total_xp'] ?? 0,
          totalGames: data['total_games'] ?? 0,
          lastDailyDate: data['lastDailyDate'],
          lastDailyScore: data['lastDailyScore'] ?? 0,
        );
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      debugPrint('Error fetchCurrentUser: $e');
      notifyListeners();
    }
  }

  /// SIMPAN HASIL KUIS SOLO
  Future<void> simpanHasilKuisSolo({
    required int skorAkhir,
    required int jumlahBenar,
    required int totalSoal,
    List<Map<String, dynamic>>? answers,
  }) async {
    try {
      final currentUser = _auth.currentUser;

      if (currentUser == null) return;

      final userRef = _firestore.collection('users').doc(currentUser.uid);

      /// ambil data lama
      final userSnapshot = await userRef.get();

      final data = userSnapshot.data() ?? {};

      final totalXpLama = data['total_xp'] ?? 0;

      final totalGamesLama = data['total_games'] ?? 0;

      /// hitung baru
      final totalXpBaru = totalXpLama + skorAkhir;

      final totalGamesBaru = totalGamesLama + 1;

      /// update user utama
      await userRef.set({
        'uid': currentUser.uid,
        'total_xp': totalXpBaru,
        'total_games': totalGamesBaru,
      }, SetOptions(merge: true));

      /// simpan history
      await userRef.collection('history').add({
        'skorAkhir': skorAkhir,
        'jumlahBenar': jumlahBenar,
        'totalSoal': totalSoal,
        'timestamp': FieldValue.serverTimestamp(),
        if (answers != null) 'answers': answers,
      });

      /// refresh UI
      await fetchCurrentUser();
    } catch (e) {
      debugPrint('Error simpanHasilKuisSolo: $e');
    }
  }

  /// SIMPAN HASIL MULTIPLAYER
  Future<void> simpanHasilMultiplayer({required int score}) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final userRef = _firestore.collection('users').doc(currentUser.uid);
      final snapshot = await userRef.get();
      final data = snapshot.data() ?? {};

      final xpGained = score ~/ 5;
      await userRef.set({
        'uid': currentUser.uid,
        'total_xp': (data['total_xp'] ?? 0) + xpGained,
        'total_games': (data['total_games'] ?? 0) + 1,
      }, SetOptions(merge: true));

      await userRef.collection('history').add({
        'skorAkhir': xpGained,
        'mode': 'multiplayer',
        'timestamp': FieldValue.serverTimestamp(),
      });

      await fetchCurrentUser();
    } catch (e) {
      debugPrint('Error simpanHasilMultiplayer: $e');
    }
  }

  /// SIMPAN HASIL DAILY CHALLENGE (2x XP)
  Future<void> simpanHasilDaily({
    required int skorAkhir,
    required int jumlahBenar,
    required int totalSoal,
    List<Map<String, dynamic>>? answers,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final now = DateTime.now();
      final todayKey =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final xpGained = skorAkhir * 2;

      final userRef = _firestore.collection('users').doc(currentUser.uid);
      final snapshot = await userRef.get();
      final data = snapshot.data() ?? {};

      await userRef.set({
        'uid': currentUser.uid,
        'total_xp': (data['total_xp'] ?? 0) + xpGained,
        'total_games': (data['total_games'] ?? 0) + 1,
        'lastDailyDate': todayKey,
        'lastDailyScore': xpGained,
      }, SetOptions(merge: true));

      await userRef.collection('history').add({
        'skorAkhir': xpGained,
        'jumlahBenar': jumlahBenar,
        'totalSoal': totalSoal,
        'mode': 'daily',
        'timestamp': FieldValue.serverTimestamp(),
        if (answers != null) 'answers': answers,
      });

      await fetchCurrentUser();
    } catch (e) {
      debugPrint('Error simpanHasilDaily: $e');
    }
  }

  /// LEADERBOARD TOP 10
  /// REALTIME
  Stream<List<UserModel>> get leaderboardStream {
    return _firestore
        .collection('users')
        .orderBy('total_xp', descending: true)
        .limit(10)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();

            return UserModel(
              uid: data['uid'] ?? '',
              displayName: data['displayName'] ?? data['username'] ?? '',
              username: data['username'] ?? '',
              photoURL: data['photoURL'],
              email: data['email'],
              totalXp: data['total_xp'] ?? 0,
              totalGames: data['total_games'] ?? 0,
            );
          }).toList();
        });
  }

  /// UPDATE PROFILE (username + display name)
  Future<String?> updateProfile({
    required String username,
    required String displayName,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return 'Not logged in';

      final newUsername = username.trim().toLowerCase();
      final newDisplayName = displayName.trim();

      if (newUsername.isEmpty) return 'Username cannot be empty';
      if (newDisplayName.isEmpty) return 'Display name cannot be empty';

      if (newUsername != _user?.username) {
        final check = await _firestore
            .collection('users')
            .where('username', isEqualTo: newUsername)
            .get();

        if (check.docs.isNotEmpty) {
          return 'Username sudah digunakan, silakan cari nama lain.';
        }
      }

      await _firestore.collection('users').doc(currentUser.uid).update({
        'username': newUsername,
        'displayName': newDisplayName,
      });

      await fetchCurrentUser();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// CLEAR USER
  void clearUser() {
    _user = null;
    notifyListeners();
  }
}
