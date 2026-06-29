import 'package:cloud_firestore/cloud_firestore.dart';

class AnggotaKeluarga {
  final String id;
  final String parentDocId;
  final String nik;
  final String nama;
  final String noKk;
  final String jenisKelamin; // 'Pria' atau 'Wanita'
  final String hubungan;     // 'Istri', 'Anak', 'Orang Tua', 'Lainnya'

  AnggotaKeluarga({
    required this.id,
    required this.parentDocId,
    required this.nik,
    required this.nama,
    required this.noKk,
    required this.jenisKelamin,
    required this.hubungan,
  });

  factory AnggotaKeluarga.fromSnapshot(DocumentSnapshot doc, String parentId) {
    final data = doc.data() as Map<String, dynamic>;
    return AnggotaKeluarga(
      id: doc.id,
      parentDocId: parentId,
      nik: data['nik'] ?? '',
      nama: data['nama'] ?? '',
      noKk: data['no_kk'] ?? '',
      jenisKelamin: data['jenis_kelamin'] ?? 'Pria',
      hubungan: data['hubungan'] ?? 'Lainnya',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nik': nik,
      'nama': nama,
      'no_kk': noKk,
      'jenis_kelamin': jenisKelamin,
      'hubungan': hubungan,
    };
  }

  AnggotaKeluarga copyWith({
    String? id,
    String? parentDocId,
    String? nik,
    String? nama,
    String? noKk,
    String? jenisKelamin,
    String? hubungan,
  }) {
    return AnggotaKeluarga(
      id: id ?? this.id,
      parentDocId: parentDocId ?? this.parentDocId,
      nik: nik ?? this.nik,
      nama: nama ?? this.nama,
      noKk: noKk ?? this.noKk,
      jenisKelamin: jenisKelamin ?? this.jenisKelamin,
      hubungan: hubungan ?? this.hubungan,
    );
  }
}
