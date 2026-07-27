import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _collection = 'warga';

  /// Stream semua data warga secara realtime.
  static Stream<QuerySnapshot> getWargaStream() {
    return _db.collection(_collection).snapshots();
  }

  /// Tambah data warga baru, kembalikan ID dokumen.
  static Future<String> addWarga(Map<String, dynamic> data) async {
    final ref = await _db.collection(_collection).add(data);
    return ref.id;
  }

  /// Update data warga berdasarkan ID dokumen.
  static Future<void> updateWarga(String docId, Map<String, dynamic> data) async {
    await _db.collection(_collection).doc(docId).update(data);
  }

  /// Tambah data riwayat bansos ke subcollection warga.
  static Future<void> addRiwayatBansos(String wargaDocId, Map<String, dynamic> riwayatData) async {
    await _db
        .collection(_collection)
        .doc(wargaDocId)
        .collection('riwayat_bansos')
        .add(riwayatData);
  }

  /// Hapus data warga berdasarkan ID dokumen.
  static Future<void> deleteWarga(String docId) async {
    await _db.collection(_collection).doc(docId).delete();
  }

  /// Cek apakah NIK sudah terdaftar di koleksi utama (KK) maupun subkoleksi (anggota_keluarga).
  /// [excludeDocId] dipakai saat edit agar tidak bentrok dengan dirinya sendiri.
  static Future<bool> isNikExists(String nik, {String? excludeDocId}) async {
    // 1. Cek di koleksi warga (KK)
    final queryKK = await _db
        .collection(_collection)
        .where('nik', isEqualTo: nik.trim())
        .limit(1)
        .get();

    if (queryKK.docs.isNotEmpty) {
      if (excludeDocId == null || queryKK.docs.first.id != excludeDocId) {
        return true;
      }
    }

    // 2. Cek di subkoleksi anggota_keluarga
    final queryAnggota = await _db
        .collectionGroup('anggota_keluarga')
        .where('nik', isEqualTo: nik.trim())
        .limit(1)
        .get();

    if (queryAnggota.docs.isNotEmpty) {
      if (excludeDocId == null || queryAnggota.docs.first.id != excludeDocId) {
        return true;
      }
    }

    return false;
  }

  /// Cek apakah No. KK sudah terdaftar untuk Kepala Keluarga.
  /// [excludeDocId] dipakai saat edit agar tidak bentrok dengan dirinya sendiri.
  static Future<bool> isKkExists(String noKk, {String? excludeDocId}) async {
    final query = await _db
        .collection(_collection)
        .where('no_kk', isEqualTo: noKk.trim())
        .limit(1)
        .get();

    if (query.docs.isEmpty) return false;
    if (excludeDocId != null && query.docs.first.id == excludeDocId) return false;
    return true;
  }

  // === ANGGOTA KELUARGA ===

  /// Stream anggota keluarga untuk satu kepala keluarga
  static Stream<QuerySnapshot> getAnggotaStream(String wargaDocId) {
    return _db
        .collection(_collection)
        .doc(wargaDocId)
        .collection('anggota_keluarga')
        .snapshots();
  }

  /// Ambil semua anggota keluarga (sekali, bukan stream)
  static Future<QuerySnapshot> getAnggotaOnce(String wargaDocId) async {
    return await _db
        .collection(_collection)
        .doc(wargaDocId)
        .collection('anggota_keluarga')
        .get();
  }

  /// Tambah anggota keluarga
  static Future<String> addAnggota(String wargaDocId, Map<String, dynamic> data) async {
    final ref = await _db
        .collection(_collection)
        .doc(wargaDocId)
        .collection('anggota_keluarga')
        .add(data);
    return ref.id;
  }

  /// Update anggota keluarga
  static Future<void> updateAnggota(
      String wargaDocId, String anggotaDocId, Map<String, dynamic> data) async {
    await _db
        .collection(_collection)
        .doc(wargaDocId)
        .collection('anggota_keluarga')
        .doc(anggotaDocId)
        .update(data);
  }

  /// Hapus anggota keluarga
  static Future<void> deleteAnggota(String wargaDocId, String anggotaDocId) async {
    await _db
        .collection(_collection)
        .doc(wargaDocId)
        .collection('anggota_keluarga')
        .doc(anggotaDocId)
        .delete();
  }

  /// Stream seluruh anggota keluarga secara global (Collection Group)
  static Stream<QuerySnapshot> getAllAnggotaStream() {
    return _db.collectionGroup('anggota_keluarga').snapshots();
  }

  // === BANTUAN AKTIF (V2 MULTI-BANTUAN) ===

  /// Stream bantuan aktif untuk satu warga
  static Stream<QuerySnapshot> getBantuanAktifStream(String wargaDocId) {
    return _db
        .collection(_collection)
        .doc(wargaDocId)
        .collection('bantuan_aktif')
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  /// Ambil bantuan aktif sekali (bukan stream)
  static Future<QuerySnapshot> getBantuanAktifOnce(String wargaDocId) async {
    return await _db
        .collection(_collection)
        .doc(wargaDocId)
        .collection('bantuan_aktif')
        .get();
  }

  /// Tambah bantuan aktif
  static Future<String> addBantuanAktif(String wargaDocId, Map<String, dynamic> data) async {
    final ref = await _db
        .collection(_collection)
        .doc(wargaDocId)
        .collection('bantuan_aktif')
        .add(data);
    return ref.id;
  }

  /// Update bantuan aktif
  static Future<void> updateBantuanAktif(
      String wargaDocId, String bantuanDocId, Map<String, dynamic> data) async {
    await _db
        .collection(_collection)
        .doc(wargaDocId)
        .collection('bantuan_aktif')
        .doc(bantuanDocId)
        .update(data);
  }

  /// Hapus bantuan aktif
  static Future<void> deleteBantuanAktif(String wargaDocId, String bantuanDocId) async {
    await _db
        .collection(_collection)
        .doc(wargaDocId)
        .collection('bantuan_aktif')
        .doc(bantuanDocId)
        .delete();
  }

  /// Stream seluruh bantuan aktif secara global (Collection Group)
  static Stream<QuerySnapshot> getAllBantuanAktifStream() {
    return _db.collectionGroup('bantuan_aktif').snapshots();
  }

  /// Migrasi Data V1 ke V2
  static Future<int> runDataMigration() async {
    int migratedCount = 0;
    try {
      final snapshot = await _db.collection(_collection).get();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        // Cek apakah data model versi 1 memiliki bantuan tunggal
        final String? jenisBantuanLama = data['jenis_bantuan'] as String?;
        final String? statusCairLama = data['status_cair'] as String?;
        final dynamic tglDiterimaLama = data['tanggal_diterima'];
        final String menerimaBantuan = data['menerima_bantuan'] ?? 'Tidak';

        if (menerimaBantuan == 'Ya' && jenisBantuanLama != null && jenisBantuanLama != '-') {
          // Cek apakah subkoleksi bantuan_aktif sudah ada datanya
          final subcollection = await doc.reference.collection('bantuan_aktif').get();
          if (subcollection.docs.isEmpty) {
            // Migrasi ke bantuan_aktif subkoleksi
            final Map<String, dynamic> newBantuan = {
              'jenis_bantuan': jenisBantuanLama,
              'status_cair': statusCairLama ?? 'Belum Menerima',
              'tanggal_pencairan': tglDiterimaLama,
              'dikonfirmasi_warga': statusCairLama == 'Dikonfirmasi Warga',
              'tanggal_konfirmasi': statusCairLama == 'Dikonfirmasi Warga' ? tglDiterimaLama : null,
              'catatan_warga': null,
              'created_at': FieldValue.serverTimestamp(),
            };
            await doc.reference.collection('bantuan_aktif').add(newBantuan);
            
            // Hapus field V1 dari dokumen utama (gunakan FieldValue.delete())
            await doc.reference.update({
              'jenis_bantuan': FieldValue.delete(),
              'status_cair': statusCairLama ?? 'Belum Menerima', // Simpan status_cair di dokumen utama sebagai cache marker
              'tanggal_diterima': FieldValue.delete(),
            });
            migratedCount++;
          }
        }
      }
    } catch (e) {
      // ignore
    }
    return migratedCount;
  }
}
