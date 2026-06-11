import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> login({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
  }

  Future<UserCredential> register({
    required String email,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
  }

  Future<void> logout() {
    return _auth.signOut();
  }

  Future<void> updateProfile({
    required String name,
    required String email,
    required String password,
  }) async {
    final user = _auth.currentUser;

    if (user == null) return;

    if (name.trim().isNotEmpty) {
      await user.updateDisplayName(name.trim());
    }

    if (email.trim().isNotEmpty && email.trim() != user.email) {
       // ignore: deprecated_member_use
      await user.updateEmail(email.trim());
    }

    if (password.trim().isNotEmpty) {
      await user.updatePassword(password.trim());
    }

    await user.reload();
  }
}