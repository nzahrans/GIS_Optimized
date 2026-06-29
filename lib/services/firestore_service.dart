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
        .get();

    for (var doc in queryAnggota.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final docNik = (data['nik'] ?? '').toString().trim();
      if (docNik == nik.trim()) {
        if (excludeDocId == null || doc.id != excludeDocId) {
          return true;
        }
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
}
