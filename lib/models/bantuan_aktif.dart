import 'package:cloud_firestore/cloud_firestore.dart';

class BantuanAktif {
  final String id;
  final String jenisBantuan;
  final String statusCair; // "Belum Menerima" | "Sudah Menerima" | "Dikonfirmasi Warga"
  final DateTime? tanggalPencairan;
  final bool dikonfirmasiWarga;
  final DateTime? tanggalKonfirmasi;
  final String? catatanWarga;
  final DateTime createdAt;

  BantuanAktif({
    required this.id,
    required this.jenisBantuan,
    this.statusCair = 'Belum Menerima',
    this.tanggalPencairan,
    this.dikonfirmasiWarga = false,
    this.tanggalKonfirmasi,
    this.catatanWarga,
    required this.createdAt,
  });

  factory BantuanAktif.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BantuanAktif(
      id: doc.id,
      jenisBantuan: data['jenis_bantuan'] ?? '',
      statusCair: data['status_cair'] ?? 'Belum Menerima',
      tanggalPencairan: data['tanggal_pencairan'] != null
          ? (data['tanggal_pencairan'] as Timestamp).toDate()
          : null,
      dikonfirmasiWarga: data['dikonfirmasi_warga'] ?? false,
      tanggalKonfirmasi: data['tanggal_konfirmasi'] != null
          ? (data['tanggal_konfirmasi'] as Timestamp).toDate()
          : null,
      catatanWarga: data['catatan_warga'],
      createdAt: data['created_at'] != null
          ? (data['created_at'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'jenis_bantuan': jenisBantuan,
      'status_cair': statusCair,
      'tanggal_pencairan': tanggalPencairan != null ? Timestamp.fromDate(tanggalPencairan!) : null,
      'dikonfirmasi_warga': dikonfirmasiWarga,
      'tanggal_konfirmasi': tanggalKonfirmasi != null ? Timestamp.fromDate(tanggalKonfirmasi!) : null,
      'catatan_warga': catatanWarga,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }

  BantuanAktif copyWith({
    String? id,
    String? jenisBantuan,
    String? statusCair,
    DateTime? tanggalPencairan,
    bool? dikonfirmasiWarga,
    DateTime? tanggalKonfirmasi,
    String? catatanWarga,
    DateTime? createdAt,
  }) {
    return BantuanAktif(
      id: id ?? this.id,
      jenisBantuan: jenisBantuan ?? this.jenisBantuan,
      statusCair: statusCair ?? this.statusCair,
      tanggalPencairan: tanggalPencairan ?? this.tanggalPencairan,
      dikonfirmasiWarga: dikonfirmasiWarga ?? this.dikonfirmasiWarga,
      tanggalKonfirmasi: tanggalKonfirmasi ?? this.tanggalKonfirmasi,
      catatanWarga: catatanWarga ?? this.catatanWarga,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
