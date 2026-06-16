import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_model.dart';

class UserProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  UserModel? _user;

  UserModel? get user => _user;

  /// FETCH CURRENT USER
  Future<void> fetchCurrentUser() async {
    try {
      final currentUser = _auth.currentUser;

      if (currentUser == null) {
        _user = null;
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
        );
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error fetchCurrentUser: $e');
    }
  }

  /// SIMPAN HASIL KUIS SOLO
  Future<void> simpanHasilKuisSolo({
    required int skorAkhir,
    required int jumlahBenar,
    required int totalSoal,
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
      });

      /// refresh UI
      await fetchCurrentUser();
    } catch (e) {
      debugPrint('Error simpanHasilKuisSolo: $e');
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

  /// CLEAR USER
  void clearUser() {
    _user = null;
    notifyListeners();
  }
}
