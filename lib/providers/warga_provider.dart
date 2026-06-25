import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import '../models/warga.dart';
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

  /// Tambah data warga baru
  Future<bool> addWarga(Warga warga, File? fotoFile) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      String fotoUrl = warga.fotoUrl;
      if (fotoFile != null) {
        final uploadedUrl = await uploadFotoRumah(fotoFile, warga.nik);
        if (uploadedUrl != null) {
          fotoUrl = uploadedUrl;
        }
      }

      final data = warga.copyWith(fotoUrl: fotoUrl).toMap();
      data['tanggal_input'] = FieldValue.serverTimestamp();

      await FirestoreService.addWarga(data);
      
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
  Future<bool> updateWarga(String docId, Warga warga, File? fotoFile) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      String fotoUrl = warga.fotoUrl;
      if (fotoFile != null) {
        final uploadedUrl = await uploadFotoRumah(fotoFile, warga.nik);
        if (uploadedUrl != null) {
          fotoUrl = uploadedUrl;
        }
      }

      final data = warga.copyWith(fotoUrl: fotoUrl).toMap();
      await FirestoreService.updateWarga(docId, data);
      
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

  /// Hapus data warga
  Future<bool> deleteWarga(String docId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
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
}
