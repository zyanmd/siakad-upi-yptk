import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/session_store.dart';
import '../state/auth_provider.dart';
import '../state/theme_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_update_banner.dart';
import '../widgets/common.dart';

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
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Terjadi kesalahan jaringan. Coba lagi.';
        _loading = false;
      });
    } finally {
      if (mounted && _loading) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Scaffold(
      backgroundColor: context.bg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxHeight < 680;
          final heroHeight = isCompact ? 224.0 : 264.0;

          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ──── HERO HEADER KUNING EMAS MELENGKUNG + OPEN PEEPS MAHASISWA ────
                    ClipPath(
                      clipper: const LoginHeroCurveClipper(),
                      child: Container(
                        height: heroHeight,
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFFE5A620),
                              Color(0xFFD48B08),
                              Color(0xFFB87500),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Stack(
                          children: [
                            const Positioned.fill(
                              child: GoldenHeaderBackdrop(heroMode: true),
                            ),
                            // Ilustrasi Open Peeps Mahasiswa bertumpu rapi di atas lengkungan
                            Positioned(
                              bottom: -2,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Image.asset(
                                  'assets/images/open_peeps_mahasiswa.png',
                                  height: isCompact ? 176 : 210,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            // Bar atas: pill kampus & tombol switcher tema
                            SafeArea(
                              bottom: false,
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 8, 16, 0),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: Colors.white
                                            .withValues(alpha: 0.20),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: 0.30),
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.school_rounded,
                                              size: 14, color: Colors.white),
                                          SizedBox(width: 5),
                                          Text(
                                            'SISFO UPI YPTK',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => context
                                          .read<ThemeProvider>()
                                          .toggleTheme(),
                                      tooltip:
                                          isDark ? 'Mode Terang' : 'Mode Gelap',
                                      icon: Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: 0.22),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white
                                                .withValues(alpha: 0.35),
                                            width: 1,
                                          ),
                                        ),
                                        child: Icon(
                                          isDark
                                              ? Icons.light_mode_rounded
                                              : Icons.dark_mode_rounded,
                                          size: 19,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ──── BAGIAN FORMULIR LOGIN BERSIH ────
                    Expanded(
                      child: SafeArea(
                        top: false,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 440),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Judul & Badge
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'SIAKAD',
                                        style: TextStyle(
                                          fontSize: 27,
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
                                          color: AppColors.primaryYellow
                                              .withValues(alpha: 0.2),
                                          borderRadius:
                                              BorderRadius.circular(7),
                                          border: Border.all(
                                            color: AppColors.primaryYellow
                                                .withValues(alpha: 0.6),
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

                                  const SizedBox(height: 5),
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

                                  const SizedBox(height: 22),

                                  // Banner Pembaruan Aplikasi (bila tersedia update)
                                  const AppUpdateBanner(),

                                  // Banner Peringatan Sesi Kedaluwarsa
                                  Builder(builder: (ctx) {
                                    final expired =
                                        ctx.watch<AuthProvider>().expired;
                                    if (!expired || _error != null) {
                                      return const SizedBox.shrink();
                                    }
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 16),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF59E0B)
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0xFFF59E0B)
                                              .withValues(alpha: 0.35),
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
                                        color: AppColors.red
                                            .withValues(alpha: 0.10),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: AppColors.red
                                              .withValues(alpha: 0.25),
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
                                                color: Colors.black
                                                    .withValues(alpha: 0.03),
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
                                            hintText:
                                                'Nomor Induk Mahasiswa (NIM)',
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
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 15),
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
                                              onPressed: () => setState(
                                                  () => _obscure = !_obscure),
                                              icon: Icon(
                                                _obscure
                                                    ? Icons
                                                        .visibility_off_outlined
                                                    : Icons.visibility_outlined,
                                                size: 20,
                                                color: context.textMuted,
                                              ),
                                            ),
                                            border: InputBorder.none,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 15),
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
                                        backgroundColor:
                                            AppColors.primaryYellow,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        disabledBackgroundColor: AppColors
                                            .primaryYellow
                                            .withValues(alpha: 0.5),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                      ),
                                      child: _loading
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                        Color>(Colors.white),
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
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    child: Text(
                                      'SIAKAD UNOFFICIAL • v1.0.9',
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
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
