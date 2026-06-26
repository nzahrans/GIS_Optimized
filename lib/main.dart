import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

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

// Import utils
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const SIGBansosApp());
}

class SIGBansosApp extends StatelessWidget {
  const SIGBansosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => WargaProvider()),
        ChangeNotifierProvider(create: (_) => MapProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()), // Provider Tema
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
              '/admin_dashboard': (context) => const AdminHomePage(),
            },
          );
        },
      ),
    );
  }
}