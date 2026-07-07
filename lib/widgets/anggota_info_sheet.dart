import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/anggota_keluarga.dart';
import '../utils/date_formatter.dart';

class AnggotaInfoSheet extends StatelessWidget {
  final AnggotaKeluarga anggota;
  final Map<String, dynamic> parentData;
  final bool isAdmin;
  final VoidCallback onRoutePressed;
  final VoidCallback onExternalMapPressed;
  final VoidCallback? onViewParentPressed;

  const AnggotaInfoSheet({
    super.key,
    required this.anggota,
    required this.parentData,
    required this.isAdmin,
    required this.onRoutePressed,
    required this.onExternalMapPressed,
    this.onViewParentPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final double maxSheetSize = isAdmin ? 0.9 : 0.65;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.15,
      minChildSize: 0.10,
      maxChildSize: maxSheetSize,
      snap: true,
      snapSizes: [0.15, maxSheetSize],
      builder: (BuildContext context, ScrollController scrollController) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
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
            controller: scrollController,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          anggota.nama,
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "${anggota.hubungan} - ${anggota.jenisKelamin}",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),

              // Detail Anggota (NIK)
              if (isAdmin) ...[
                _infoRow("NIK Anggota", anggota.nik, isDark),
              ],
              _infoRow("Blok/Gang Rumah", parentData['blok'], isDark),
              const SizedBox(height: 12),

              // Bagian Kepala Keluarga
              _buildSectionTitle("INFORMASI KELUARGA", theme),
              const SizedBox(height: 8),
              _infoRow("Nama Kepala Keluarga", parentData['nama'], isDark),
              if (isAdmin) _infoRow("No. KK", parentData['no_kk'], isDark),
              const SizedBox(height: 12),

              // Status Bansos KK (Mewarisi)
              if (isAdmin) ...[
                _buildSectionTitle("STATUS BANSOS KELUARGA", theme),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(isDark ? 0.1 : 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.primary.withOpacity(0.1)),
                  ),
                  child: Column(
                    children: [
                      _infoRow("Terima Bantuan?", parentData['menerima_bantuan'], isDark),
                      if (parentData['menerima_bantuan'] == 'Ya') ...[
                        const Divider(height: 16),
                        _infoRow("Jenis Bantuan", parentData['jenis_bantuan'], isDark),
                        _infoRow("Status Cair", parentData['status_cair'], isDark),
                        if (parentData['status_cair'] == 'Sudah Menerima' && parentData['tanggal_diterima'] != null)
                          _infoRow(
                            "Waktu Diterima",
                            parentData['tanggal_diterima'] is Timestamp
                                ? DateFormatter.formatIndonesianDate((parentData['tanggal_diterima'] as Timestamp).toDate())
                                : DateFormatter.formatIndonesianDate(parentData['tanggal_diterima']),
                            isDark,
                          ),
                      ]
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Foto Rumah (Mewarisi)
              if (parentData['foto_url'] != null && parentData['foto_url'] != '')
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: isDark ? const Color(0xFF1E293B) : Colors.grey[200],
                    image: DecorationImage(
                      image: NetworkImage(parentData['foto_url']),
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
                    color: isDark ? const Color(0xFF1E293B) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey[300]!),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_not_supported_outlined, size: 36, color: isDark ? Colors.white.withOpacity(0.3) : Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text("Foto rumah tidak tersedia", style: TextStyle(color: isDark ? Colors.white.withOpacity(0.5) : Colors.grey[500], fontSize: 13)),
                    ],
                  ),
                ),

              // --- TOMBOL LIHAT DETAIL KEPALA KELUARGA (Khusus Admin/User yang bisa tap) ---
              if (onViewParentPressed != null) ...[
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
                    icon: const Icon(Icons.people_outline),
                    label: const Text("Lihat Detail Kepala Keluarga", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    onPressed: onViewParentPressed,
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Tombol Rute
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
      },
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0, top: 4.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _infoRow(String label, dynamic value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value?.toString() ?? '-',
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
