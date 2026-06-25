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

  /// Hapus data warga berdasarkan ID dokumen.
  static Future<void> deleteWarga(String docId) async {
    await _db.collection(_collection).doc(docId).delete();
  }

  /// Cek apakah NIK sudah terdaftar.
  /// [excludeDocId] dipakai saat edit agar tidak bentrok dengan dirinya sendiri.
  static Future<bool> isNikExists(String nik, {String? excludeDocId}) async {
    final query = await _db
        .collection(_collection)
        .where('nik', isEqualTo: nik.trim())
        .limit(1)
        .get();

    if (query.docs.isEmpty) return false;
    if (excludeDocId != null && query.docs.first.id == excludeDocId) return false;
    return true;
  }

  /// Cek apakah No. KK sudah terdaftar.
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
}
