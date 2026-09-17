import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_provider.dart';
import '../theme/app_theme.dart';

/// Splash: cek sesi tersimpan lalu arahkan ke Beranda atau Login.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  Future<void> _route() async {
    final auth = context.read<AuthProvider>();
    await Future.delayed(const Duration(milliseconds: 800));
    await auth.bootstrap();
    if (!mounted) return;
    Navigator.of(context)
        .pushReplacementNamed(auth.isAuthed ? '/home' : '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: AppColors.headerGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -50,
              top: 90,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.amber.withOpacity(0.13),
                ),
              ),
            ),
            Positioned(
              left: -40,
              bottom: 60,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: AppColors.logoGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.amber.withOpacity(0.35),
                          blurRadius: 28,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.school_rounded,
                        size: 46, color: AppColors.indigo950),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'SIAKAD UPI YPTK',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sistem Informasi Akademik',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 40),
                  const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      color: AppColors.amber,
                      strokeWidth: 2.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
