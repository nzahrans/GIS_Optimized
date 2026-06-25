import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

// Import providers
import 'providers/auth_provider.dart';
import 'providers/warga_provider.dart';
import 'providers/map_provider.dart';

// Import views
import 'views/splash_screen.dart';
import 'views/user_home.dart';
import 'views/login_page.dart';
import 'views/admin_home.dart';

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
      ],
      child: MaterialApp(
        title: 'GIS Bansos Tegalsari',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1E3A8A),
            primary: const Color(0xFF1E3A8A),
            secondary: const Color(0xFFF59E0B),
            background: const Color(0xFFF8FAFC),
          ),
          useMaterial3: true,
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFFF1F5F9),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 1.8),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
            floatingLabelStyle: const TextStyle(color: Color(0xFF1E3A8A), fontWeight: FontWeight.w600),
          ),
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashScreen(),
          '/home': (context) => const UserHomePage(),
          '/login': (context) => const LoginPage(),
          '/admin_dashboard': (context) => const AdminHomePage(),
        },
      ),
    );
  }
}
