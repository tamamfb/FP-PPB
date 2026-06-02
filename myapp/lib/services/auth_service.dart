import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // =========================
  // 1. AUTH STATE STREAM
  // =========================
  Stream<UserModel?> get authStateChanges {
    return _auth.authStateChanges().map((User? user) {
      if (user == null) return null;

      return UserModel(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName ?? user.email!.split('@')[0],
        photoURL: user.photoURL ?? '',
      );
    });
  }

  // =========================
  // 2. LOGIN EMAIL & PASSWORD
  // =========================
  Future<UserModel?> signInWithEmail(String email, String password) async {
    try {
      final UserCredential userCredential = await _auth
          .signInWithEmailAndPassword(email: email, password: password);

      final User? user = userCredential.user;

      if (user != null) {
        await _saveOrUpdateUser(user);

        return UserModel(
          uid: user.uid,
          email: user.email ?? '',
          displayName: user.displayName ?? email.split('@')[0],
          photoURL: user.photoURL ?? '',
        );
      }

      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' ||
          e.code == 'invalid-credential' ||
          e.code == 'wrong-password') {
        return await _registerWithEmail(email, password);
      }
      rethrow;
    } catch (e) {
      debugPrint("Error Auth Email: $e");
      rethrow;
    }
  }

  // =========================
  // 3. REGISTER EMAIL (AUTO)
  // =========================
  Future<UserModel?> _registerWithEmail(String email, String password) async {
    try {
      final UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      final User? user = userCredential.user;

      if (user != null) {
        await _saveOrUpdateUser(user);

        return UserModel(
          uid: user.uid,
          email: user.email ?? '',
          displayName: email.split('@')[0],
          photoURL: '',
        );
      }

      return null;
    } catch (e) {
      debugPrint("Error Register Email: $e");
      rethrow;
    }
  }

  // =========================
  // 4. GOOGLE SIGN IN
  // =========================
  Future<UserModel?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) return null; // user cancel

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      final User? user = userCredential.user;

      if (user != null) {
        await _saveOrUpdateUser(user);

        return UserModel(
          uid: user.uid,
          email: user.email ?? '',
          displayName: user.displayName ?? user.email!.split('@')[0],
          photoURL: user.photoURL ?? '',
        );
      }

      return null;
    } catch (e) {
      debugPrint("Error Google Sign-In: $e");
      rethrow;
    }
  }

  // =========================
  // 5. SAVE / UPDATE FIRESTORE
  // =========================
  Future<void> _saveOrUpdateUser(User user) async {
    final userRef = _db.collection('users').doc(user.uid);
    final doc = await userRef.get();

    if (!doc.exists) {
      await userRef.set({
        'uid': user.uid,
        'displayName': user.displayName ?? user.email!.split('@')[0],
        'email': user.email ?? '',
        'photoURL': user.photoURL ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      });
    } else {
      await userRef.update({'lastLogin': FieldValue.serverTimestamp()});
    }
  }

  // =========================
  // 6. LOGOUT
  // =========================
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
