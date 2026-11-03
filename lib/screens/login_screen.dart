import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/session_store.dart';
import '../state/auth_provider.dart';
import '../state/theme_provider.dart';
import '../theme/app_theme.dart';
import '../state/app_update_provider.dart';
import '../widgets/app_update_banner.dart';

/// Halaman login bersih, rapi, dan modern.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nimCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final store = context.read<SessionStore>();
      if (store.usernameCached.isNotEmpty) {
        _nimCtrl.text = store.usernameCached;
      }
      context.read<AppUpdateProvider>().maybeCheck();
      final auth = context.read<AuthProvider>();
      if (auth.expired) {
        setState(() => _error = 'Sesi Anda berakhir. Silakan masuk kembali.');
        auth.expired = false;
      }
    });
  }

  @override
  void dispose() {
    _nimCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final nim = _nimCtrl.text.trim();
    final pass = _passCtrl.text;
    if (nim.isEmpty || pass.isEmpty) {
      setState(() => _error = 'NIM dan password wajib diisi.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().login(nim, pass);
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Terjadi kesalahan jaringan. Coba lagi.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      // Bar atas: Tombol Switcher Tema minimalis di pojok kanan (tidak mengganggu)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            onPressed: () =>
                                context.read<ThemeProvider>().toggleTheme(),
                            tooltip: isDark ? 'Mode Terang' : 'Mode Gelap',
                            icon: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: context.card,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: context.border,
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                isDark
                                    ? Icons.light_mode_rounded
                                    : Icons.dark_mode_rounded,
                                size: 19,
                                color: isDark
                                    ? AppColors.primaryYellow
                                    : const Color(0xFF1C1917),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Logo & Identitas Aplikasi Bergaya Apple Squircle
                      Center(
                        child: Container(
                          width: 82,
                          height: 82,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: AppColors.logoGradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryYellow.withValues(alpha: 0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.school_rounded,
                            size: 44,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      const SizedBox(height: 22),

                      // Judul & Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'SIAKAD',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                              color: context.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: AppColors.primaryYellow.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(
                                color: AppColors.primaryYellow.withValues(alpha: 0.6),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              'UNOFFICIAL',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: context.primaryContrast,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),
                      Text(
                        'Universitas Putra Indonesia YPTK Padang',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Portal Layanan Akademik & Kemahasiswaan',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: context.textMuted,
                          letterSpacing: -0.2,
                        ),
                      ),

                      const SizedBox(height: 36),

                      // Banner Pembaruan Aplikasi (bila tersedia update)
                      const AppUpdateBanner(),

                      // Banner Peringatan Sesi Kedaluwarsa
                      Builder(builder: (ctx) {
                        final expired = ctx.watch<AuthProvider>().expired;
                        if (!expired || _error != null) return const SizedBox.shrink();
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                              width: 1,
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                size: 19,
                                color: Color(0xFFD97706),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Sesi Anda telah berakhir atau tidak valid. Silakan login kembali.',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFFB45309),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      // Pesan Error jika ada
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.red.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.red.withValues(alpha: 0.25),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 18,
                                color: AppColors.red,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.red,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],

                      // Formulir Masuk: Container Card Bersih (NIM & Password)
                      Container(
                        decoration: BoxDecoration(
                          color: context.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: context.border,
                            width: 1,
                          ),
                          boxShadow: context.isDark
                              ? null
                              : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                        ),
                        child: Column(
                          children: [
                            // Input NIM
                            TextField(
                              controller: _nimCtrl,
                              enabled: !_loading,
                              keyboardType: TextInputType.text,
                              textInputAction: TextInputAction.next,
                              style: TextStyle(
                                fontSize: 15,
                                color: context.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Nomor Induk Mahasiswa (NIM)',
                                hintStyle: TextStyle(
                                  color: context.textMuted,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                ),
                                prefixIcon: Icon(
                                  Icons.badge_outlined,
                                  size: 20,
                                  color: context.textMuted,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 15),
                              ),
                            ),

                            // Garis pemisah
                            Divider(
                              height: 1,
                              thickness: 1,
                              indent: 48,
                              color: context.border,
                            ),

                            // Input Password
                            TextField(
                              controller: _passCtrl,
                              enabled: !_loading,
                              obscureText: _obscure,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _submit(),
                              style: TextStyle(
                                fontSize: 15,
                                color: context.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Password SIAKAD',
                                hintStyle: TextStyle(
                                  color: context.textMuted,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                ),
                                prefixIcon: Icon(
                                  Icons.lock_outline_rounded,
                                  size: 20,
                                  color: context.textMuted,
                                ),
                                suffixIcon: IconButton(
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 20,
                                    color: context.textMuted,
                                  ),
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 15),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Tombol Masuk Utama
                      SizedBox(
                        height: 50,
                        child: FilledButton(
                          onPressed: _loading ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primaryYellow,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            disabledBackgroundColor:
                                AppColors.primaryYellow.withValues(alpha: 0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Masuk',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.3,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),

                      const Spacer(),

                      // Footer iOS Footnote
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Text(
                          'SIAKAD UNOFFICIAL • v1.0.2',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: context.textMuted,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
