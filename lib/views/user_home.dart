import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'search_results.dart';
import '../providers/map_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/warga_info_sheet.dart';

class UserHomePage extends StatefulWidget {
  final LatLng? centerOnLocation;
  final String? highlightDocId;

  const UserHomePage({super.key, this.centerOnLocation, this.highlightDocId});

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  String? _selectedDocId;

  @override
  void initState() {
    super.initState();
    _selectedDocId = widget.highlightDocId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.centerOnLocation != null) {
        context.read<MapProvider>().moveCamera(widget.centerOnLocation!, zoom: 19.0);
      }
    });
  }

  // --- FUNGSI BUKA GOOGLE MAPS EKSTERNAL ---
  Future<void> _openExternalMap(double lat, double lng) async {
    final Uri googleMapsUrl = Uri.parse(
        "https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving");

    if (!await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Tidak dapat membuka Google Maps")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapProvider = context.watch<MapProvider>();
    final authProvider = context.watch<AuthProvider>();
    final isLoggedInWarga = authProvider.isLoggedIn && (authProvider.user?.email ?? '').endsWith('@warga.sigbansos.com');

    return Scaffold(
      body: Stack(
        children: [
          // StreamBuilder untuk membaca Pin Marker secara realtime dari Firestore
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('warga').snapshots(),
            builder: (context, snapshot) {
              Set<Marker> markers = {};
              if (snapshot.hasData) {
                for (var doc in snapshot.data!.docs) {
                  var data = doc.data() as Map<String, dynamic>;
                  if (data['lokasi'] != null) {
                    GeoPoint geoPoint = data['lokasi'];
                    bool isSelected = (_selectedDocId == doc.id);

                    markers.add(
                      Marker(
                        markerId: MarkerId(doc.id),
                        position: LatLng(geoPoint.latitude, geoPoint.longitude),
                        icon: isSelected
                            ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)
                            : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                        onTap: () => _showWargaInfo(context, doc.id, data),
                      ),
                    );
                  }
                }
              }
              return GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: widget.centerOnLocation ?? const LatLng(-6.850071, 107.930230),
                  zoom: 18.0,
                ),
                onMapCreated: (controller) {
                  context.read<MapProvider>().setController(controller);
                },
                onTap: (point) {
                  if (_selectedDocId != null) setState(() => _selectedDocId = null);
                },
                markers: markers,
                polylines: mapProvider.polylines,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
              );
            },
          ),

          // Search bar dan Login button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(15.0),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: Material(
                      elevation: 5, shape: const CircleBorder(), color: Colors.white,
                      child: CircleAvatar(
                        backgroundColor: Colors.white,
                        child: isLoggedInWarga
                            ? IconButton(
                                icon: const Icon(Icons.person, color: Color(0xFF1E3A8A)),
                                tooltip: "Profil Saya",
                                onPressed: () => _showProfilWarga(context, authProvider.user!.email!),
                              )
                            : IconButton(
                                icon: const Icon(Icons.login, color: Color(0xFF1E3A8A)),
                                tooltip: "Login",
                                onPressed: () => Navigator.pushNamed(context, '/login'),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(30),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)],
                    ),
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: "Cari Lokasi Rumah Warga...",
                        border: InputBorder.none,
                        filled: false,
                        icon: Icon(Icons.search, color: Colors.grey),
                      ),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (value) {
                        if (value.trim().isNotEmpty) {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => SearchResultsPage(query: value, isAdmin: false)));
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Tombol Hapus Rute
          if (mapProvider.polylines.isNotEmpty)
            Positioned(
              bottom: 30,
              right: 15,
              child: FloatingActionButton.extended(
                onPressed: () => mapProvider.clearRoute(),
                backgroundColor: Colors.red[800],
                icon: const Icon(Icons.clear, color: Colors.white),
                label: const Text("Hapus Rute", style: TextStyle(color: Colors.white)),
              ),
            ),

          // Indikator Loading Rute
          if (mapProvider.isLoadingRoute)
            const Center(
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 10),
                      Text("Memuat Rute..."),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showWargaInfo(BuildContext context, String docId, Map<String, dynamic> data) {
    setState(() => _selectedDocId = docId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return WargaInfoSheet(
          docId: docId,
          data: data,
          isAdmin: false,
          onRoutePressed: () async {
            Navigator.pop(context); // Tutup bottom sheet
            if (data['lokasi'] != null) {
              GeoPoint geo = data['lokasi'];
              final mapProv = context.read<MapProvider>();
              final success = await mapProv.drawRoute(geo.latitude, geo.longitude);
              if (!success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(mapProv.errorMessage ?? "Gagal memuat rute")),
                );
              }
            }
          },
          onExternalMapPressed: () {
            if (data['lokasi'] != null) {
              GeoPoint geo = data['lokasi'];
              _openExternalMap(geo.latitude, geo.longitude);
            }
          },
        );
      },
    ).whenComplete(() {
      setState(() => _selectedDocId = null);
    });
  }

  void _showProfilWarga(BuildContext context, String email) {
    final String nik = email.split('@')[0];

    // Inisialisasi stream di luar builder agar tidak di-recreate saat bottom sheet di-drag/rebuild
    final Stream<QuerySnapshot> profileStream = FirebaseFirestore.instance
        .collection('warga')
        .where('nik', isEqualTo: nik)
        .snapshots();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StreamBuilder<QuerySnapshot>(
          stream: profileStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      const Text(
                        "Profil Warga Tidak Ditemukan",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Akun NIK $nik belum terdaftar di sistem warga Ketua RT. Silakan hubungi Ketua RT.",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            Navigator.pop(context);
                            await context.read<AuthProvider>().signOut();
                          },
                          child: const Text("Keluar Sesi / Logout"),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final data = snapshot.data!.docs.first.data() as Map<String, dynamic>;

            return SafeArea(
              child: Container(
                padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
                width: double.infinity,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['nama'] ?? 'Tanpa Nama',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const Text("Akun Resmi Warga Tegalsari", style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const Divider(height: 24),
                      const Text(
                        "DATA KEPENDUDUKAN",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey, letterSpacing: 1.1),
                      ),
                      const SizedBox(height: 8),
                      _profilRow("Nama Kepala Keluarga", data['nama']),
                      _profilRow("NIK", data['nik']),
                      _profilRow("No. KK", data['no_kk']),
                      _profilRow("Blok/Gang", data['blok']),
                      const SizedBox(height: 24),

                      const Text(
                        "STATUS BANTUAN SOSIAL (BANSOS)",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey, letterSpacing: 1.1),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: data['menerima_bantuan'] == 'Ya'
                              ? Colors.green.withOpacity(0.05)
                              : Colors.grey.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: data['menerima_bantuan'] == 'Ya'
                                ? Colors.green.withOpacity(0.1)
                                : Colors.grey.withOpacity(0.1),
                          ),
                        ),
                        child: Column(
                          children: [
                            _profilRow("Penerima Bantuan?", data['menerima_bantuan']),
                            if (data['menerima_bantuan'] == 'Ya') ...[
                              const Divider(height: 16),
                              _profilRow("Jenis Bantuan", data['jenis_bantuan']),
                              _profilRow("Status Cair", data['status_cair']),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      const Text(
                        "RIWAYAT PENYALURAN BANSOS",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey, letterSpacing: 1.1),
                      ),
                      const SizedBox(height: 8),
                      if (data['menerima_bantuan'] == 'Ya')
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: data['status_cair'] == 'Sudah Menerima'
                                ? Colors.green[100]
                                : Colors.amber[100],
                            child: Icon(
                              data['status_cair'] == 'Sudah Menerima' ? Icons.check : Icons.access_time,
                              color: data['status_cair'] == 'Sudah Menerima' ? Colors.green : Colors.amber[800],
                            ),
                          ),
                          title: const Text("Penyaluran Periode Saat Ini", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text(
                            data['status_cair'] == 'Sudah Menerima'
                                ? "Telah disalurkan ke rumah warga"
                                : "Menunggu pencairan di Kelurahan",
                            style: const TextStyle(fontSize: 12),
                          ),
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text("Tidak ada riwayat bantuan sosial untuk akun NIK ini.", style: TextStyle(color: Colors.grey, fontSize: 13)),
                        ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: BorderSide(color: Theme.of(context).colorScheme.primary),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () {
                                debugPrint('[WargaProfile] Menampilkan dialog Ubah Password...');
                                _showUbahPasswordDialog(context);
                              },
                              icon: const Icon(Icons.lock_reset),
                              label: const Text("Ubah Password"),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                backgroundColor: Colors.red[800],
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () async {
                                debugPrint('[WargaProfile] Melakukan aksi Keluar Sesi/Logout...');
                                Navigator.pop(context);
                                await context.read<AuthProvider>().signOut();
                                debugPrint('[WargaProfile] Logout berhasil.');
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Berhasil keluar dari akun warga")),
                                  );
                                }
                              },
                              icon: const Icon(Icons.logout),
                              label: const Text("Keluar Sesi"),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _profilRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value?.toString() ?? '-',
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
        ],
      ),
    );
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.lock_outline, color: Color(0xFF1E3A8A)),
                  SizedBox(width: 8),
                  Text("Ubah Password", style: TextStyle(fontWeight: FontWeight.bold)),
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
                        "Masukkan password baru Anda. Password minimal terdiri dari 6 karakter.",
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
                            return "Password konfirmasi tidak sama";
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: isLoading
                      ? null
                      : () async {
                          debugPrint('[ChangePassword] Tombol Simpan ditekan.');
                          if (formKey.currentState!.validate()) {
                            debugPrint('[ChangePassword] Form validasi berhasil.');
                            setState(() {
                              isLoading = true;
                              dialogErrorMessage = null;
                            });
                            try {
                              final user = FirebaseAuth.instance.currentUser;
                              debugPrint('[ChangePassword] Pengguna aktif: ${user?.email}');
                              if (user != null) {
                                debugPrint('[ChangePassword] Mengirim request updatePassword ke Firebase Auth...');
                                await user.updatePassword(newPasswordController.text);
                                debugPrint('[ChangePassword] Sukses memperbarui password.');
                                if (parentContext.mounted) {
                                  final messenger = ScaffoldMessenger.of(parentContext);
                                  Navigator.pop(dialogContext); // Tutup dialog Ubah Password
                                  Navigator.pop(parentContext); // Tutup bottom sheet Profil
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text("Password berhasil diperbarui!"),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } else {
                                throw FirebaseAuthException(
                                  code: 'no-user',
                                  message: 'Pengguna tidak terdeteksi aktif.',
                                );
                              }
                            } on FirebaseAuthException catch (e) {
                              debugPrint('[ChangePassword] FirebaseAuthException: [${e.code}] ${e.message}');
                              String errMsg = "Gagal memperbarui password: ${e.message}";
                              if (e.code == 'requires-recent-login') {
                                errMsg = "Sesi Anda sudah kedaluwarsa demi keamanan. Silakan keluar (logout) dan login kembali sebelum mengubah password.";
                              }
                              setState(() {
                                dialogErrorMessage = errMsg;
                              });
                            } catch (e) {
                              debugPrint('[ChangePassword] Generic Exception: $e');
                              setState(() {
                                dialogErrorMessage = "Terjadi kesalahan: $e";
                              });
                            } finally {
                              setState(() => isLoading = false);
                            }
                          } else {
                            debugPrint('[ChangePassword] Form validasi gagal (salah satu input tidak valid).');
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
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
}
