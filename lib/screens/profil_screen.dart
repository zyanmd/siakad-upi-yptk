import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../state/auth_provider.dart';
import '../state/theme_provider.dart';
import '../theme/app_theme.dart';
import '../utils/smart.dart';
import '../widgets/common.dart';
import '../widgets/gradient_header.dart';
import 'profil_akademik_screen.dart';

/// Profil mahasiswa: info akun, pengaturan tema, sesi, dan logout.
class ProfilScreen extends StatefulWidget {
  const ProfilScreen({super.key});

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  Map<String, dynamic>? _profil;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfil();
  }

  Future<void> _loadProfil() async {
    setState(() => _error = null);
    try {
      final api = context.read<ApiClient>();
      final resp = await api.get('/api/akademik/profil');
      final data = resp is Map ? (resp['data'] ?? resp) : resp;
      if (!mounted) return;
      setState(() => _profil = asMap(data));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = errorText(e));
    }
  }

  // ------------------------------------------------------------ aksi

  Future<void> _logout() async {
    final ok = await confirmDialog(
        context, 'Logout', 'Yakin ingin keluar dari aplikasi?');
    if (!ok) return;
    if (!mounted) return;
    await context.read<AuthProvider>().logout();
    // Perpindahan ke login otomatis ditangani listener MainShell.
  }

  // ------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: context.bg,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          GradientHeader(
            title: 'Profil Saya',
            subtitle: 'Informasi akun & pengaturan',
            leading: Navigator.of(context).canPop()
                ? const HeaderBackButton()
                : null,
            tall: true,
            bottom: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: AppColors.logoGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Text(
                    _initials(auth.nama),
                    style: const TextStyle(
                      color: AppColors.indigo950,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        auth.nama,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'NIM ${auth.nim}',
                        style: TextStyle(
                          color: context.textMuted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---------------- info mahasiswa ----------------
                SectionTitle(
                  'Profil Akademik',
                  trailing: TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ProfilAkademikScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded,
                        size: 16, color: AppColors.upiYellowDeep),
                    label: const Text(
                      'Buka Lengkap',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.upiYellowDeep,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SurfaceCard(
                  child: _error != null
                      ? Column(
                          children: [
                            Text(_error!,
                                style: const TextStyle(
                                    fontSize: 12.5, color: AppColors.red)),
                            const SizedBox(height: 8),
                            TextButton(
                                onPressed: _loadProfil,
                                child: const Text('Muat ulang')),
                          ],
                        )
                      : _profil == null
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 18),
                              child: LoadingView(label: 'Memuat profil...'),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppColors.upiYellowDeep
                                            .withValues(alpha: 0.12),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.school_rounded,
                                        color: AppColors.upiYellowDeep,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            pickString(
                                                asMap(_profil!['akademik']),
                                                [
                                                  'program_studi',
                                                  'prodi',
                                                  'Program Studi'
                                                ],
                                                'Program Studi Mahasiswa'),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            pickString(
                                                asMap(_profil!['akademik']),
                                                ['fakultas', 'Fakultas'],
                                                'Universitas Putra Indonesia YPTK'),
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: context.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                const Divider(height: 1),
                                const SizedBox(height: 10),
                                KeyValueRow(
                                  label: 'NIM',
                                  value: pickString(
                                      asMap(_profil!['akademik']),
                                      ['nim', 'NIM'],
                                      auth.nim),
                                ),
                                KeyValueRow(
                                  label: 'Dosen Pembimbing (PA)',
                                  value: pickString(
                                      asMap(_profil!['pa']),
                                      ['nama', 'Nama'],
                                      'Dalam proses'),
                                ),
                                KeyValueRow(
                                  label: 'Status Kemahasiswaan',
                                  value: pickString(
                                      asMap(_profil!['akademik']),
                                      ['status', 'Status'],
                                      'Aktif'),
                                ),
                                KeyValueRow(
                                  label: 'Email',
                                  value: pickString(
                                      asMap(_profil!['kontak']),
                                      ['email', 'Email'],
                                      '-'),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const ProfilAkademikScreen(),
                                      ),
                                    ),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.upiYellowDeep,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 11),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                    ),
                                    icon: const Icon(
                                        Icons.assignment_ind_rounded,
                                        size: 18),
                                    label: const Text(
                                      'Lihat Biodata & Riwayat Lengkap',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                ),
                const SizedBox(height: 20),

                // ---------------- pengaturan ----------------
                const SectionTitle('Tampilan'),
                const SizedBox(height: 10),
                const SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.brightness_6_rounded,
                              size: 20, color: AppColors.indigo500),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text('Mode Tampilan',
                                style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ThemeModeSwitcher(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                const SizedBox(height: 22),

                // ---------------- logout ----------------
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _logout,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.red.withValues(alpha: 0.10),
                      foregroundColor: AppColors.red,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      side: BorderSide(
                          color: AppColors.red.withValues(alpha: 0.3)),
                    ),
                    icon: const Icon(Icons.logout_rounded, size: 19),
                    label: const Text('Logout',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    'SIAKAD UNOFFICIAL • v1.0.0',
                    style: TextStyle(fontSize: 11, color: context.textMuted, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 96),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String nama) {
    final parts =
        nama.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    return parts.first.substring(0, 1).toUpperCase();
  }
}
