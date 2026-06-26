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
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
        width: double.infinity,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      data['nama'] ?? 'Tanpa Nama',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (isAdmin && onDeletePressed != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 28),
                      onPressed: onDeletePressed,
                    ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),

              // NIK & No KK (Admin Only)
              if (isAdmin) ...[
                _infoRow("NIK", data['nik']),
                _infoRow("No. KK", data['no_kk']),
              ],
              _infoRow("Blok/Gang", data['blok']),
              
              if (isAdmin) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.primary.withOpacity(0.1)),
                  ),
                  child: Column(
                    children: [
                      _infoRow("Terima Bantuan?", data['menerima_bantuan']),
                      if (data['menerima_bantuan'] == 'Ya') ...[
                        const Divider(height: 16),
                        _infoRow("Jenis Bantuan", data['jenis_bantuan']),
                        _infoRow("Status Cair", data['status_cair']),
                        if (data['status_cair'] == 'Sudah Menerima' &&
                            data['tanggal_diterima'] != null)
                          _infoRow(
                            "Waktu Diterima",
                            DateFormatter.formatIndonesianDate(data['tanggal_diterima']),
                          ),
                      ]
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Foto Rumah
              if (data['foto_url'] != null && data['foto_url'] != '')
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: const Color(0xFF090D16),
                    image: DecorationImage(
                      image: NetworkImage(data['foto_url']),
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF090D16),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_not_supported_outlined, size: 36, color: Colors.white.withOpacity(0.3)),
                      const SizedBox(height: 8),
                      Text("Foto rumah tidak tersedia", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
                    ],
                  ),
                ),


              // --- TOMBOL-TOMBOL NAVIGASI / EDIT ---
              if (isAdmin && onEditPressed != null) ...[
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.secondary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 1,
                    ),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text("Edit Data Warga", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    onPressed: onEditPressed,
                  ),
                ),
                const SizedBox(height: 12),
              ],

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.primary,
                        side: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: const Text("Tampilkan Rute", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      onPressed: onRoutePressed,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 1,
                      ),
                      icon: const Icon(Icons.directions_outlined, size: 18),
                      label: const Text("Google Maps", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      onPressed: onExternalMapPressed,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          Text(value?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        ],
      ),
    );
  }
}
