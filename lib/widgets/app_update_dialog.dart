import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart' show appNavigatorKey;

import '../services/app_update_service.dart';
import '../theme/app_theme.dart';

/// Menampilkan pop up pembaruan aplikasi.
///
/// - [AppUpdateStatus.force]  → dialog tidak bisa ditutup (tanpa tombol nanti).
/// - [AppUpdateStatus.optional] → ada tombol "Nanti" untuk menunda.
///
/// Mengembalikan `true` bila pengguna memilih menunda (opsional), sehingga
/// pemanggil bisa menyimpan versi yang di-skip.
Future<bool> showAppUpdateDialog(
  BuildContext context, {
  required AppUpdateInfo info,
}) async {
  final targetContext = appNavigatorKey.currentContext ?? context;
  final force = info.status == AppUpdateStatus.force;
  final result = await showDialog<bool>(
    context: targetContext,
    barrierDismissible: !force,
    builder: (ctx) => PopScope(
      canPop: !force,
      child: _AppUpdateDialog(info: info, force: force),
    ),
  );
  // Dialog force tidak punya aksi tutup, jadi result hanya true saat menunda.
  return result == true;
}

class _AppUpdateDialog extends StatelessWidget {
  const _AppUpdateDialog({required this.info, required this.force});

  final AppUpdateInfo info;
  final bool force;

  Future<void> _openStore() async {
    final url = info.downloadUrl.trim();
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Diabaikan; tidak bisa membuka tautan unduhan.
    }
  }

  Future<void> _openGitHub() async {
    final url = (info.githubUrl ?? 'https://github.com/zyanmd/siakad-upi-yptk').trim();
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final accent = force ? AppColors.red : AppColors.primaryYellow;
    final title = info.title.trim().isEmpty
        ? (force ? 'Wajib Diperbarui' : 'Pembaruan Tersedia')
        : info.title.trim();

    return Dialog(
      backgroundColor: context.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(
                force
                    ? Icons.system_update_rounded
                    : Icons.update_rounded,
                size: 32,
                color: accent,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              info.message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: context.textMuted,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: context.softFill,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _verPill(context, 'Saat ini', info.currentVersion ?? '-'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(Icons.arrow_forward_rounded,
                        size: 16, color: context.textMuted),
                  ),
                  _verPill(context, 'Terbaru', info.latestVersion,
                      highlight: true),
                ],
              ),
            ),
            if (force) ...[
              const SizedBox(height: 12),
              const Text(
                'Anda harus memperbarui untuk melanjutkan.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.red,
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _openStore,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.download_rounded,
                        size: 19, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      'Unduh Pembaruan',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: force ? Colors.white : context.primaryContrast,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (info.githubUrl != null && info.githubUrl!.isNotEmpty) ...[
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                height: 38,
                child: TextButton.icon(
                  onPressed: _openGitHub,
                  icon: Icon(Icons.open_in_new_rounded,
                      size: 15, color: context.textMuted),
                  label: Text(
                    'Lihat Rilis di GitHub',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: context.textMuted,
                    ),
                  ),
                ),
              ),
            ],
            if (!force) ...[
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                height: 38,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(
                    'Nanti Saja',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: context.textMuted,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _verPill(BuildContext context, String label, String value,
      {bool highlight = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: context.textMuted)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: highlight ? AppColors.green : context.textPrimary,
          ),
        ),
      ],
    );
  }
}

