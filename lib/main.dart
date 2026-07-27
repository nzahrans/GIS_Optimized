import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'package:shared_preferences/shared_preferences.dart';

// Import providers
import 'providers/auth_provider.dart';
import 'providers/warga_provider.dart';
import 'providers/map_provider.dart';
import 'providers/theme_provider.dart';

// Import views
import 'views/splash_screen.dart';
import 'views/user_home.dart';
import 'views/login_page.dart';
import 'views/admin_home.dart';
import 'views/admin_dashboard.dart';
import 'views/user_dashboard.dart';
import 'views/transparansi_bantuan.dart';
import 'views/monitoring_bantuan.dart';

// Import utils
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  final prefs = await SharedPreferences.getInstance();
  final themeIndex = prefs.getInt('theme_mode');
  runApp(SIGBansosApp(themeIndex: themeIndex));
}

class SIGBansosApp extends StatelessWidget {
  final int? themeIndex;
  const SIGBansosApp({super.key, this.themeIndex});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => WargaProvider()),
        ChangeNotifierProvider(create: (_) => MapProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider(themeIndex)), // Provider Tema dengan initial index
      ],
      // Gunakan Consumer agar MaterialApp bisa "mendengarkan" perubahan dari ThemeProvider
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'SIGAP Tegalsari',
            debugShowCheckedModeBanner: false,
            
            // --- KONFIGURASI TEMA DINAMIS ---
            themeMode: themeProvider.themeMode, // Mengikuti settingan (terang/gelap/sistem)
            theme: AppTheme.lightTheme,         // Konfigurasi dari app_theme.dart
            darkTheme: AppTheme.darkTheme,      // Konfigurasi dari app_theme.dart
            
            initialRoute: '/',
            routes: {
              '/': (context) => const SplashScreen(),
              '/home': (context) => const UserHomePage(),
              '/login': (context) => const LoginPage(),
              '/admin_dashboard': (context) => const AdminDashboardPage(),
              '/admin_map': (context) => const AdminHomePage(),
              '/admin_monitoring': (context) => const MonitoringBantuanPage(),
              '/user_dashboard': (context) => const UserDashboardPage(),
              '/transparansi': (context) => const TransparansiBantuanPage(),
            },
          );
        },
      ),
    );
  }
}