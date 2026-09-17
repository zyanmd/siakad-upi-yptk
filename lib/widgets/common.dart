import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

// ------------------------------------------------------------- Toast

void appToast(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.red : null,
      duration: Duration(milliseconds: error ? 3500 : 2200),
    ),
  );
}

/// Tampilkan pesan error dari exception apa pun dengan cara yang aman.
String errorText(Object e) =>
    e is ApiException ? e.message : 'Terjadi kesalahan. Coba lagi.';

/// Dialog konfirmasi iOS Cupertino style; return true bila setuju.
Future<bool> confirmDialog(
    BuildContext context, String title, String message) async {
  final ok = await showCupertinoDialog<bool>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(title),
      content: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(message),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Batal'),
        ),
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Ya, Lanjutkan'),
        ),
      ],
    ),
  );
  return ok == true;
}

// ------------------------------------------------------------- Link

Future<void> openExternal(BuildContext context, String url) async {
  try {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  } catch (_) {
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (_) {
      if (context.mounted) {
        appToast(context, 'Tidak dapat membuka tautan eksternal.', error: true);
      }
    }
  }
}

Future<void> copyText(BuildContext context, String value) async {
  await Clipboard.setData(ClipboardData(text: value));
  if (context.mounted) appToast(context, 'Disalin ke clipboard');
}

// --------------------------------------------------------- State views

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label = 'Memuat data...'});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CupertinoActivityIndicator(radius: 12),
          const SizedBox(height: 12),
          Text(label,
              style: TextStyle(
                color: context.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w400,
              )),
        ],
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, this.icon = CupertinoIcons.tray, this.message});
  final IconData icon;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: context.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              message ?? 'Tidak ada data untuk ditampilkan.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.textMuted,
                fontSize: 13,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(CupertinoIcons.exclamationmark_circle,
                  size: 32, color: AppColors.red),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryYellow,
                foregroundColor: const Color(0xFF1C1917),
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(CupertinoIcons.arrow_clockwise, size: 16),
              label: const Text('Coba Lagi',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------- Building blocks

/// Header seksi bergaya iOS Inset Grouped.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: context.textPrimary,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Kartu permukaan iOS Inset Grouped dengan border hairline 0.5px.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.margin = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderSide = BorderSide(
      color: context.border,
      width: 0.5,
    );

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.fromBorderSide(borderSide),
        boxShadow: context.isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: onTap == null
            ? Padding(padding: padding, child: child)
            : InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(16),
                child: Padding(padding: padding, child: child),
              ),
      ),
    );
  }
}

/// Chip status kapsul khas iOS (pastel fill + dark text).
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, this.label, this.kind});
  final String? label;
  final String? kind;

  (Color, Color) _colors() {
    final text = '${kind ?? ''} ${label ?? ''}'.toLowerCase();
    const greenWords = [
      'lunas', 'paid', 'berhasil', 'aktif', 'approve', 'disetujui',
      'valid', 'success', 'selesai', 'hadir', 'lulus', 'ok',
    ];
    const redWords = [
      'tolak', 'reject', 'gagal', 'blokir', 'nonaktif', 'batal',
      'expired', 'alpa', 'menolak',
    ];
    const amberWords = [
      'pending', 'waiting', 'proses', 'belum', 'booking', 'resolve',
      'menunggu', 'review', 'izin', 'sakit', 'tertunda',
    ];
    if (greenWords.any((w) => text.contains(w))) {
      return (AppColors.green.withValues(alpha: 0.14), AppColors.green);
    }
    if (redWords.any((w) => text.contains(w))) {
      return (AppColors.red.withValues(alpha: 0.12), AppColors.red);
    }
    if (amberWords.any((w) => text.contains(w))) {
      return (AppColors.orange.withValues(alpha: 0.14), AppColors.orange);
    }
    return (AppColors.grey.withValues(alpha: 0.12), AppColors.grey);
  }

  @override
  Widget build(BuildContext context) {
    final text = (label ?? 'Status').toString();
    final (bg, fg) = _colors();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

/// Baris key - value iOS style; tekan lama untuk salin nilai.
class KeyValueRow extends StatelessWidget {
  const KeyValueRow({
    super.key,
    required this.label,
    required this.value,
    this.onTapValue,
  });

  final String label;
  final String value;
  final VoidCallback? onTapValue;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onLongPress: () => copyText(context, value),
      onTap: onTapValue,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Text(
                label,
                style: TextStyle(
                  color: context.textMuted,
                  fontSize: 12.5,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 7,
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartu statistik iOS Health/Activity style.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.border, width: 0.5),
        boxShadow: context.isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: context.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tile menu grid khas iOS Home Screen / Springboard style.
class MenuTile extends StatelessWidget {
  const MenuTile({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.border, width: 0.5),
          boxShadow: context.isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
                color: context.textPrimary,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// InputDecoration bergaya iOS textfield.
InputDecoration appInput(
  BuildContext context,
  String label, {
  IconData? icon,
  Widget? suffix,
}) {
  OutlineInputBorder border([Color? c, double w = 0.5]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c ?? context.border, width: w),
      );

  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(
      color: context.textMuted,
      fontSize: 13.5,
      fontWeight: FontWeight.w400,
    ),
    prefixIcon:
        icon != null ? Icon(icon, size: 19, color: context.textMuted) : null,
    suffixIcon: suffix,
    filled: true,
    fillColor: context.isDark
        ? const Color(0xFF1C1C1E)
        : Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: border(),
    enabledBorder: border(),
    focusedBorder: border(AppColors.primaryYellow, 1.2),
  );
}

/// Judul kolom kecil untuk item list.
String moneyOrRaw(String key, dynamic v) => formatValue(key, v);
