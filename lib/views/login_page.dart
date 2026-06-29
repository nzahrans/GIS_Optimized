import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart'; // Tambahkan import ThemeProvider

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final input = _emailController.text.trim();
    final password = _passwordController.text;

    if (input.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Input tidak boleh kosong")),
      );
      return;
    }

    // Konversi NIK menjadi virtual email jika diinput 16 digit angka
    String finalEmail = input;
    final isNik = RegExp(r'^\d{16}$').hasMatch(input);
    if (isNik) {
      finalEmail = '$input@warga.sigbansos.com';
    }

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signIn(finalEmail, password);

    if (mounted) {
      if (success) {
        if (authProvider.role == 'admin') {
          Navigator.pushNamedAndRemoveUntil(context, '/admin_dashboard', (route) => false);
        } else {
          Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authProvider.errorMessage ?? "Login gagal")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    
    // 1. Deteksi apakah mode saat ini adalah mode gelap
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // 2. Siapkan warna teks dinamis mengikuti tema
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSubtitleColor = isDark ? Colors.white.withOpacity(0.6) : const Color(0xFF64748B);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          // TOMBOL TOGGLE TEMA
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            tooltip: 'Ganti Tema',
            onPressed: () {
              // Panggil fungsi toggle dari ThemeProvider
              context.read<ThemeProvider>().toggleTheme(!isDark);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          // 3. Gradient dinamis: Gelap atau Terang
          gradient: LinearGradient(
            colors: isDark 
                ? [const Color(0xFF090D16), const Color(0xFF1E293B)]
                : [const Color(0xFFE2E8F0), const Color(0xFFF8FAFC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    decoration: BoxDecoration(
                      // 4. Latar belakang kontainer kaca (glassmorphism) dinamis
                      color: isDark 
                          ? Colors.white.withOpacity(0.06) 
                          : Colors.white.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark 
                            ? Colors.white.withOpacity(0.12)
                            : Colors.white,
                        width: 1.5,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 76.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo Geometris Minimalis
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isDark
                                  ? [Colors.white.withOpacity(0.12), Colors.white.withOpacity(0.03)]
                                  : [const Color(0xFF3B82F6).withOpacity(0.2), const Color(0xFF3B82F6).withOpacity(0.05)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? Colors.white.withOpacity(0.18) : const Color(0xFF3B82F6).withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            Icons.location_on_rounded,
                            size: 36,
                            color: isDark ? Colors.white : const Color(0xFF3B82F6),
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Nama Aplikasi Dual-tone
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "SIG",
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: textColor,
                                letterSpacing: 0.8,
                              ),
                            ),
                            Text(
                              "AP",
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w300,
                                color: textColor.withOpacity(0.9),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Kepanjangan Aplikasi
                        Text(
                          "Sistem Informasi Geografis Bantuan Penduduk\n RT 02 RW 02 Tegalsari, Sumedang",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: textColor.withOpacity(0.8),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 20),                        
                        // Form Email/NIK
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.text,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            labelText: "Email atau NIK",
                            labelStyle: TextStyle(color: textSubtitleColor),
                            prefixIcon: Icon(Icons.person_outline, color: textSubtitleColor),
                            filled: true,
                            fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.8),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: isDark ? Colors.white.withOpacity(0.1) : Colors.transparent,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Form Password
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            labelText: "Password",
                            labelStyle: TextStyle(color: textSubtitleColor),
                            prefixIcon: Icon(Icons.lock_outline, color: textSubtitleColor),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                color: textSubtitleColor,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            filled: true,
                            fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.8),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: isDark ? Colors.white.withOpacity(0.1) : Colors.transparent,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                          onSubmitted: (_) => _login(),
                        ),
                        const SizedBox(height: 32),
                        
                        // Tombol Masuk
                        Container(
                          width: double.infinity,
                          height: 52,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: authProvider.isLoading
                                ? LinearGradient(
                                    colors: [
                                      const Color(0xFF3B82F6).withOpacity(0.6),
                                      const Color(0xFF2563EB).withOpacity(0.6),
                                    ],
                                  )
                                : const LinearGradient(
                                    colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                            boxShadow: authProvider.isLoading
                                ? null
                                : [
                                    BoxShadow(
                                      color: const Color(0xFF3B82F6).withOpacity(0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: authProvider.isLoading ? null : _login,
                              borderRadius: BorderRadius.circular(16),
                              child: Center(
                                child: authProvider.isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Text(
                                        "Masuk",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white, // Teks tombol tetap putih di kedua mode
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}