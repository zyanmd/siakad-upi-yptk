import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../services/api_client.dart';
import '../services/session_store.dart';
import '../state/auth_provider.dart';
import '../state/theme_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Halaman login: NIM + password SIAKAD.
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
        setState(() => _error = 'Sesi Anda berakhir. Silakan login kembali.');
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
        _error = 'Terjadi kesalahan. Periksa koneksi lalu coba lagi.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          children: [
            // ---------- Bagian gradien atas ----------
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: AppColors.headerGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(30)),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -40,
                    top: 30,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.amber.withOpacity(0.13),
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 40, 24, 74),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: AppColors.logoGradient,
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: const Icon(Icons.school_rounded,
                                    size: 31, color: AppColors.indigo950),
                              ),
                              const ThemeModeSwitcher(),
                            ],
                          ),
                          const SizedBox(height: 22),
                          const Text(
                            'SIAKAD\nUPI YPTK',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 27,
                              fontWeight: FontWeight.w900,
                              height: 1.12,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sistem Informasi Akademik Mahasiswa',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ---------- Kartu form ----------
            Transform.translate(
              offset: const Offset(0, -36),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: context.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Masuk',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Gunakan NIM dan password SIAKAD Anda.',
                        style: TextStyle(
                            fontSize: 12.5, color: context.textMuted),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: AppColors.red.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppColors.red.withOpacity(0.25)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  size: 18, color: AppColors.red),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                      fontSize: 12.5,
                                      color: AppColors.red,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      TextField(
                        controller: _nimCtrl,
                        enabled: !_loading,
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.next,
                        decoration: appInput(context, 'NIM',
                            icon: Icons.badge_rounded),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _passCtrl,
                        enabled: !_loading,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        decoration: appInput(
                          context,
                          'Password',
                          icon: Icons.lock_rounded,
                          suffix: IconButton(
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              size: 20,
                              color: context.textMuted,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          onPressed: _loading ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.indigo700,
                            disabledBackgroundColor:
                                AppColors.indigo700.withOpacity(0.65),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 21,
                                  height: 21,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white),
                                )
                              : const Text(
                                  'Login',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800),
                                ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: Text(
                          'Terhubung ke ${ApiConfig.baseUrl}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 10.5, color: context.textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'v1.0.0 - SIAKAD UPI YPTK Scraper API',
              style: TextStyle(fontSize: 10.5, color: context.textMuted),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
