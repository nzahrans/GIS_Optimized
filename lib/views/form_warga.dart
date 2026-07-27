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
import '../widgets/custom_alert_dialog.dart';

class FormWargaPage extends StatefulWidget {
  final String? docId;
  final Map<String, dynamic>? existingData;

  const FormWargaPage({super.key, this.docId, this.existingData});

  @override
  State<FormWargaPage> createState() => _FormWargaPageState();
}

class _FormWargaPageState extends State<FormWargaPage> {
  final _kkController = TextEditingController();
  final _nikController = TextEditingController();
  final _namaController = TextEditingController();
  final _blokController = TextEditingController();
  final _koordinatController = TextEditingController();
  final _jenisBantuanController = TextEditingController();

  String _apakahMenerimaBantuan = 'Tidak';
  String _statusPenerimaanSaatIni = 'Belum Menerima';
  LatLng? _lokasiTerpilih;
  File? _fotoRumah;
  String? _existingFotoUrl; 
  bool _catatSebagaiRiwayatBaru = false;

  bool get _isEditMode => widget.docId != null;

  @override
  void initState() {
    super.initState();
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

    Position position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));

    setState(() {
      _lokasiTerpilih = LatLng(position.latitude, position.longitude);
      _koordinatController.text = "${position.latitude}, ${position.longitude}";
    });

    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lokasi GPS berhasil ditemukan!")));
  }

  Future<void> _ambilFoto(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: source, imageQuality: 50);

    if (photo != null) {
      setState(() {
        _fotoRumah = File(photo.path);
      });
    }
  }

  void _showImageSourceOptions() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 10,
                spreadRadius: 1,
              )
            ],
          ),
          child: SafeArea(
            child: Wrap(
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    height: 5,
                    width: 48,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[700] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: Colors.blue),
                  title: Text(
                    'Ambil Foto (Kamera)',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _ambilFoto(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library, color: Colors.green),
                  title: Text(
                    'Pilih dari Galeri',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _ambilFoto(ImageSource.gallery);
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _isValid16Digit(String value) {
    final trimmed = value.trim();
    return trimmed.length == 16 && RegExp(r'^\d+$').hasMatch(trimmed);
  }

  Future<void> _simpanDataKeFirebase() async {
    if (_kkController.text.trim().isEmpty || _nikController.text.trim().isEmpty || _namaController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Harap lengkapi data Identitas!")));
      return;
    }
    if (!_isValid16Digit(_nikController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("NIK harus tepat 16 digit angka!")));
      return;
    }
    if (!_isValid16Digit(_kkController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No. KK harus tepat 16 digit angka!")));
      return;
    }
    if (_lokasiTerpilih == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Harap tentukan lokasi rumah!")));
      return;
    }
    if (_apakahMenerimaBantuan == 'Ya' && _jenisBantuanController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Harap isi Jenis Bantuan!")));
      return;
    }

    final wargaProvider = context.read<WargaProvider>();

    final valid = await wargaProvider.checkDuplikasi(
      _nikController.text,
      _kkController.text,
      excludeDocId: widget.docId,
    );

    if (!valid) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(wargaProvider.errorMessage ?? "Duplikasi data terdeteksi")));
      return;
    }

    final newStatus = _apakahMenerimaBantuan == 'Ya' ? _statusPenerimaanSaatIni : '-';
    final warga = Warga(
      id: widget.docId ?? '',
      nama: _namaController.text.trim(),
      nik: _nikController.text.trim(),
      noKk: _kkController.text.trim(),
      blok: _blokController.text.trim(),
      koordinat: _lokasiTerpilih!,
      menerimaBantuan: _isEditMode ? _apakahMenerimaBantuan : (_apakahMenerimaBantuan == 'Ya' ? 'Ya' : 'Tidak'),
      fotoUrl: _existingFotoUrl ?? '',
    );

    List<Map<String, dynamic>>? initialBantuan;
    if (!_isEditMode && _apakahMenerimaBantuan == 'Ya') {
      initialBantuan = [
        {
          'jenis_bantuan': _jenisBantuanController.text.trim(),
          'status_cair': _statusPenerimaanSaatIni,
          'tanggal_pencairan': _statusPenerimaanSaatIni == 'Sudah Menerima' ? FieldValue.serverTimestamp() : null,
          'dikonfirmasi_warga': false,
          'tanggal_konfirmasi': null,
          'catatan_warga': null,
        }
      ];
    }

    bool success;
    if (_isEditMode) {
      success = await wargaProvider.updateWarga(widget.docId!, warga, _fotoRumah);
    } else {
      success = await wargaProvider.addWarga(warga, _fotoRumah, initialBantuan: initialBantuan);
    }

    if (mounted) {
      if (success) {
        final msg = _isEditMode ? "Data berhasil diperbarui!" : "Alhamdulillah! Data Berhasil Disimpan.";
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) => CustomSuccessDialog(
            title: "Berhasil!",
            message: msg,
            buttonText: "Selesai",
          ),
        );
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(wargaProvider.errorMessage ?? "Gagal menyimpan data")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final wargaProvider = context.watch<WargaProvider>();
    final theme = Theme.of(context);
    
    // DETEKSI TEMA
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditMode ? "Edit Data Warga" : "Tambah Warga Baru",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("1. INFORMASI KEPALA KELUARGA", isDark),
            const SizedBox(height: 16),
            _buildInputBox(
              controller: _kkController,
              hint: "Masukkan No. KK (16 Digit) *",
              keyboardType: TextInputType.number,
            ),
            _buildInputBox(
              controller: _nikController,
              hint: "Masukkan NIK Kepala Keluarga *",
              keyboardType: TextInputType.number,
            ),
            _buildInputBox(
              controller: _namaController,
              hint: "Masukkan Nama Lengkap *",
            ),
            _buildInputBox(
              controller: _blokController,
              hint: "Masukkan Blok/Gang (opsional)",
            ),
            const SizedBox(height: 24),

            _buildSectionTitle("2. LOKASI RUMAH", isDark),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () async {
                final LatLng? result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => PickMapPage(
                            initialCenter: _lokasiTerpilih,
                            docId: widget.docId,
                          )),
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
                  // WARNA DINAMIS
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _lokasiTerpilih != null
                        ? theme.colorScheme.primary
                        : (isDark ? const Color(0xFF334155) : Colors.grey[300]!),
                    width: 1.5,
                  ),
                  boxShadow: [
                    if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _lokasiTerpilih == null ? Icons.map_outlined : Icons.add_location_alt_rounded,
                      size: 44,
                      color: _lokasiTerpilih != null
                          ? theme.colorScheme.primary
                          : (isDark ? const Color(0xFF94A3B8) : Colors.grey[400]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _lokasiTerpilih == null ? "Ketuk untuk Menyesuaikan Titik di Peta" : "Lokasi Rumah Berhasil Ditentukan!",
                      style: TextStyle(
                        color: _lokasiTerpilih != null
                            ? theme.colorScheme.primary
                            : (isDark ? const Color(0xFF94A3B8) : Colors.grey[600]),
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

            _buildSectionTitle("3. FOTO RUMAH", isDark),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _showImageSourceOptions,
              child: Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: (_fotoRumah != null || (_existingFotoUrl != null && _existingFotoUrl!.isNotEmpty))
                        ? theme.colorScheme.secondary
                        : (isDark ? const Color(0xFF334155) : Colors.grey[300]!),
                    width: 1.5,
                  ),
                  boxShadow: [
                    if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
                  ],
                  image: _fotoRumah != null
                      ? DecorationImage(image: FileImage(_fotoRumah!), fit: BoxFit.cover)
                      : (_existingFotoUrl != null && _existingFotoUrl!.isNotEmpty)
                          ? DecorationImage(image: NetworkImage(_existingFotoUrl!), fit: BoxFit.cover)
                          : null,
                ),
                child: (_fotoRumah == null && (_existingFotoUrl == null || _existingFotoUrl!.isEmpty))
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt_outlined,
                            size: 44,
                            color: isDark ? const Color(0xFF94A3B8) : Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Ketuk untuk Mengambil Foto Rumah",
                            style: TextStyle(
                              color: isDark ? const Color(0xFF94A3B8) : Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      )
                    : null,
              ),
            ),
            if (_fotoRumah != null || (_existingFotoUrl != null && _existingFotoUrl!.isNotEmpty))
              Center(
                child: TextButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: Text(_fotoRumah != null ? "Ganti Foto Rumah" : "Ganti Foto Rumah Terdaftar"),
                  onPressed: _showImageSourceOptions,
                ),
              ),
            const SizedBox(height: 24),

            if (!_isEditMode) ...[
              _buildSectionTitle("4. STATUS BANTUAN SOSIAL", isDark),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _apakahMenerimaBantuan,
                decoration: const InputDecoration(labelText: "Apakah Keluarga Ini Menerima Bantuan?"),
                dropdownColor: theme.colorScheme.surface,
                items: ['Ya', 'Tidak'].map((value) => DropdownMenuItem<String>(value: value, child: Text(value))).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _apakahMenerimaBantuan = newValue!;
                  });
                },
              ),
              if (_apakahMenerimaBantuan == 'Ya') ...[
                const SizedBox(height: 16),
                _buildInputBox(
                  controller: _jenisBantuanController,
                  hint: "Jenis Bantuan (Contoh: PKH, BPNT)",
                ),
                const SizedBox(height: 16),
                Card(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey[300]!),
                  ),
                  elevation: isDark ? 0 : 2,
                  shadowColor: Colors.black12,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Status Penerimaan Saat Ini :",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        RadioListTile<String>(
                          title: Text(
                            "Belum Menerima / Belum Cair",
                            style: TextStyle(
                              color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
                              fontSize: 14,
                            ),
                          ),
                          value: 'Belum Menerima',
                          groupValue: _statusPenerimaanSaatIni,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          activeColor: theme.colorScheme.primary,
                          onChanged: (value) => setState(() => _statusPenerimaanSaatIni = value!),
                        ),
                        RadioListTile<String>(
                          title: Text(
                            "Sudah Menerima / Sudah Cair",
                            style: TextStyle(
                              color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
                              fontSize: 14,
                            ),
                          ),
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
            ],

            // TOMBOL SIMPAN
            Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: wargaProvider.isLoading
                    ? LinearGradient(
                        colors: [
                          const Color(0xFF3B82F6).withOpacity(0.6),
                          const Color(0xFF2563EB).withOpacity(0.6),
                        ],
                      )
                    : const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                boxShadow: wargaProvider.isLoading
                    ? null
                    : [
                        BoxShadow(color: const Color(0xFF3B82F6).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
                      ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: wargaProvider.isLoading ? null : () => _simpanDataKeFirebase(),
                  borderRadius: BorderRadius.circular(16),
                  child: Center(
                    child: wargaProvider.isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                          )
                        : Text(
                            _isEditMode ? "Simpan Perubahan" : "Simpan Data Warga",
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  ),
);
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: isDark ? const Color(0xFF94A3B8) : Colors.grey[700],
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _buildInputBox({required TextEditingController controller, required String hint, TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: hint),
      ),
    );
  }
}