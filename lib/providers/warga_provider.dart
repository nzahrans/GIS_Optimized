import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/warga.dart';
import '../models/anggota_keluarga.dart';
import '../services/firestore_service.dart';

class WargaProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Upload foto rumah ke Firebase Storage
  Future<String?> uploadFotoRumah(File file, String nik) async {
    try {
      final String namaFile = 'foto_${nik}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference ref = FirebaseStorage.instance.ref().child('foto_rumah').child(namaFile);
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('WargaProvider Upload Error: $e');
      rethrow;
    }
  }

  /// Cek duplikasi NIK dan KK
  Future<bool> checkDuplikasi(String nik, String noKk, {String? excludeDocId}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final bool nikExists = await FirestoreService.isNikExists(nik, excludeDocId: excludeDocId);
      if (nikExists) {
        _isLoading = false;
        _errorMessage = 'NIK sudah terdaftar!';
        notifyListeners();
        return false;
      }

      final bool kkExists = await FirestoreService.isKkExists(noKk, excludeDocId: excludeDocId);
      if (kkExists) {
        _isLoading = false;
        _errorMessage = 'Nomor KK sudah terdaftar!';
        notifyListeners();
        return false;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Gagal memvalidasi NIK/KK: $e';
      notifyListeners();
      return false;
    }
  }

  /// Tambah data warga baru dan buat akun Firebase Auth secara otomatis
  Future<bool> addWarga(Warga warga, File? fotoFile) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Pendaftaran akun warga secara otomatis via Secondary App
      final String virtualEmail = '${warga.nik.trim()}@warga.sigbansos.com';
      final String virtualPassword = '123456';

      FirebaseApp? tempApp;
      try {
        tempApp = await Firebase.initializeApp(
          name: 'TempWargaAuthApp',
          options: Firebase.app().options,
        );
        final FirebaseAuth tempAuth = FirebaseAuth.instanceFor(app: tempApp);
        await tempAuth.createUserWithEmailAndPassword(
          email: virtualEmail,
          password: virtualPassword,
        );
      } on FirebaseAuthException catch (authError) {
        if (authError.code != 'email-already-in-use') {
          rethrow;
        }
      } catch (authError) {
        debugPrint('Autocreate Warga Auth Warning: $authError');
      } finally {
        if (tempApp != null) {
          await tempApp.delete();
        }
      }

      // 2. Upload Foto Rumah ke Firebase Storage
      String fotoUrl = warga.fotoUrl;
      if (fotoFile != null) {
        final uploadedUrl = await uploadFotoRumah(fotoFile, warga.nik);
        if (uploadedUrl != null) {
          fotoUrl = uploadedUrl;
        }
      }

      // 3. Simpan data warga ke Firestore
      final data = warga.copyWith(fotoUrl: fotoUrl).toMap();
      data['tanggal_input'] = FieldValue.serverTimestamp();

      final String docId = await FirestoreService.addWarga(data);

      // Jika statusnya langsung "Sudah Menerima", catat ke riwayat_bansos subcollection
      if (warga.statusBansos == 'Sudah Menerima') {
        await FirestoreService.addRiwayatBansos(docId, {
          'jenis_bantuan': warga.jenisBantuan,
          'status_cair': warga.statusBansos,
          'tanggal_diterima': FieldValue.serverTimestamp(),
        });
      }
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Gagal menyimpan data warga: $e';
      notifyListeners();
      return false;
    }
  }

  /// Update data warga
  Future<bool> updateWarga(
    String docId,
    Warga warga,
    File? fotoFile, {
    bool shouldAddHistory = false,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Pendaftaran akun warga secara otomatis via Secondary App jika belum ada
      final String virtualEmail = '${warga.nik.trim()}@warga.sigbansos.com';
      final String virtualPassword = '123456';

      FirebaseApp? tempApp;
      try {
        tempApp = await Firebase.initializeApp(
          name: 'TempWargaAuthAppUpdate',
          options: Firebase.app().options,
        );
        final FirebaseAuth tempAuth = FirebaseAuth.instanceFor(app: tempApp);
        await tempAuth.createUserWithEmailAndPassword(
          email: virtualEmail,
          password: virtualPassword,
        );
      } on FirebaseAuthException catch (authError) {
        if (authError.code != 'email-already-in-use') {
          rethrow;
        }
      } catch (authError) {
        debugPrint('Autocreate Warga Auth Warning (Update): $authError');
      } finally {
        if (tempApp != null) {
          await tempApp.delete();
        }
      }

      // Upload Foto Rumah ke Firebase Storage
      String fotoUrl = warga.fotoUrl;
      if (fotoFile != null) {
        final uploadedUrl = await uploadFotoRumah(fotoFile, warga.nik);
        if (uploadedUrl != null) {
          fotoUrl = uploadedUrl;
        }
      }

      final data = warga.copyWith(fotoUrl: fotoUrl).toMap();
      await FirestoreService.updateWarga(docId, data);

      if (shouldAddHistory) {
        await FirestoreService.addRiwayatBansos(docId, {
          'jenis_bantuan': warga.jenisBantuan,
          'status_cair': warga.statusBansos,
          'tanggal_diterima': FieldValue.serverTimestamp(),
        });
      }
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Gagal memperbarui data warga: $e';
      notifyListeners();
      return false;
    }
  }

  /// Hapus data warga beserta semua anggota keluarganya
  Future<bool> deleteWarga(String docId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Ambil semua anggota keluarga terlebih dahulu dan hapus
      final anggotaSnapshot = await FirestoreService.getAnggotaOnce(docId);
      for (var doc in anggotaSnapshot.docs) {
        await FirestoreService.deleteAnggota(docId, doc.id);
      }

      // 2. Hapus dokumen warga utama
      await FirestoreService.deleteWarga(docId);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Gagal menghapus data warga: $e';
      notifyListeners();
      return false;
    }
  }

  /// Tambah data anggota keluarga
  Future<bool> addAnggota(String wargaDocId, AnggotaKeluarga anggota) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await FirestoreService.addAnggota(wargaDocId, anggota.toMap());
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Gagal menambahkan anggota keluarga: $e';
      notifyListeners();
      return false;
    }
  }

  /// Update data anggota keluarga
  Future<bool> updateAnggota(String wargaDocId, String anggotaDocId, AnggotaKeluarga anggota) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await FirestoreService.updateAnggota(wargaDocId, anggotaDocId, anggota.toMap());
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Gagal memperbarui data anggota keluarga: $e';
      notifyListeners();
      return false;
    }
  }

  /// Hapus data anggota keluarga
  Future<bool> deleteAnggota(String wargaDocId, String anggotaDocId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await FirestoreService.deleteAnggota(wargaDocId, anggotaDocId);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Gagal menghapus data anggota keluarga: $e';
      notifyListeners();
      return false;
    }
  }
}
