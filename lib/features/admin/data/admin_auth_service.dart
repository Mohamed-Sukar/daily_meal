import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final adminAuthProvider = Provider<AdminAuthService>((ref) {
  return AdminAuthService(FirebaseAuth.instance);
});

final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(adminAuthProvider);
  return authService.authStateChanges();
});

class AdminAuthService {
  final FirebaseAuth _auth;

  AdminAuthService(this._auth);

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
  }

  Future<UserCredential> registerWithEmail(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
  }

  Future<UserCredential> signInWithGoogle() async {
    final googleProvider = GoogleAuthProvider();
    return await _auth.signInWithPopup(googleProvider);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
