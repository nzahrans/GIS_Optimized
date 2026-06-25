import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static User? get currentUser => _auth.currentUser;

  static bool get isLoggedIn => _auth.currentUser != null;

  /// Login dengan email dan password.
  /// Lempar [FirebaseAuthException] jika gagal.
  static Future<UserCredential> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Logout dari sesi aktif.
  static Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Stream perubahan status autentikasi.
  static Stream<User?> get authStateChanges => _auth.authStateChanges();
}
