import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'user_home.dart';
import 'admin_home.dart';

class SearchResultsPage extends StatelessWidget {
  final String query;
  final bool isAdmin;

  const SearchResultsPage({super.key, required this.query, this.isAdmin = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hasil: "$query"'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('warga').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          var allDocs = snapshot.data!.docs;
          var filteredDocs = allDocs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            String namaWarga = (data['nama'] ?? '').toString().toLowerCase();
            return namaWarga.contains(query.toLowerCase());
          }).toList();

          if (filteredDocs.isEmpty) {
            return const Center(child: Text("Data tidak ditemukan"));
          }

          return ListView.builder(
            itemCount: filteredDocs.length,
            itemBuilder: (context, index) {
              var doc = filteredDocs[index];
              var data = doc.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isAdmin ? Colors.red[100] : Colors.blue[100],
                    child: Icon(Icons.person, color: isAdmin ? Colors.red : Colors.blue),
                  ),
                  title: Text(data['nama'] ?? 'Tanpa Nama', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: isAdmin
                      ? Text("NIK: ${data['nik']}\nStatus: ${data['status_cair']}")
                      : (data['blok'] != null && data['blok'] != '') ? Text("Blok: ${data['blok']}") : null,
                  isThreeLine: isAdmin,
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    _showDetailDialog(context, data, doc.id);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showDetailDialog(BuildContext context, Map<String, dynamic> data, String docId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(data['nama'] ?? 'Detail Warga'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isAdmin) ...[
                  _detailRow("NIK", data['nik']),
                  _detailRow("No. KK", data['no_kk']),
                  _detailRow("Blok", data['blok']),
                  const Divider(),
                  _detailRow("Menerima Bantuan?", data['menerima_bantuan']),
                  if (data['menerima_bantuan'] == 'Ya') ...[
                    _detailRow("Jenis Bantuan", data['jenis_bantuan']),
                    _detailRow("Status Cair", data['status_cair']),
                  ]
                ] else ...[
                  _detailRow("Blok/Gang", data['blok']),
                ],
                const SizedBox(height: 10),
                if (data['foto_url'] != null && data['foto_url'] != '')
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(data['foto_url'], height: 150, width: double.infinity, fit: BoxFit.cover),
                  ),
              ],
            ),
          ),
          actions: [
            if (data['lokasi'] != null)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                icon: const Icon(Icons.map, size: 18),
                label: const Text("Lihat di Peta"),
                onPressed: () {
                  Navigator.pop(context); // Tutup Dialog

                  GeoPoint geoPoint = data['lokasi'];
                  LatLng targetLocation = LatLng(geoPoint.latitude, geoPoint.longitude);

                  if (isAdmin) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AdminHomePage(
                          centerOnLocation: targetLocation,
                          highlightDocId: docId,
                        ),
                      ),
                    );
                  } else {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UserHomePage(
                          centerOnLocation: targetLocation,
                          highlightDocId: docId,
                        ),
                      ),
                    );
                  }
                },
              ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Tutup")),
          ],
        );
      },
    );
  }

  Widget _detailRow(String label, dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12))),
          Expanded(child: Text(value?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
