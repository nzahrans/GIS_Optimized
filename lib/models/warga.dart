import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class Warga {
  final String id;
  final String nama;
  final String nik;
  final String noKk;
  final String blok;
  final LatLng koordinat;
  final String menerimaBantuan; // "Ya" atau "Tidak"
  final String fotoUrl;

  Warga({
    required this.id,
    required this.nama,
    required this.nik,
    required this.noKk,
    this.blok = '',
    required this.koordinat,
    this.menerimaBantuan = 'Tidak',
    this.fotoUrl = '',
  });

  /// Buat Warga dari dokumen Firestore.
  factory Warga.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final GeoPoint geoPoint = data['lokasi'] as GeoPoint;
    return Warga(
      id: doc.id,
      nama: data['nama'] ?? '',
      nik: data['nik'] ?? '',
      noKk: data['no_kk'] ?? '',
      blok: data['blok'] ?? '',
      koordinat: LatLng(geoPoint.latitude, geoPoint.longitude),
      menerimaBantuan: data['menerima_bantuan'] ?? 'Tidak',
      fotoUrl: data['foto_url'] ?? '',
    );
  }

  /// Konversi ke Map untuk disimpan ke Firestore.
  Map<String, dynamic> toMap() {
    return {
      'nama': nama,
      'nik': nik,
      'no_kk': noKk,
      'blok': blok,
      'lokasi': GeoPoint(koordinat.latitude, koordinat.longitude),
      'menerima_bantuan': menerimaBantuan,
      'foto_url': fotoUrl,
    };
  }

  /// Salin Warga dengan nilai yang diubah.
  Warga copyWith({
    String? id,
    String? nama,
    String? nik,
    String? noKk,
    String? blok,
    LatLng? koordinat,
    String? menerimaBantuan,
    String? fotoUrl,
  }) {
    return Warga(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      nik: nik ?? this.nik,
      noKk: noKk ?? this.noKk,
      blok: blok ?? this.blok,
      koordinat: koordinat ?? this.koordinat,
      menerimaBantuan: menerimaBantuan ?? this.menerimaBantuan,
      fotoUrl: fotoUrl ?? this.fotoUrl,
    );
  }
}
