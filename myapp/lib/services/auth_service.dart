import '../models/user_model.dart';

class AuthService {
  // Teammate C will implement Google Sign In here
  Future<UserModel?> signInWithGoogle() async => null;
  Future<void> signOut() async {}
  Stream<UserModel?> get authStateChanges => const Stream.empty();
}
