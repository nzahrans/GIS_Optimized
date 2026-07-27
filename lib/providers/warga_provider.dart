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
  Future<bool> addWarga(Warga warga, File? fotoFile, {List<Map<String, dynamic>>? initialBantuan}) async {
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
        final UserCredential cred = await tempAuth.createUserWithEmailAndPassword(
          email: virtualEmail,
          password: virtualPassword,
        );
        if (cred.user != null) {
          await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
            'email': virtualEmail,
            'role': 'user',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
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

      // Simpan initialBantuan jika ada
      if (initialBantuan != null) {
        for (var b in initialBantuan) {
          b['created_at'] = FieldValue.serverTimestamp();
          await FirestoreService.addBantuanAktif(docId, b);
          
          if (b['status_cair'] == 'Sudah Menerima') {
            await FirestoreService.addRiwayatBansos(docId, {
              'jenis_bantuan': b['jenis_bantuan'],
              'status_cair': b['status_cair'],
              'tanggal_diterima': FieldValue.serverTimestamp(),
              'dikonfirmasi_warga': false,
              'tanggal_konfirmasi': null,
              'diubah_oleh': 'admin',
            });
          }
        }
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
    File? fotoFile,
  ) async {
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
        final UserCredential cred = await tempAuth.createUserWithEmailAndPassword(
          email: virtualEmail,
          password: virtualPassword,
        );
        if (cred.user != null) {
          await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
            'email': virtualEmail,
            'role': 'user',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
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

  /// Hapus data warga beserta semua anggota keluarganya dan bantuan aktifnya
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

      // 2. Ambil semua bantuan aktif dan hapus
      final bantuanSnapshot = await FirestoreService.getBantuanAktifOnce(docId);
      for (var doc in bantuanSnapshot.docs) {
        await FirestoreService.deleteBantuanAktif(docId, doc.id);
      }

      // 3. Hapus dokumen warga utama
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

  // === OPERATIONS BANTUAN AKTIF ===

  /// Sinkronisasi status bantuan warga ke dokumen utama
  Future<void> _syncWargaBantuanStatus(String wargaDocId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('warga')
          .doc(wargaDocId)
          .collection('bantuan_aktif')
          .get();

      if (snapshot.docs.isEmpty) {
        await FirebaseFirestore.instance.collection('warga').doc(wargaDocId).update({
          'menerima_bantuan': 'Tidak',
          'status_cair': 'Belum Menerima',
        });
        return;
      }

      final docs = snapshot.docs;
      final statuses = docs.map((doc) => doc.data()['status_cair'] as String? ?? 'Belum Menerima').toList();

      String aggregateStatus = 'Belum Menerima';
      if (statuses.contains('Sudah Menerima')) {
        // Ada yang sudah cair tapi belum dikonfirmasi warga
        aggregateStatus = 'Sudah Menerima';
      } else if (statuses.contains('Dikonfirmasi Warga')) {
        // Ada yang sudah dikonfirmasi warga, dan tidak ada yang hanya "Sudah Menerima" (semua yang cair sudah dikonfirmasi)
        aggregateStatus = 'Dikonfirmasi Warga';
      } else {
        // Semua "Belum Menerima"
        aggregateStatus = 'Belum Menerima';
      }

      await FirebaseFirestore.instance.collection('warga').doc(wargaDocId).update({
        'menerima_bantuan': 'Ya',
        'status_cair': aggregateStatus,
      });
    } catch (e) {
      debugPrint('Error syncing warga bantuan status: $e');
    }
  }

  /// Tambah bantuan aktif untuk warga
  Future<bool> addBantuan(String wargaDocId, String jenisBantuan, String statusCair) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = {
        'jenis_bantuan': jenisBantuan,
        'status_cair': statusCair,
        'tanggal_pencairan': statusCair == 'Sudah Menerima' ? FieldValue.serverTimestamp() : null,
        'dikonfirmasi_warga': false,
        'tanggal_konfirmasi': null,
        'catatan_warga': null,
        'created_at': FieldValue.serverTimestamp(),
      };
      await FirestoreService.addBantuanAktif(wargaDocId, data);

      if (statusCair == 'Sudah Menerima') {
        await FirestoreService.addRiwayatBansos(wargaDocId, {
          'jenis_bantuan': jenisBantuan,
          'status_cair': statusCair,
          'tanggal_diterima': FieldValue.serverTimestamp(),
          'dikonfirmasi_warga': false,
          'tanggal_konfirmasi': null,
          'diubah_oleh': 'admin',
        });
      }

      // Sinkronisasi status gabungan ke dokumen warga utama
      await _syncWargaBantuanStatus(wargaDocId);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Gagal menambahkan bantuan: $e';
      notifyListeners();
      return false;
    }
  }

  /// Update status bantuan aktif (Cairkan oleh admin, atau update lainnya)
  Future<bool> updateBantuanStatus(
    String wargaDocId,
    String bantuanDocId,
    String statusCair, {
    bool dikonfirmasi = false,
    String? catatanWarga,
    String diubahOleh = 'admin',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updates = <String, dynamic>{
        'status_cair': statusCair,
      };

      if (statusCair == 'Sudah Menerima') {
        updates['tanggal_pencairan'] = FieldValue.serverTimestamp();
      } else if (statusCair == 'Dikonfirmasi Warga') {
        updates['dikonfirmasi_warga'] = true;
        updates['tanggal_konfirmasi'] = FieldValue.serverTimestamp();
        updates['catatan_warga'] = catatanWarga;
      }

      await FirestoreService.updateBantuanAktif(wargaDocId, bantuanDocId, updates);

      // Ambil detail bantuan aktif untuk riwayat
      final docBantuan = await FirebaseFirestore.instance
          .collection('warga')
          .doc(wargaDocId)
          .collection('bantuan_aktif')
          .doc(bantuanDocId)
          .get();
      
      final String jenisBantuan = docBantuan.data()?['jenis_bantuan'] ?? 'Bansos';

      // Catat ke riwayat
      await FirestoreService.addRiwayatBansos(wargaDocId, {
        'jenis_bantuan': jenisBantuan,
        'status_cair': statusCair,
        'tanggal_diterima': FieldValue.serverTimestamp(),
        'dikonfirmasi_warga': statusCair == 'Dikonfirmasi Warga' || dikonfirmasi,
        'tanggal_konfirmasi': statusCair == 'Dikonfirmasi Warga' ? FieldValue.serverTimestamp() : null,
        'diubah_oleh': diubahOleh,
      });

      // Sinkronisasi status gabungan ke dokumen warga utama
      await _syncWargaBantuanStatus(wargaDocId);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Gagal mengupdate status bantuan: $e';
      notifyListeners();
      return false;
    }
  }

  /// Hapus bantuan aktif
  Future<bool> deleteBantuan(String wargaDocId, String bantuanDocId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await FirestoreService.deleteBantuanAktif(wargaDocId, bantuanDocId);

      // Sinkronisasi status gabungan ke dokumen warga utama
      await _syncWargaBantuanStatus(wargaDocId);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Gagal menghapus bantuan: $e';
      notifyListeners();
      return false;
    }
  }

  /// Konfirmasi bantuan oleh warga sendiri
  Future<bool> konfirmasiBantuan(String wargaDocId, String bantuanDocId, String? catatan) async {
    return await updateBantuanStatus(
      wargaDocId,
      bantuanDocId,
      'Dikonfirmasi Warga',
      dikonfirmasi: true,
      catatanWarga: catatan,
      diubahOleh: 'warga',
    );
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
