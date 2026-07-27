import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/warga_provider.dart';
import '../services/firestore_service.dart';
import '../utils/date_formatter.dart';

class UserDashboardPage extends StatefulWidget {
  const UserDashboardPage({super.key});

  @override
  State<UserDashboardPage> createState() => _UserDashboardPageState();
}

class _UserDashboardPageState extends State<UserDashboardPage> {
  final _formKey = GlobalKey<FormState>();
  final _catatanController = TextEditingController();

  @override
  void dispose() {
    _catatanController.dispose();
    super.dispose();
  }

  void _showUbahPasswordDialog(BuildContext parentContext) {
    final formKey = GlobalKey<FormState>();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isLoading = false;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: parentContext,
      builder: (dialogContext) {
        String? dialogErrorMessage;
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.lock_outline, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  const Text("Ubah Password", style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (dialogErrorMessage != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red[200]!),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.error_outline, color: Colors.red[800], size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  dialogErrorMessage!,
                                  style: TextStyle(color: Colors.red[900], fontSize: 13, height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      const Text(
                        "Masukkan password baru Anda.\nPassword minimal terdiri dari 6 karakter.",
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: newPasswordController,
                        obscureText: obscureNew,
                        decoration: InputDecoration(
                          labelText: "Password Baru",
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => obscureNew = !obscureNew),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Password baru tidak boleh kosong";
                          }
                          if (value.length < 6) {
                            return "Password minimal 6 karakter";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: confirmPasswordController,
                        obscureText: obscureConfirm,
                        decoration: InputDecoration(
                          labelText: "Konfirmasi Password Baru",
                          prefixIcon: const Icon(Icons.lock_reset_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => obscureConfirm = !obscureConfirm),
                          ),
                        ),
                        validator: (value) {
                          if (value != newPasswordController.text) {
                            return "Konfirmasi password tidak cocok";
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
                  child: const Text("Batal"),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            setState(() {
                              isLoading = true;
                              dialogErrorMessage = null;
                            });

                            try {
                              final user = FirebaseAuth.instance.currentUser;
                              if (user != null) {
                                await user.updatePassword(newPasswordController.text.trim());
                                if (mounted) {
                                  Navigator.pop(dialogContext);
                                  ScaffoldMessenger.of(parentContext).showSnackBar(
                                    const SnackBar(
                                      content: Text("Password berhasil diperbarui!"),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } else {
                                throw Exception("Sesi user tidak aktif");
                              }
                            } on FirebaseAuthException catch (e) {
                              setState(() {
                                isLoading = false;
                                if (e.code == 'requires-recent-login') {
                                  dialogErrorMessage =
                                      "Tindakan ini sensitif dan memerlukan masuk kembali terlebih dahulu.";
                                } else {
                                  dialogErrorMessage = e.message ?? "Gagal memperbarui password";
                                }
                              });
                            } catch (e) {
                              setState(() {
                                isLoading = false;
                                dialogErrorMessage = "Gagal memperbarui password: $e";
                              });
                            }
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                        )
                      : const Text("Simpan"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showKonfirmasiDialog(BuildContext context, String wargaDocId, String bantuanDocId, String jenisBantuan) {
    _catatanController.clear();
    final theme = Theme.of(context);
    final wargaProvider = Provider.of<WargaProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) {
        bool isDialogLoading = false;
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              backgroundColor: theme.colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                "Konfirmasi Bantuan",
                style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
              ),
              content: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Apakah Anda menyatakan bahwa telah menerima bantuan \"$jenisBantuan\" dengan baik dan tepat sasaran?",
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _catatanController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: "Catatan atau Masukan (Opsional)",
                        alignLabelWithHint: true,
                        hintText: "Tulis masukan tentang penyaluran bansos di sini...",
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isDialogLoading ? null : () => Navigator.pop(ctx),
                  child: const Text("Batal"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isDialogLoading
                      ? null
                      : () async {
                          setState(() {
                            isDialogLoading = true;
                          });

                          final success = await wargaProvider.konfirmasiBantuan(
                            wargaDocId,
                            bantuanDocId,
                            _catatanController.text.trim(),
                          );

                          if (mounted) {
                            Navigator.pop(ctx);
                            if (success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Terima kasih! Bantuan berhasil dikonfirmasi."),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(wargaProvider.errorMessage ?? "Gagal mengkonfirmasi bantuan"),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  child: isDialogLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                        )
                      : const Text("Ya, Konfirmasi"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    // Dapatkan NIK dari email warga yang login
    final String userEmail = authProvider.user?.email ?? '';
    final String nik = userEmail.split('@')[0];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Dashboard Warga Padamulya",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => themeProvider.toggleTheme(!themeProvider.isDarkMode),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authProvider.signOut();
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/home');
              }
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: Container(
          color: isDark ? const Color(0xFF090D16) : Colors.white,
          child: Column(
            children: [
              UserAccountsDrawerHeader(
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                ),
                currentAccountPicture: const CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 40, color: Color(0xFF3B82F6)),
                ),
                accountName: const Text(
                  "Warga Desa Padamulya",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                accountEmail: Text(userEmail),
              ),
              ListTile(
                leading: const Icon(Icons.dashboard, color: Color(0xFF3B82F6)),
                title: const Text('Dashboard Utama', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.map, color: Colors.grey),
                title: const Text('Tampilan Peta'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/home');
                },
              ),
              ListTile(
                leading: const Icon(Icons.analytics_outlined, color: Colors.grey),
                title: const Text('Transparansi Penyaluran'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/transparansi');
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.lock_outline, color: Colors.grey),
                title: const Text('Ubah Password'),
                onTap: () {
                  Navigator.pop(context);
                  _showUbahPasswordDialog(context);
                },
              ),
              const Spacer(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text('Keluar dari Akun', style: TextStyle(color: Colors.redAccent)),
                onTap: () async {
                  await authProvider.signOut();
                  if (mounted) {
                    Navigator.of(context).pushReplacementNamed('/home');
                  }
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('warga').where('nik', isEqualTo: nik).limit(1).snapshots(),
        builder: (context, profileSnapshot) {
          if (profileSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (profileSnapshot.hasError || !profileSnapshot.hasData || profileSnapshot.data!.docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text(
                      "Data Anda tidak ditemukan!",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Silakan hubungi admin atau ketua RT jika Anda belum terdaftar di aplikasi SIGAP.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            );
          }

          final wargaDoc = profileSnapshot.data!.docs.first;
          final wargaDocId = wargaDoc.id;
          final wargaData = wargaDoc.data() as Map<String, dynamic>;
          final String nama = wargaData['nama'] ?? '';
          final String blok = wargaData['blok'] ?? '-';
          final String noKk = wargaData['no_kk'] ?? '';
          final String fotoUrl = wargaData['foto_url'] ?? '';

          // Masking NIK dan No. KK demi privasi
          final maskedNik = nik.length == 16
              ? '${nik.substring(0, 4)}**********${nik.substring(14)}'
              : nik;
          final maskedKk = noKk.length == 16
              ? '${noKk.substring(0, 4)}**********${noKk.substring(14)}'
              : noKk;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Box Warga
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey[200]!),
                    boxShadow: [
                      if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                        backgroundImage: fotoUrl.isNotEmpty ? NetworkImage(fotoUrl) : null,
                        child: fotoUrl.isEmpty ? Icon(Icons.person, size: 28, color: theme.colorScheme.primary) : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nama,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text("Blok/Gang: $blok", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 12)),
                            const SizedBox(height: 2),
                            Text("No. KK: $maskedKk", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[500], fontSize: 11)),
                            Text("NIK: $maskedNik", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[500], fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Quick Navigation Buttons
                Row(
                  children: [
                    Expanded(
                      child: _buildQuickNavButton(
                        context,
                        "Buka Peta Desa",
                        Icons.map_outlined,
                        theme.colorScheme.primary,
                        '/home',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildQuickNavButton(
                        context,
                        "Transparansi",
                        Icons.analytics_outlined,
                        Colors.teal,
                        '/transparansi',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Bantuan Sosial Aktif
                Text(
                  "Program Bantuan Sosial Anda",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 12),

                StreamBuilder<QuerySnapshot>(
                  stream: FirestoreService.getBantuanAktifStream(wargaDocId),
                  builder: (context, bantuanSnapshot) {
                    if (bantuanSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final bantuanList = bantuanSnapshot.data?.docs ?? [];
                    if (bantuanList.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey[200]!),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Saat ini Anda tidak terdaftar sebagai penerima bantuan sosial.",
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: bantuanList.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final doc = bantuanList[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final String idBantuan = doc.id;
                        final String jenis = data['jenis_bantuan'] ?? '-';
                        final String status = data['status_cair'] ?? 'Belum Menerima';
                        
                        Color badgeColor = Colors.grey;
                        IconData badgeIcon = Icons.hourglass_empty;
                        if (status == 'Sudah Menerima') {
                          badgeColor = Colors.orange;
                          badgeIcon = Icons.check_circle_outline;
                        } else if (status == 'Dikonfirmasi Warga') {
                          badgeColor = Colors.green;
                          badgeIcon = Icons.verified_user;
                        }

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      jenis,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: badgeColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(badgeIcon, color: badgeColor, size: 14),
                                        const SizedBox(width: 4),
                                        Text(
                                          status,
                                          style: TextStyle(
                                            color: badgeColor,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (status == 'Sudah Menerima') ...[
                                const Divider(height: 20),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    onPressed: () => _showKonfirmasiDialog(context, wargaDocId, idBantuan, jenis),
                                    icon: const Icon(Icons.check, size: 18),
                                    label: const Text("Konfirmasi Bantuan Diterima", style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ] else if (status == 'Dikonfirmasi Warga') ...[
                                const Divider(height: 20),
                                Row(
                                  children: [
                                    const Icon(Icons.check_circle, color: Colors.green, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Telah dikonfirmasi pada ${data['tanggal_konfirmasi'] != null ? DateFormatter.formatIndonesianDate((data['tanggal_konfirmasi'] as Timestamp).toDate()) : '-'}",
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                  ],
                                ),
                                if (data['catatan_warga'] != null && (data['catatan_warga'] as String).isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    "Catatan Anda: \"${data['catatan_warga']}\"",
                                    style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
                                  ),
                                ],
                              ] else ...[
                                const Divider(height: 20),
                                const Row(
                                  children: [
                                    Icon(Icons.access_time, color: Colors.red, size: 16),
                                    SizedBox(width: 8),
                                    Text(
                                      "Bansos belum cair atau masih diproses oleh RT.",
                                      style: TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Riwayat Penyaluran (Timeline)
                Text(
                  "Riwayat Penerimaan Bansos",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 12),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('warga')
                      .doc(wargaDocId)
                      .collection('riwayat_bansos')
                      .orderBy('tanggal_diterima', descending: true)
                      .snapshots(),
                  builder: (context, riwayatSnapshot) {
                    if (riwayatSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final riwayatList = riwayatSnapshot.data?.docs ?? [];
                    if (riwayatList.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        alignment: Alignment.center,
                        child: const Text("Belum ada riwayat penerimaan bantuan.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: riwayatList.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final data = riwayatList[index].data() as Map<String, dynamic>;
                        final String jenis = data['jenis_bantuan'] ?? '';
                        final String status = data['status_cair'] ?? '';
                        final Timestamp? tgl = data['tanggal_diterima'];
                        final String dateStr = tgl != null ? DateFormatter.formatIndonesianDate(tgl.toDate()) : '-';
                        final bool dikonfirmasi = data['dikonfirmasi_warga'] ?? false;

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey[200]!),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: dikonfirmasi ? Colors.green.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                                child: Icon(
                                  dikonfirmasi ? Icons.verified : Icons.payment,
                                  color: dikonfirmasi ? Colors.green : Colors.blue,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Bantuan: $jenis",
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "Status: $status ($dateStr)",
                                      style: const TextStyle(color: Colors.grey, fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickNavButton(BuildContext context, String label, IconData icon, Color color, String route) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey[200]!),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.pushNamed(context, route),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
