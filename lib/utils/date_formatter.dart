import 'package:cloud_firestore/cloud_firestore.dart';

class DateFormatter {
  /// Mengubah objek Timestamp atau DateTime menjadi String tanggal berformat Indonesia.
  /// Contoh output: "Jumat, 26 Juni 2026 08:42 WIB"
  static String formatIndonesianDate(dynamic rawDate) {
    if (rawDate == null) return '-';
    DateTime? dt;
    if (rawDate is Timestamp) {
      dt = rawDate.toDate();
    } else if (rawDate is DateTime) {
      dt = rawDate;
    }
    if (dt == null) return '-';

    final months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    final days = [
      'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'
    ];

    String dayName = days[dt.weekday - 1];
    String day = dt.day.toString();
    String monthName = months[dt.month - 1];
    String year = dt.year.toString();
    String hour = dt.hour.toString().padLeft(2, '0');
    String minute = dt.minute.toString().padLeft(2, '0');

    return "$dayName, $day $monthName $year $hour:$minute WIB";
  }
}
