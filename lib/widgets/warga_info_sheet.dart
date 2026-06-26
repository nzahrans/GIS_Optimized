import 'package:flutter/material.dart';
import '../utils/date_formatter.dart';

class WargaInfoSheet extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final bool isAdmin;
  final VoidCallback onRoutePressed;
  final VoidCallback onExternalMapPressed;
  final VoidCallback? onEditPressed;
  final VoidCallback? onDeletePressed;

  const WargaInfoSheet({
    super.key,
    required this.docId,
    required this.data,
    required this.isAdmin,
    required this.onRoutePressed,
    required this.onExternalMapPressed,
    this.onEditPressed,
    this.onDeletePressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final double maxSheetSize = isAdmin ? 0.9 : 0.55;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.15, // Step 1: Muncul pertama kali di 40% layar
      minChildSize: 0.10,    // Batas minimum sebelum otomatis tertutup
      maxChildSize: maxSheetSize,     // Step 2: Maksimal saat ditarik full ke atas (90% layar)
      snap: true,            // Mengaktifkan efek magnet/step
      snapSizes: [0.15, maxSheetSize], // Titik henti drag
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor, // Menyesuaikan tema
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 0,
              )
            ],
          ),
          child: ListView(
            controller: scrollController, // Wajib dipasang agar bisa di-drag
            padding: const EdgeInsets.only(bottom: 20),
            children: [
              // --- DRAG HANDLE (Indikator Tarik) ---
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 16),
                  height: 5,
                  width: 48,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      data['nama'] ?? 'Tanpa Nama', //[cite: 1]
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor), //[cite: 1]
                    ),
                  ),
                  if (isAdmin && onDeletePressed != null) //[cite: 1]
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 28), //[cite: 1]
                      onPressed: onDeletePressed, //[cite: 1]
                    ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),

              // NIK & No KK (Admin Only)
              if (isAdmin) ...[
                _infoRow("NIK", data['nik'], isDark), //[cite: 1]
                _infoRow("No. KK", data['no_kk'], isDark), //[cite: 1]
              ],
              _infoRow("Blok/Gang", data['blok'], isDark), //[cite: 1]
              
              if (isAdmin) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12), //[cite: 1]
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(isDark ? 0.1 : 0.05), //[cite: 1]
                    borderRadius: BorderRadius.circular(12), //[cite: 1]
                    border: Border.all(color: theme.colorScheme.primary.withOpacity(0.1)), //[cite: 1]
                  ),
                  child: Column(
                    children: [
                      _infoRow("Terima Bantuan?", data['menerima_bantuan'], isDark), //[cite: 1]
                      if (data['menerima_bantuan'] == 'Ya') ...[ //[cite: 1]
                        const Divider(height: 16),
                        _infoRow("Jenis Bantuan", data['jenis_bantuan'], isDark), //[cite: 1]
                        _infoRow("Status Cair", data['status_cair'], isDark), //[cite: 1]
                        if (data['status_cair'] == 'Sudah Menerima' && data['tanggal_diterima'] != null) //[cite: 1]
                          _infoRow(
                            "Waktu Diterima", //[cite: 1]
                            DateFormatter.formatIndonesianDate(data['tanggal_diterima']), //[cite: 1]
                            isDark,
                          ),
                      ]
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Foto Rumah
              if (data['foto_url'] != null && data['foto_url'] != '') //[cite: 1]
                Container(
                  margin: const EdgeInsets.only(bottom: 24), //[cite: 1]
                  height: 180, //[cite: 1]
                  width: double.infinity, //[cite: 1]
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16), //[cite: 1]
                    color: isDark ? const Color(0xFF1E293B) : Colors.grey[200], //[cite: 1]
                    image: DecorationImage(
                      image: NetworkImage(data['foto_url']), //[cite: 1]
                      fit: BoxFit.cover, //[cite: 1]
                    ),
                  ),
                )
              else
                Container(
                  margin: const EdgeInsets.only(bottom: 24), //[cite: 1]
                  height: 120, //[cite: 1]
                  width: double.infinity, //[cite: 1]
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.grey[100], //[cite: 1]
                    borderRadius: BorderRadius.circular(16), //[cite: 1]
                    border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey[300]!), //[cite: 1]
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min, //[cite: 1]
                    mainAxisAlignment: MainAxisAlignment.center, //[cite: 1]
                    children: [
                      Icon(Icons.image_not_supported_outlined, size: 36, color: isDark ? Colors.white.withOpacity(0.3) : Colors.grey[400]), //[cite: 1]
                      const SizedBox(height: 8), //[cite: 1]
                      Text("Foto rumah tidak tersedia", style: TextStyle(color: isDark ? Colors.white.withOpacity(0.5) : Colors.grey[500], fontSize: 13)), //[cite: 1]
                    ],
                  ),
                ),

              // --- TOMBOL-TOMBOL NAVIGASI / EDIT ---
              if (isAdmin && onEditPressed != null) ...[ //[cite: 1]
                SizedBox(
                  width: double.infinity, //[cite: 1]
                  height: 50, //[cite: 1]
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.secondary, //[cite: 1]
                      foregroundColor: Colors.white, //[cite: 1]
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), //[cite: 1]
                      elevation: 1, //[cite: 1]
                    ),
                    icon: const Icon(Icons.edit_outlined), //[cite: 1]
                    label: const Text("Edit Data Warga", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)), //[cite: 1]
                    onPressed: onEditPressed, //[cite: 1]
                  ),
                ),
                const SizedBox(height: 12), //[cite: 1]
              ],

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.primary, //[cite: 1]
                        side: BorderSide(color: theme.colorScheme.primary, width: 1.5), //[cite: 1]
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), //[cite: 1]
                        padding: const EdgeInsets.symmetric(vertical: 14), //[cite: 1]
                      ),
                      icon: const Icon(Icons.map_outlined, size: 18), //[cite: 1]
                      label: const Text("Tampilkan Rute", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)), //[cite: 1]
                      onPressed: onRoutePressed, //[cite: 1]
                    ),
                  ),
                  const SizedBox(width: 12), //[cite: 1]
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary, //[cite: 1]
                        foregroundColor: Colors.white, //[cite: 1]
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), //[cite: 1]
                        padding: const EdgeInsets.symmetric(vertical: 14), //[cite: 1]
                        elevation: 1, //[cite: 1]
                      ),
                      icon: const Icon(Icons.directions_outlined, size: 18), //[cite: 1]
                      label: const Text("Google Maps", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)), //[cite: 1]
                      onPressed: onExternalMapPressed, //[cite: 1]
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8), //[cite: 1]
            ],
          ),
        );
      },
    );
  }

  Widget _infoRow(String label, dynamic value, bool isDark) { //[cite: 1]
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4), //[cite: 1]
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, //[cite: 1]
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)), //[cite: 1]
          Text(value?.toString() ?? '-', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: isDark ? Colors.white : Colors.black87)), //[cite: 1]
        ],
      ),
    );
  }
}