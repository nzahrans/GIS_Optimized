import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      
      // Mengarahkan halaman berdasarkan status autentikasi dari AuthProvider
      final authProvider = context.read<AuthProvider>();
      if (authProvider.isLoggedIn) {
        Navigator.pushReplacementNamed(context, '/admin_dashboard');
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, size: 100, color: Colors.blue),
            SizedBox(height: 20),
            Text("GIS BANSOS", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text("Tegalsari", style: TextStyle(fontSize: 16, color: Colors.grey)),
            SizedBox(height: 40),
            CircularProgressIndicator(),
            Spacer(),
            Text("Designed By Naufal Zahran", style: TextStyle(color: Colors.grey)),
            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
