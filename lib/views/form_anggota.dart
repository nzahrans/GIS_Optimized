import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/anggota_keluarga.dart';
import '../providers/warga_provider.dart';
import '../services/firestore_service.dart';

class FormAnggotaPage extends StatefulWidget {
  final String wargaDocId;
  final String noKk;
  final AnggotaKeluarga? anggota;

  const FormAnggotaPage({
    super.key,
    required this.wargaDocId,
    required this.noKk,
    this.anggota,
  });

  @override
  State<FormAnggotaPage> createState() => _FormAnggotaPageState();
}

class _FormAnggotaPageState extends State<FormAnggotaPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _kkController;
  late final TextEditingController _nikController;
  late final TextEditingController _namaController;

  String _jenisKelamin = 'Pria';
  String _hubungan = 'Anak';
  bool _isEditMode = false;

  final List<String> _listHubungan = ['Istri', 'Anak', 'Orang Tua', 'Lainnya'];
  final List<String> _listJenisKelamin = ['Pria', 'Wanita'];

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.anggota != null;
    _kkController = TextEditingController(text: widget.noKk);
    _nikController = TextEditingController(text: widget.anggota?.nik ?? '');
    _namaController = TextEditingController(text: widget.anggota?.nama ?? '');
    
    if (_isEditMode && widget.anggota != null) {
      _jenisKelamin = widget.anggota!.jenisKelamin;
      _hubungan = widget.anggota!.hubungan;
    }
  }

  @override
  void dispose() {
    _kkController.dispose();
    _nikController.dispose();
    _namaController.dispose();
    super.dispose();
  }

  bool _isValid16Digit(String val) {
    return RegExp(r'^\d{16}$').hasMatch(val.trim());
  }

  Future<void> _simpanData() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<WargaProvider>();
    final nik = _nikController.text.trim();
    final nama = _namaController.text.trim();

    // Validasi NIK Terdaftar
    final exists = await FirestoreService.isNikExists(
      nik,
      excludeDocId: widget.anggota?.id,
    );

    if (exists && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("NIK sudah terdaftar di sistem!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final newAnggota = AnggotaKeluarga(
      id: widget.anggota?.id ?? '',
      parentDocId: widget.wargaDocId,
      nik: nik,
      nama: nama,
      noKk: widget.noKk,
      jenisKelamin: _jenisKelamin,
      hubungan: _hubungan,
    );

    bool success = false;
    if (_isEditMode) {
      success = await provider.updateAnggota(widget.wargaDocId, widget.anggota!.id, newAnggota);
    } else {
      success = await provider.addAnggota(widget.wargaDocId, newAnggota);
    }

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditMode ? "Data anggota berhasil diperbarui" : "Anggota keluarga berhasil ditambahkan"),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? "Gagal menyimpan data"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = context.watch<WargaProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditMode ? "Edit Anggota Keluarga" : "Tambah Anggota Keluarga",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle("INFORMASI ANGGOTA KELUARGA", isDark),
              const SizedBox(height: 16),
              
              // No KK (Read-Only)
              _buildReadOnlyField(
                controller: _kkController,
                hint: "Nomor KK",
                icon: Icons.folder_shared_outlined,
              ),
              const SizedBox(height: 12),

              // NIK
              _buildInputField(
                controller: _nikController,
                hint: "NIK Anggota Keluarga (16 Digit) *",
                icon: Icons.badge_outlined,
                keyboardType: TextInputType.number,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return "NIK wajib diisi";
                  }
                  if (!_isValid16Digit(val)) {
                    return "NIK harus terdiri dari 16 digit angka";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Nama
              _buildInputField(
                controller: _namaController,
                hint: "Nama Lengkap *",
                icon: Icons.person_outline,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return "Nama lengkap wajib diisi";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Jenis Kelamin Dropdown
              _buildDropdownField<String>(
                label: "Jenis Kelamin",
                value: _jenisKelamin,
                items: _listJenisKelamin.map((val) {
                  return DropdownMenuItem(
                    value: val,
                    child: Text(val),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _jenisKelamin = val);
                },
                icon: Icons.wc_outlined,
              ),
              const SizedBox(height: 12),

              // Hubungan Dropdown
              _buildDropdownField<String>(
                label: "Hubungan dengan Kepala Keluarga",
                value: _hubungan,
                items: _listHubungan.map((val) {
                  return DropdownMenuItem(
                    value: val,
                    child: Text(val),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _hubungan = val);
                },
                icon: Icons.family_restroom_outlined,
              ),
              const SizedBox(height: 36),

              // Tombol Simpan
              Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: provider.isLoading
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
                  boxShadow: provider.isLoading
                      ? null
                      : [
                          BoxShadow(
                            color: const Color(0xFF3B82F6).withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: provider.isLoading ? null : _simpanData,
                    borderRadius: BorderRadius.circular(16),
                    child: Center(
                      child: provider.isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              _isEditMode ? "Simpan Perubahan" : "Tambah Anggota",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
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

  Widget _buildReadOnlyField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withOpacity(0.5) : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.grey),
          labelText: hint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    required String? Function(String?) validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: isDark ? Colors.blue[400] : const Color(0xFF3B82F6)),
          labelText: hint,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: isDark ? const Color(0xFF334155) : Colors.grey[300]!,
              width: 1.5,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: isDark ? const Color(0xFF334155) : Colors.grey[300]!,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
        ],
      ),
      child: DropdownButtonFormField<T>(
        value: value,
        items: items,
        onChanged: onChanged,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: isDark ? Colors.blue[400] : const Color(0xFF3B82F6)),
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: isDark ? const Color(0xFF334155) : Colors.grey[300]!,
              width: 1.5,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: isDark ? const Color(0xFF334155) : Colors.grey[300]!,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
