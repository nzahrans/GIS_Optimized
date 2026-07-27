import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/firestore_service.dart';

class TransparansiBantuanPage extends StatefulWidget {
  const TransparansiBantuanPage({super.key});

  @override
  State<TransparansiBantuanPage> createState() => _TransparansiBantuanPageState();
}

class _TransparansiBantuanPageState extends State<TransparansiBantuanPage> {
  String _searchQuery = "";
  final _searchController = TextEditingController();
  String? _selectedProgram;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Transparansi Penyaluran",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirestoreService.getAllBantuanAktifStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Terjadi kesalahan: ${snapshot.error}"));
          }

          final docs = snapshot.data?.docs ?? [];
          
          // Agregasi data bantuan
          final Map<String, Map<String, int>> agregasi = {};
          
          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final String jenis = data['jenis_bantuan'] ?? '-';
            final String status = data['status_cair'] ?? 'Belum Menerima';

            if (jenis == '-' || jenis.isEmpty) continue;

            if (!agregasi.containsKey(jenis)) {
              agregasi[jenis] = {
                'total': 0,
                'belum': 0,
                'sudah': 0,
                'konfirm': 0,
              };
            }

            agregasi[jenis]!['total'] = agregasi[jenis]!['total']! + 1;
            if (status == 'Sudah Menerima') {
              agregasi[jenis]!['sudah'] = agregasi[jenis]!['sudah']! + 1;
            } else if (status == 'Dikonfirmasi Warga') {
              agregasi[jenis]!['konfirm'] = agregasi[jenis]!['konfirm']! + 1;
            } else {
              agregasi[jenis]!['belum'] = agregasi[jenis]!['belum']! + 1;
            }
          }

          // Filter berdasarkan pencarian
          final filteredKeys = agregasi.keys.where((key) {
            return key.toLowerCase().contains(_searchQuery.toLowerCase());
          }).toList();

          // Jika program yang dipilih tidak ada lagi di list, reset pilihan
          if (_selectedProgram != null && !agregasi.containsKey(_selectedProgram)) {
            _selectedProgram = null;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Box Privasi
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.blue[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : Colors.blue[100]!,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: isDark ? Colors.blue[400] : Colors.blue[800]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Halaman ini menampilkan data agregat real-time penyaluran bantuan di RT 02 / RW 02 Tegalsari. Identitas penerima disembunyikan untuk menjaga privasi warga.",
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: isDark ? Colors.grey[350] : Colors.blue[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: "Cari Program Bantuan (e.g. PKH, BPNT)",
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = "";
                              });
                            },
                          )
                        : null,
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim();
                    });
                  },
                ),
                const SizedBox(height: 24),

                Text(
                  "Daftar Program Penyaluran",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 12),

                if (filteredKeys.isEmpty)
                  Container(
                    height: 150,
                    alignment: Alignment.center,
                    child: const Text("Tidak ada program bantuan yang sesuai.", style: TextStyle(color: Colors.grey)),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredKeys.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final String program = filteredKeys[index];
                      final data = agregasi[program]!;
                      final int total = data['total']!;
                      final int belum = data['belum']!;
                      final int sudah = data['sudah']!;
                      final int konfirm = data['konfirm']!;

                      final double pctBelum = total > 0 ? (belum / total) : 0.0;
                      final double pctSudah = total > 0 ? (sudah / total) : 0.0;
                      final double pctKonfirm = total > 0 ? (konfirm / total) : 0.0;

                      final isSelected = _selectedProgram == program;

                      return Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : (isDark ? const Color(0xFF334155) : Colors.grey[200]!),
                            width: isSelected ? 1.8 : 1.0,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedProgram = null;
                                } else {
                                  _selectedProgram = program;
                                }
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          program,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                      ),
                                      Text(
                                        "$total Penerima",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  
                                  // Multi-color progress bar
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: SizedBox(
                                      height: 10,
                                      width: double.infinity,
                                      child: Row(
                                        children: [
                                          if (pctKonfirm > 0)
                                            Expanded(
                                              flex: (pctKonfirm * 100).toInt(),
                                              child: Container(color: Colors.green),
                                            ),
                                          if (pctSudah > 0)
                                            Expanded(
                                              flex: (pctSudah * 100).toInt(),
                                              child: Container(color: Colors.orangeAccent),
                                            ),
                                          if (pctBelum > 0)
                                            Expanded(
                                              flex: (pctBelum * 100).toInt(),
                                              child: Container(color: Colors.red),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),

                                  // Legend
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      _buildStatItem("🔴 Belum Cair", belum, pctBelum),
                                      _buildStatItem("🟡 Sudah Cair", sudah, pctSudah),
                                      _buildStatItem("🟢 Dikonfirmasi", konfirm, pctKonfirm),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                
                // Section 3: Visual Chart (Pie Chart) untuk Program yang Terpilih
                if (_selectedProgram != null) ...[
                  const SizedBox(height: 28),
                  Text(
                    "Visualisasi Penyaluran: $_selectedProgram",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildPieChartSection(agregasi[_selectedProgram!]!, isDark),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatItem(String label, int count, double pct) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          "$count (${(pct * 100).toStringAsFixed(0)}%)",
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildPieChartSection(Map<String, int> data, bool isDark) {
    final int belum = data['belum']!;
    final int sudah = data['sudah']!;
    final int konfirm = data['konfirm']!;
    final int total = data['total']!;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey[200]!),
      ),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: SizedBox(
                height: 140,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 35,
                    sections: [
                      PieChartSectionData(
                        color: Colors.red,
                        value: belum.toDouble(),
                        title: belum > 0 ? '$belum' : '',
                        radius: 30,
                        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      PieChartSectionData(
                        color: Colors.orangeAccent,
                        value: sudah.toDouble(),
                        title: sudah > 0 ? '$sudah' : '',
                        radius: 30,
                        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      PieChartSectionData(
                        color: Colors.green,
                        value: konfirm.toDouble(),
                        title: konfirm > 0 ? '$konfirm' : '',
                        radius: 30,
                        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 1,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLegendRow(Colors.red, "Belum Cair", belum, total),
                  const SizedBox(height: 8),
                  _buildLegendRow(Colors.orangeAccent, "Sudah Cair (RT)", sudah, total),
                  const SizedBox(height: 8),
                  _buildLegendRow(Colors.green, "Dikonfirmasi Warga", konfirm, total),
                  const Divider(height: 20),
                  Text(
                    "Total Sasaran: $total KK",
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendRow(Color color, String label, int value, int total) {
    final double pct = total > 0 ? (value / total * 100) : 0.0;
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            "$label ($value)",
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          "${pct.toStringAsFixed(0)}%",
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
      ],
    );
  }
}
