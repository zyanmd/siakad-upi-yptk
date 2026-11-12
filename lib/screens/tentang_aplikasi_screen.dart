import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_update_provider.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';
import '../widgets/app_update_dialog.dart';
import '../widgets/common.dart';
import '../widgets/gradient_header.dart';

/// Halaman Informasi Lengkap Tentang Aplikasi SIAKAD UNOFFICIAL & Kontak Pengembang.
class TentangAplikasiScreen extends StatelessWidget {
  const TentangAplikasiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          GradientHeader(
            title: context.tr('about_section', 'Tentang Aplikasi'),
            subtitle: context.tr('about_app_desc', 'Informasi versi & pengembang'),
            leading: const HeaderBackButton(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Kartu Identitas Aplikasi
                SurfaceCard(
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.amber, AppColors.upiYellowDeep],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.upiYellowDeep.withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.school_rounded,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'SIAKAD',
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: AppColors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: AppColors.amber.withValues(alpha: 0.3)),
                            ),
                            child: const Text(
                              'UNOFFICIAL',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.upiYellowDeep,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Versi 1.0.9 (Modern Edition)',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: context.textMuted,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Divider(height: 1),
                      const SizedBox(height: 14),
                      Text(
                        context.tr('unofficial_desc'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: context.textMuted,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 2. Keunggulan & Fitur Aplikasi
                SectionTitle(context.isEnglish ? 'Key Features' : 'Fitur Unggulan'),
                const SizedBox(height: 10),
                SurfaceCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Column(
                    children: [
                      _buildFeatureTile(
                        context,
                        icon: Icons.auto_awesome_rounded,
                        color: AppColors.upiYellowDeep,
                        title: context.isEnglish
                            ? 'AI Assistant & Helpdesk'
                            : 'Asisten AI & Bantuan SISFO',
                        desc: context.isEnglish
                            ? 'Floating bubble with AI consultation and routing'
                            : 'Widget mengambang dengan konsultasi pintar & eskalasi prodi',
                      ),
                      const Divider(height: 1),
                      _buildFeatureTile(
                        context,
                        icon: Icons.phone_android_rounded,
                        color: AppColors.indigo500,
                        title: context.isEnglish
                            ? 'Modern & Clean Experience'
                            : 'Antarmuka Modern & Bersih',
                        desc: context.isEnglish
                            ? 'Clean typography, responsive layout, and intuitive flow'
                            : 'Tipografi rapi, tata letak responsif, & navigasi mulus',
                      ),
                      const Divider(height: 1),
                      _buildFeatureTile(
                        context,
                        icon: Icons.security_rounded,
                        color: AppColors.green,
                        title: context.isEnglish
                            ? 'Fast & Secure Session'
                            : 'Akses Cepat & Aman',
                        desc: context.isEnglish
                            ? 'Connected to SIAKAD UPI YPTK unofficially'
                            : 'Terhubung ke SIAKAD UPI YPTK secara tidak resmi',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 3. Kontak Pengembang (Clean Button Link)
                SectionTitle(context.isEnglish ? 'Developer Support' : 'Dukungan Pengembang'),
                const SizedBox(height: 10),
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('developer_sub',
                            'Kritik, saran, atau laporan kendala'),
                        style: TextStyle(
                          fontSize: 12.5,
                          color: context.textMuted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Clean Link Button Tanpa Menampilkan Nama
                      IosBounceTap(
                        onTap: () =>
                            openExternal(context, 'https://t.me/rhandev'),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 13),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2AABEE), Color(0xFF229ED9)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF229ED9)
                                    .withValues(alpha: 0.30),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                                size: 19,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                context.tr('developer_contact',
                                    'Hubungi Pengembang via Telegram'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.open_in_new_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () async {
                          final provider = context.read<AppUpdateProvider>();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Memeriksa update terbaru...'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                          await provider.maybeCheck(force: true);
                          if (!context.mounted) return;
                          final info = provider.pending;
                          if (info != null) {
                            showAppUpdateDialog(context, info: info);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Aplikasi sudah menggunakan versi terbaru (v1.0.9).'),
                              ),
                            );
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            color: context.softFill,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: context.border,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.sync_rounded,
                                color: context.primary,
                                size: 19,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                context.tr('check_update_btn', 'Periksa Pembaruan Aplikasi'),
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Footer Clean
                Center(
                  child: Text(
                    'SIAKAD UNOFFICIAL • Modern Edition v1.0.9',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureTile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.textMuted,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
