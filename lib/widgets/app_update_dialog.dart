import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart' show appNavigatorKey;
import '../services/app_update_service.dart';
import '../theme/app_theme.dart';

/// Menampilkan pop up pembaruan aplikasi dengan unduhan langsung di dalam aplikasi (In-App Download & Install).
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
  return result == true;
}

class _AppUpdateDialog extends StatefulWidget {
  const _AppUpdateDialog({required this.info, required this.force});

  final AppUpdateInfo info;
  final bool force;

  @override
  State<_AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<_AppUpdateDialog> {
  bool _downloading = false;
  bool _downloaded = false;
  double _progress = 0.0;
  String _statusText = '';
  String? _downloadedPath;
  String? _error;
  CancelToken? _cancelToken;

  @override
  void dispose() {
    _cancelToken?.cancel('Dialog ditutup.');
    super.dispose();
  }

  Future<void> _startDownload() async {
    setState(() {
      _downloading = true;
      _downloaded = false;
      _progress = 0.0;
      _error = null;
      _statusText = 'Menghubungkan ke server...';
    });

    try {
      final dir = await getTemporaryDirectory();
      final savePath = '${dir.path}/siakad_v${widget.info.latestVersion}.apk';

      // Bersihkan file lama jika ada
      final file = File(savePath);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }

      final url = widget.info.downloadUrl.trim();
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(minutes: 5),
        followRedirects: true,
      ));

      _cancelToken = CancelToken();

      await dio.download(
        url,
        savePath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (!mounted) return;
          if (total > 0) {
            setState(() {
              _progress = (received / total).clamp(0.0, 1.0);
              final recMB = (received / (1024 * 1024)).toStringAsFixed(1);
              final totMB = (total / (1024 * 1024)).toStringAsFixed(1);
              final pct = (_progress * 100).toInt();
              _statusText = 'Mengunduh: $recMB / $totMB MB ($pct%)';
            });
          } else {
            setState(() {
              final recMB = (received / (1024 * 1024)).toStringAsFixed(1);
              _statusText = 'Mengunduh: $recMB MB...';
            });
          }
        },
      );

      if (!mounted) return;

      setState(() {
        _downloading = false;
        _downloaded = true;
        _downloadedPath = savePath;
        _progress = 1.0;
        _statusText = 'Unduhan selesai! Membuka installer...';
      });

      // Langsung buka installer APK di Android
      await _installApk(savePath);
    } catch (e) {
      if (!mounted) return;
      if (e is DioException && CancelToken.isCancel(e)) return;
      setState(() {
        _downloading = false;
        _error = 'Unduhan gagal. Pastikan koneksi internet stabil.';
        _statusText = '';
      });
    }
  }

  Future<void> _installApk(String path) async {
    try {
      final result = await OpenFilex.open(
        path,
        type: 'application/vnd.android.package-archive',
      );
      if (result.type != ResultType.done && mounted) {
        setState(() {
          _statusText = 'Ketuk "Pasang Sekarang" untuk melanjutkan.';
        });
      }
    } catch (e) {
      debugPrint('[UpdateDialog] Error membuka installer: $e');
    }
  }

  Future<void> _openExternalBrowser() async {
    final url = widget.info.downloadUrl.trim();
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final force = widget.force;
    final info = widget.info;
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
            // Ikon Header
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _downloaded
                    ? Icons.check_circle_rounded
                    : (_downloading
                        ? Icons.cloud_download_rounded
                        : (force
                            ? Icons.system_update_rounded
                            : Icons.rocket_launch_rounded)),
                size: 32,
                color: _downloaded ? AppColors.green : accent,
              ),
            ),
            const SizedBox(height: 16),

            // Judul
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

            // Pesan changelog
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 140),
              child: SingleChildScrollView(
                child: Text(
                  info.message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: context.textMuted,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Indikator Versi
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

            // Status Progress Unduhan di dalam Aplikasi
            if (_downloading || _downloaded || _statusText.isNotEmpty) ...[
              const SizedBox(height: 16),
              if (_downloading) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    minHeight: 7,
                    backgroundColor: context.softFill,
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                _statusText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _downloaded ? AppColors.green : context.textPrimary,
                ),
              ),
            ],

            // Pesan Error jika unduhan gagal
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.red,
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: _openExternalBrowser,
                child: const Text(
                  'Unduh manual via Browser',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],

            if (force && !_downloaded) ...[
              const SizedBox(height: 10),
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

            const SizedBox(height: 18),

            // Tombol Utama: Unduh di dalam aplikasi / Pasang Sekarang
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _downloaded ? AppColors.green : accent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _downloading
                    ? null
                    : (_downloaded && _downloadedPath != null
                        ? () => _installApk(_downloadedPath!)
                        : _startDownload),
                child: _downloading
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Mengunduh (${(_progress * 100).toInt()}%)...',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _downloaded
                                ? Icons.install_mobile_rounded
                                : Icons.download_rounded,
                            size: 19,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _downloaded
                                ? 'Pasang Sekarang'
                                : 'Unduh Pembaruan Langsung',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: force || _downloaded
                                  ? Colors.white
                                  : context.primaryContrast,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            // Tombol Nanti Saja (jika opsional dan tidak sedang mengunduh)
            if (!force && !_downloading) ...[
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                height: 38,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(
                    'Nanti Saja',
                    style: TextStyle(
                      fontSize: 13,
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
