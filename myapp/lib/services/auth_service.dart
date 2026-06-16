import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Stream<UserModel?> get authStateChanges {
    return _auth.authStateChanges().map((User? firebaseUser) {
      if (firebaseUser == null) return null;

      // Sesuaikan dengan parameter required yang ada di UserModel kamu
      return UserModel(
        uid: firebaseUser.uid,
        username: firebaseUser.displayName?.toLowerCase() ?? 'user',
        displayName: firebaseUser.displayName ?? 'User Baru',
        email: firebaseUser.email ?? '',
        totalXp: 0, // Nilai default awal saat stream inisialisasi
        totalGames: 0, // Nilai default awal saat stream inisialisasi
      );
    });
  }

  /// ==========================
  /// REGISTER
  /// ==========================
  Future<String?> register({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      username = username.trim().toLowerCase();

      /// cek username duplicate
      final usernameCheck = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .get();

      if (usernameCheck.docs.isNotEmpty) {
        return 'Username sudah digunakan, silakan cari nama lain.';
      }

      /// create auth
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      User? user = credential.user;

      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'username': username,
          'displayName': username,
          'email': email.trim(),
          'photoURL': null,
          'total_xp': 0,
          'total_games': 0,
          'created_at': Timestamp.now(),
        });
      }

      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'Email sudah dipakai';

        case 'weak-password':
          return 'Password terlalu lemah';

        case 'invalid-email':
          return 'Email tidak valid';

        default:
          return e.message;
      }
    } catch (e) {
      return e.toString();
    }
  }

  /// ==========================
  /// LOGIN EMAIL / USERNAME
  /// ==========================
  Future<String?> login({
    required String logininput,
    required String password,
  }) async {
    try {
      String email = logininput.trim();

      /// login via username
      if (!email.contains('@')) {
        final result = await _firestore
            .collection('users')
            .where('username', isEqualTo: logininput.trim().toLowerCase())
            .limit(1)
            .get();

        if (result.docs.isEmpty) {
          return 'Username tidak ditemukan';
        }

        email = result.docs.first['email'];
      }

      await _auth.signInWithEmailAndPassword(email: email, password: password);

      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'invalid-credential':
          return 'Email/Password salah';

        case 'user-not-found':
          return 'User tidak ditemukan';

        default:
          return e.message;
      }
    }
  }

  /// ==========================
  /// LOGOUT
  /// ==========================
  Future<void> logout() async {
    await _auth.signOut();
  }
}
