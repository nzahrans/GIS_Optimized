import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/firestore_service.dart';
import '../widgets/statistik_card.dart';
import 'form_warga.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Dashboard Admin SIGAP",
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
                  image: const DecorationImage(
                    image: AssetImage('assets/images/logo_light.png'),
                    opacity: 0.1,
                    fit: BoxFit.cover,
                  ),
                ),
                currentAccountPicture: const CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.admin_panel_settings, size: 40, color: Color(0xFF3B82F6)),
                ),
                accountName: const Text(
                  "Administrator",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                accountEmail: Text(authProvider.user?.email ?? 'admin@gis.com'),
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
                  Navigator.pushNamed(context, '/admin_map');
                },
              ),
              ListTile(
                leading: const Icon(Icons.list_alt, color: Colors.grey),
                title: const Text('Monitoring Bantuan'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/admin_monitoring');
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_add, color: Colors.grey),
                title: const Text('Tambah Data Warga'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const FormWargaPage()),
                  );
                },
              ),
              const Divider(),
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
        stream: FirestoreService.getWargaStream(),
        builder: (context, wargaSnapshot) {
          if (wargaSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (wargaSnapshot.hasError) {
            return Center(child: Text("Terjadi kesalahan: ${wargaSnapshot.error}"));
          }

          final wargaDocs = wargaSnapshot.data?.docs ?? [];
          final totalKK = wargaDocs.length;
          final totalTerpetakan = wargaDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['lokasi'] != null;
          }).length;

          final totalPenerima = wargaDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['menerima_bantuan'] == 'Ya';
          }).length;

          return StreamBuilder<QuerySnapshot>(
            stream: FirestoreService.getAllAnggotaStream(),
            builder: (context, anggotaSnapshot) {
              final anggotaDocs = anggotaSnapshot.data?.docs ?? [];
              final totalPenduduk = totalKK + anggotaDocs.length;

              return StreamBuilder<QuerySnapshot>(
                stream: FirestoreService.getAllBantuanAktifStream(),
                builder: (context, bantuanSnapshot) {
                  final bantuanDocs = bantuanSnapshot.data?.docs ?? [];
                  
                  final totalBelumCair = bantuanDocs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return data['status_cair'] == 'Belum Menerima';
                  }).length;

                  final totalSudahCair = bantuanDocs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return data['status_cair'] == 'Sudah Menerima';
                  }).length;

                  final totalDikonfirmasi = bantuanDocs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return data['status_cair'] == 'Dikonfirmasi Warga';
                  }).length;

                  // Hitung jenis bantuan terbanyak
                  final Map<String, int> bantuanCounts = {};
                  for (var doc in bantuanDocs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final jenis = data['jenis_bantuan'] as String? ?? '-';
                    // Bersihkan string dan ambil kata pertamanya (misal: "PKH Periode Juli" -> "PKH")
                    final cleanJenis = jenis.split(' ').first.toUpperCase();
                    if (cleanJenis.isNotEmpty && cleanJenis != '-') {
                      bantuanCounts[cleanJenis] = (bantuanCounts[cleanJenis] ?? 0) + 1;
                    }
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Selamat Datang
                        Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Selamat Datang, Admin!",
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Pantau penyaluran bantuan sosial Padamulya",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Section 1: Quick Actions
                        Row(
                          children: [
                            Expanded(
                              child: _buildActionButton(
                                context: context,
                                label: "Lihat Peta",
                                icon: Icons.map,
                                color: Colors.blue,
                                route: '/admin_map',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildActionButton(
                                context: context,
                                label: "Monitoring",
                                icon: Icons.list_alt,
                                color: Colors.indigo,
                                route: '/admin_monitoring',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildActionButton(
                                context: context,
                                label: "Warga Baru",
                                icon: Icons.person_add,
                                color: Colors.teal,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const FormWargaPage()),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Section 2: Cards Grid
                        Text(
                          "Ringkasan Kependudukan & Bansos",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 12),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 2.2,
                          children: [
                            StatistikCard(
                              title: "Total KK",
                              value: "$totalKK KK",
                              icon: Icons.family_restroom,
                              color: Colors.blue,
                            ),
                            StatistikCard(
                              title: "Total Penduduk",
                              value: "$totalPenduduk Jiwa",
                              icon: Icons.people,
                              color: Colors.indigo,
                            ),
                            StatistikCard(
                              title: "Penerima Bantuan",
                              value: "$totalPenerima Warga",
                              icon: Icons.card_membership,
                              color: Colors.amber,
                            ),
                            StatistikCard(
                              title: "Bantuan Terpetakan",
                              value: "$totalTerpetakan KK",
                              icon: Icons.location_on,
                              color: Colors.orange,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        GridView.count(
                          crossAxisCount: 3,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 1.4,
                          children: [
                            StatistikCard(
                              title: "Belum Cair",
                              value: "$totalBelumCair",
                              icon: Icons.hourglass_empty,
                              color: Colors.red,
                            ),
                            StatistikCard(
                              title: "Sudah Cair",
                              value: "$totalSudahCair",
                              icon: Icons.check_circle_outline,
                              color: Colors.orangeAccent,
                            ),
                            StatistikCard(
                              title: "Konfirmasi",
                              value: "$totalDikonfirmasi",
                              icon: Icons.verified_user,
                              color: Colors.green,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Card Tingkat Konfirmasi Warga
                        Builder(
                          builder: (context) {
                            final totalDisbursed = totalSudahCair + totalDikonfirmasi;
                            final double rate = totalDisbursed > 0 ? (totalDikonfirmasi / totalDisbursed * 100) : 0.0;
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF334155) : Colors.grey[200]!,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Tingkat Konfirmasi Penerimaan Warga",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                                        ),
                                      ),
                                      Text(
                                        "${rate.toStringAsFixed(1)}%",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(5),
                                    child: LinearProgressIndicator(
                                      value: rate / 100,
                                      minHeight: 8,
                                      backgroundColor: isDark ? const Color(0xFF334155) : Colors.grey[200]!,
                                      valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    "Persentase bantuan tersalurkan yang telah diverifikasi dan dikonfirmasi diterima oleh warga.",
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 28),

                        // Section 3: Charts
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Pie Chart Status Bantuan
                            Expanded(
                              flex: 1,
                              child: _buildPieChartCard(
                                title: "Status Penyaluran",
                                belum: totalBelumCair,
                                sudah: totalSudahCair,
                                konfirm: totalDikonfirmasi,
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Bar Chart Jenis Bantuan
                            Expanded(
                              flex: 1,
                              child: _buildBarChartCard(
                                title: "Distribusi Program",
                                data: bantuanCounts,
                                isDark: isDark,
                                theme: theme,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),

                        // Section 4: Preview Penerima Terbaru
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Penerima Bantuan Terbaru",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pushNamed(context, '/admin_monitoring'),
                              child: const Text("Lihat Semua →"),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildRecentWargaList(wargaDocs, isDark, theme),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color color,
    String? route,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 75,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : Colors.grey[200]!,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap ?? () {
            if (route != null) Navigator.pushNamed(context, route);
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPieChartCard({
    required String title,
    required int belum,
    required int sudah,
    required int konfirm,
    required bool isDark,
  }) {
    final int total = belum + sudah + konfirm;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0xFF334155) : Colors.grey[200]!,
        ),
      ),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 16),
            if (total == 0)
              const SizedBox(
                height: 120,
                child: Center(
                  child: Text(
                    "Tidak ada data bantuan",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              )
            else ...[
              SizedBox(
                height: 120,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 30,
                    sections: [
                      PieChartSectionData(
                        color: Colors.red,
                        value: belum.toDouble(),
                        title: '${(belum / total * 100).toStringAsFixed(0)}%',
                        radius: 35,
                        titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      PieChartSectionData(
                        color: Colors.orangeAccent,
                        value: sudah.toDouble(),
                        title: '${(sudah / total * 100).toStringAsFixed(0)}%',
                        radius: 35,
                        titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      PieChartSectionData(
                        color: Colors.green,
                        value: konfirm.toDouble(),
                        title: '${(konfirm / total * 100).toStringAsFixed(0)}%',
                        radius: 35,
                        titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildChartLegend(Colors.red, "Belum", belum),
              _buildChartLegend(Colors.orangeAccent, "Sudah Cair", sudah),
              _buildChartLegend(Colors.green, "Dikonfirmasi", konfirm),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChartLegend(Color color, String label, int value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
          Text("$value", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildBarChartCard({
    required String title,
    required Map<String, int> data,
    required bool isDark,
    required ThemeData theme,
  }) {
    final list = data.entries.toList();
    list.sort((a, b) => b.value.compareTo(a.value));
    final displayList = list.take(3).toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0xFF334155) : Colors.grey[200]!,
        ),
      ),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 16),
            if (displayList.isEmpty)
              const SizedBox(
                height: 120,
                child: Center(
                  child: Text(
                    "Tidak ada data bansos",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              )
            else ...[
              SizedBox(
                height: 120,
                child: BarChart(
                  BarChartData(
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      show: true,
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            int idx = value.toInt();
                            if (idx >= 0 && idx < displayList.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  displayList[idx].key,
                                  style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
                                ),
                              );
                            }
                            return const Text("");
                          },
                        ),
                      ),
                    ),
                    barGroups: List.generate(
                      displayList.length,
                      (index) => BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: displayList[index].value.toDouble(),
                            color: theme.colorScheme.primary,
                            width: 14,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...List.generate(displayList.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(displayList[index].key, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      Text("${displayList[index].value}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecentWargaList(List<QueryDocumentSnapshot> docs, bool isDark, ThemeData theme) {
    // Filter docs yang menerima bantuan dan sort berdasarkan input terbaru jika ada
    final list = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['menerima_bantuan'] == 'Ya';
    }).take(5).toList();

    if (list.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 30),
        alignment: Alignment.center,
        child: const Text("Belum ada warga penerima bantuan sosial.", style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final data = list[index].data() as Map<String, dynamic>;
        final String nama = data['nama'] ?? '';
        final String blok = data['blok'] ?? '-';
        final String fotoUrl = data['foto_url'] ?? '';

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : Colors.grey[200]!,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                backgroundImage: fotoUrl.isNotEmpty ? NetworkImage(fotoUrl) : null,
                child: fotoUrl.isEmpty ? Icon(Icons.person, color: theme.colorScheme.primary) : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nama,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Alamat: $blok",
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
            ],
          ),
        );
      },
    );
  }
}
