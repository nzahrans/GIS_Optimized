import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  String? _errorMessage;
  String? _role;

  AuthProvider() {
    // Listen to changes in authentication state
    AuthService.authStateChanges.listen((User? user) async {
      _user = user;
      if (user != null) {
        _role = await _fetchOrCreateUserRole(user);
      } else {
        _role = null;
      }
      notifyListeners();
    });
  }

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _user != null;
  String? get role => _role;

  /// Memastikan data role sudah termuat (dipakai saat startup/splash screen)
  Future<void> ensureRoleLoaded() async {
    if (_user != null && _role == null) {
      _role = await _fetchOrCreateUserRole(_user!);
      notifyListeners();
    }
  }

  /// Fungsi internal untuk mengambil atau membuat dokumen user role di Firestore
  Future<String> _fetchOrCreateUserRole(User user) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['role'] != null) {
          return data['role'] as String;
        }
      }

      // Jika dokumen tidak ditemukan, buat fallback role berdasarkan email
      final email = user.email ?? '';
      String role = 'user';
      if (email.endsWith('@warga.sigbansos.com')) {
        role = 'user';
      } else if (email.toLowerCase().contains('admin')) {
        role = 'admin';
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'email': email,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return role;
    } catch (e) {
      debugPrint('Error fetch/create user role: $e');
      // Fallback logika hardcode jika Firestore bermasalah
      final email = user.email ?? '';
      if (email.endsWith('@warga.sigbansos.com')) {
        return 'user';
      } else if (email.toLowerCase().contains('admin')) {
        return 'admin';
      }
      return 'user';
    }
  }

  /// Sign in with email and password
  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final userCredential = await AuthService.signIn(email, password);
      final user = userCredential.user;
      if (user != null) {
        _role = await _fetchOrCreateUserRole(user);
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      _errorMessage = e.message ?? 'Terjadi kesalahan autentikasi';
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Terjadi kesalahan tidak dikenal';
      notifyListeners();
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();
    await AuthService.signOut();
    _role = null;
    _isLoading = false;
    notifyListeners();
  }
}
