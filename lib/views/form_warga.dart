import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pick_map.dart';
import '../models/warga.dart';
import '../providers/warga_provider.dart';

class FormWargaPage extends StatefulWidget {
  /// Jika [docId] tidak null, halaman berjalan dalam mode edit.
  final String? docId;
  final Map<String, dynamic>? existingData;

  const FormWargaPage({super.key, this.docId, this.existingData});

  @override
  State<FormWargaPage> createState() => _FormWargaPageState();
}

class _FormWargaPageState extends State<FormWargaPage> {
  // --- CONTROLLERS ---
  final _kkController = TextEditingController();
  final _nikController = TextEditingController();
  final _namaController = TextEditingController();
  final _blokController = TextEditingController();
  final _koordinatController = TextEditingController();
  final _jenisBantuanController = TextEditingController();

  // --- STATE VARIABLES ---
  String _apakahMenerimaBantuan = 'Tidak';
  String _statusPenerimaanSaatIni = 'Belum Menerima';
  LatLng? _lokasiTerpilih;
  File? _fotoRumah;
  String? _existingFotoUrl; // URL foto lama saat edit

  bool get _isEditMode => widget.docId != null;

  @override
  void initState() {
    super.initState();
    // Pre-fill form saat mode edit
    if (_isEditMode && widget.existingData != null) {
      final d = widget.existingData!;
      _kkController.text = d['no_kk'] ?? '';
      _nikController.text = d['nik'] ?? '';
      _namaController.text = d['nama'] ?? '';
      _blokController.text = d['blok'] ?? '';
      _apakahMenerimaBantuan = d['menerima_bantuan'] ?? 'Tidak';
      _jenisBantuanController.text = d['jenis_bantuan'] ?? '';
      _statusPenerimaanSaatIni = d['status_cair'] ?? 'Belum Menerima';
      _existingFotoUrl = d['foto_url'];
      if (d['lokasi'] != null) {
        final GeoPoint gp = d['lokasi'];
        _lokasiTerpilih = LatLng(gp.latitude, gp.longitude);
        _koordinatController.text = '${gp.latitude}, ${gp.longitude}';
      }
    }
  }

  @override
  void dispose() {
    _kkController.dispose();
    _nikController.dispose();
    _namaController.dispose();
    _blokController.dispose();
    _koordinatController.dispose();
    _jenisBantuanController.dispose();
    super.dispose();
  }

  // --- FUNGSI GPS ---
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aktifkan GPS pada HP Anda!')));
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Izin lokasi ditolak')));
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Izin lokasi ditolak permanen. Buka pengaturan.')));
      return;
    }

    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sedang mencari titik koordinat...")));

    Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    setState(() {
      _lokasiTerpilih = LatLng(position.latitude, position.longitude);
      _koordinatController.text = "${position.latitude}, ${position.longitude}";
    });

    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lokasi GPS berhasil ditemukan!")));
  }

  // --- FUNGSI AMBIL FOTO ---
  Future<void> _ambilFoto(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: source, imageQuality: 50); // Kompres 50%

    if (photo != null) {
      setState(() {
        _fotoRumah = File(photo.path);
      });
    }
  }

  void _showImageSourceOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.blue),
                title: const Text('Ambil Foto (Kamera)'),
                onTap: () { Navigator.pop(context); _ambilFoto(ImageSource.camera); },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.green),
                title: const Text('Pilih dari Galeri'),
                onTap: () { Navigator.pop(context); _ambilFoto(ImageSource.gallery); },
              ),
            ],
          ),
        );
      },
    );
  }

  // --- VALIDASI NIK/KK ---
  bool _isValid16Digit(String value) {
    final trimmed = value.trim();
    return trimmed.length == 16 && RegExp(r'^\d+$').hasMatch(trimmed);
  }

  // --- LOGIKA SIMPAN KE FIREBASE (CORE via WargaProvider) ---
  Future<void> _simpanDataKeFirebase() async {
    // 1. Validasi Kelengkapan
    if (_kkController.text.trim().isEmpty ||
        _nikController.text.trim().isEmpty ||
        _namaController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Harap lengkapi data Identitas!")));
      return;
    }

    // 2. Validasi Format NIK & No. KK
    if (!_isValid16Digit(_nikController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("NIK harus tepat 16 digit angka!")));
      return;
    }
    if (!_isValid16Digit(_kkController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No. KK harus tepat 16 digit angka!")));
      return;
    }

    if (_lokasiTerpilih == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Harap tentukan lokasi rumah!")));
      return;
    }
    if (_apakahMenerimaBantuan == 'Ya' && _jenisBantuanController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Harap isi Jenis Bantuan!")));
      return;
    }

    final wargaProvider = context.read<WargaProvider>();

    // 3. Validasi duplikasi NIK dan KK melalui provider
    final valid = await wargaProvider.checkDuplikasi(
      _nikController.text,
      _kkController.text,
      excludeDocId: widget.docId,
    );

    if (!valid) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(wargaProvider.errorMessage ?? "Duplikasi data terdeteksi")),
        );
      }
      return;
    }

    // 4. Instansiasi objek Warga
    final warga = Warga(
      id: widget.docId ?? '',
      nama: _namaController.text.trim(),
      nik: _nikController.text.trim(),
      noKk: _kkController.text.trim(),
      blok: _blokController.text.trim(),
      koordinat: _lokasiTerpilih!,
      menerimaBantuan: _apakahMenerimaBantuan,
      jenisBantuan: _apakahMenerimaBantuan == 'Ya' ? _jenisBantuanController.text.trim() : '-',
      statusBansos: _apakahMenerimaBantuan == 'Ya' ? _statusPenerimaanSaatIni : '-',
      fotoUrl: _existingFotoUrl ?? '',
    );

    // 5. Eksekusi tambah atau update data
    bool success;
    if (_isEditMode) {
      success = await wargaProvider.updateWarga(widget.docId!, warga, _fotoRumah);
    } else {
      success = await wargaProvider.addWarga(warga, _fotoRumah);
    }

    if (mounted) {
      if (success) {
        final msg = _isEditMode ? "Data berhasil diperbarui!" : "Alhamdulillah! Data Berhasil Disimpan.";
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(wargaProvider.errorMessage ?? "Gagal menyimpan data")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final wargaProvider = context.watch<WargaProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _isEditMode ? "Edit Data Warga" : "Tambah Warga Baru",
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("1. INFORMASI KEPALA KELUARGA"),
            const SizedBox(height: 16),
            _buildInputBox(controller: _kkController, hint: "Masukkan No. KK (16 Digit) *", keyboardType: TextInputType.number),
            _buildInputBox(controller: _nikController, hint: "Masukkan NIK Kepala Keluarga *", keyboardType: TextInputType.number),
            _buildInputBox(controller: _namaController, hint: "Masukkan Nama Lengkap *"),
            _buildInputBox(controller: _blokController, hint: "Masukkan Blok/Gang (opsional)"),
            const SizedBox(height: 24),

            _buildSectionTitle("2. LOKASI RUMAH"),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () async {
                final LatLng? result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PickMapPage(initialCenter: _lokasiTerpilih)),
                );
                if (result != null) {
                  setState(() {
                    _lokasiTerpilih = result;
                    _koordinatController.text = "${result.latitude}, ${result.longitude}";
                  });
                }
              },
              child: Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _lokasiTerpilih != null ? theme.colorScheme.primary : const Color(0xFFCBD5E1),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _lokasiTerpilih == null ? Icons.map_outlined : Icons.add_location_alt_rounded,
                      size: 44,
                      color: _lokasiTerpilih != null ? theme.colorScheme.primary : const Color(0xFF64748B),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _lokasiTerpilih == null ? "Ketuk untuk Menyesuaikan Titik di Peta" : "Lokasi Rumah Berhasil Ditentukan!",
                      style: TextStyle(
                        color: _lokasiTerpilih != null ? theme.colorScheme.primary : const Color(0xFF64748B),
                        fontWeight: _lokasiTerpilih != null ? FontWeight.w600 : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _koordinatController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: "Koordinat Rumah",
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 54,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                      foregroundColor: theme.colorScheme.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: wargaProvider.isLoading ? null : () => _getCurrentLocation(),
                    icon: const Icon(Icons.gps_fixed, size: 18),
                    label: const Text("GPS", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            _buildSectionTitle("3. FOTO RUMAH"),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _showImageSourceOptions,
              child: Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _fotoRumah != null ? theme.colorScheme.secondary : const Color(0xFFCBD5E1),
                    width: 1.5,
                  ),
                  image: _fotoRumah != null ? DecorationImage(image: FileImage(_fotoRumah!), fit: BoxFit.cover) : null,
                ),
                child: _fotoRumah == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt_outlined, size: 44, color: Color(0xFF64748B)),
                          const SizedBox(height: 8),
                          Text(
                            "Ketuk untuk Mengambil Foto Rumah",
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                          ),
                        ],
                      )
                    : null,
              ),
            ),
            if (_fotoRumah != null)
              Center(
                child: TextButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text("Ganti Foto Rumah"),
                  onPressed: _showImageSourceOptions,
                ),
              ),
            const SizedBox(height: 24),

            _buildSectionTitle("4. STATUS BANTUAN SOSIAL"),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _apakahMenerimaBantuan,
              decoration: const InputDecoration(
                labelText: "Apakah Keluarga Ini Menerima Bantuan?",
              ),
              items: ['Ya', 'Tidak']
                  .map((value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      ))
                  .toList(),
              onChanged: (newValue) {
                setState(() {
                  _apakahMenerimaBantuan = newValue!;
                });
              },
            ),
            if (_apakahMenerimaBantuan == 'Ya') ...[
              const SizedBox(height: 16),
              _buildInputBox(controller: _jenisBantuanController, hint: "Jenis Bantuan (Contoh: PKH, BPNT)"),
              const SizedBox(height: 16),
              Card(
                color: const Color(0xFFF8FAFC),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Status Penerimaan Saat Ini :",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 8),
                      RadioListTile<String>(
                        title: const Text("Belum Menerima / Belum Cair"),
                        value: 'Belum Menerima',
                        groupValue: _statusPenerimaanSaatIni,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        activeColor: theme.colorScheme.primary,
                        onChanged: (value) => setState(() => _statusPenerimaanSaatIni = value!),
                      ),
                      RadioListTile<String>(
                        title: const Text("Sudah Menerima / Sudah Cair"),
                        value: 'Sudah Menerima',
                        groupValue: _statusPenerimaanSaatIni,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        activeColor: theme.colorScheme.primary,
                        onChanged: (value) => setState(() => _statusPenerimaanSaatIni = value!),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 36),

            // TOMBOL SIMPAN (DENGAN LOADING PROVIDER)
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                onPressed: wargaProvider.isLoading ? null : _simpanDataKeFirebase,
                child: wargaProvider.isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        _isEditMode ? "Simpan Perubahan" : "Simpan Data Warga",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: Color(0xFF1E293B),
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _buildInputBox({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: hint,
        ),
      ),
    );
  }
}
