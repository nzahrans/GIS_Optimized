import 'package:flutter/material.dart';

class AppTheme {
  // Palet Warna Mode Terang
  static final lightTheme = ThemeData(
    scaffoldBackgroundColor: const Color(0xFFF8FAFC), // Warna background abu-abu sangat muda
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF3B82F6),     // Biru utama SIGAP
      secondary: Color(0xFF2563EB),   // Biru gelap
      surface: Colors.white,          // Background card/container
      onSurface: Color(0xFF1E293B),   // Teks utama (gelap)
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF3B82F6),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
  );

  // Palet Warna Mode Gelap (Menggunakan warna yang sudah kamu pakai sebelumnya)
  static final darkTheme = ThemeData(
    scaffoldBackgroundColor: const Color(0xFF090D16), // Background gelap utama
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF3B82F6),
      secondary: Color(0xFF2563EB),
      surface: Color(0xFF1E293B),     // Background card/container gelap
      onSurface: Colors.white,        // Teks utama (putih)
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF090D16),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    iconTheme: const IconThemeData(color: Colors.white70),
  );
}