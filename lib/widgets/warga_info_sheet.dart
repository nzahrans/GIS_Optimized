import 'package:flutter/material.dart';

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
    return Container(
      padding: const EdgeInsets.all(20),
      width: double.infinity,
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
                  icon: const Icon(Icons.delete, color: Colors.red, size: 28),
                  onPressed: onDeletePressed,
                ),
            ],
          ),
          const Divider(),

          // NIK & No KK (Admin Only)
          if (isAdmin) ...[
            _infoRow("NIK", data['nik']),
            _infoRow("No. KK", data['no_kk']),
          ],
          _infoRow("Blok/Gang", data['blok']),
          
          if (isAdmin) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  _infoRow("Terima Bantuan?", data['menerima_bantuan']),
                  if (data['menerima_bantuan'] == 'Ya') ...[
                    _infoRow("Jenis Bantuan", data['jenis_bantuan']),
                    _infoRow("Status Cair", data['status_cair']),
                  ]
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),

          // Foto Rumah
          if (data['foto_url'] != null && data['foto_url'] != '')
            Container(
              margin: const EdgeInsets.only(bottom: 15),
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                color: Colors.grey[200],
                image: DecorationImage(
                  image: NetworkImage(data['foto_url']),
                  fit: BoxFit.cover,
                ),
              ),
            )
          else
            Container(
              margin: const EdgeInsets.only(bottom: 15),
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Center(
                child: Icon(Icons.image_not_supported, size: 36, color: Colors.grey),
              ),
            ),

          const SizedBox(height: 10),

          // --- TOMBOL-TOMBOL NAVIGASI / EDIT ---
          if (isAdmin && onEditPressed != null) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.edit, color: Colors.white),
                label: const Text("Edit Data Warga", style: TextStyle(fontSize: 15)),
                onPressed: onEditPressed,
              ),
            ),
            const SizedBox(height: 10),
          ],

          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue[800],
                side: BorderSide(color: Colors.blue[800]!, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.map),
              label: const Text("Tampilkan Rute di Aplikasi", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              onPressed: onRoutePressed,
            ),
          ),
          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isAdmin ? Colors.blue[800] : Colors.blue[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.directions, color: Colors.white),
              label: const Text("Navigasi ke Lokasi (Google Maps)", style: TextStyle(fontSize: 15)),
              onPressed: onExternalMapPressed,
            ),
          ),
          const SizedBox(height: 10),
        ],
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
