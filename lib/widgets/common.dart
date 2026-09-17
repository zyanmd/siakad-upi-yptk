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

/// Dialog konfirmasi Ya/Tidak; return true bila setuju.
Future<bool> confirmDialog(
    BuildContext context, String title, String message) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(title,
          style:
              const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      content: Text(message,
          style: const TextStyle(fontSize: 13.5, height: 1.5)),
      actionsPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.indigo700),
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
          const CircularProgressIndicator(
              color: AppColors.indigo700, strokeWidth: 2.6),
          const SizedBox(height: 14),
          Text(label, style: TextStyle(color: context.textMuted, fontSize: 12.5)),
        ],
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, this.icon = Icons.inbox_outlined, this.message});
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
            Icon(icon, size: 46, color: context.textMuted.withOpacity(0.6)),
            const SizedBox(height: 12),
            Text(
              message ?? 'Tidak ada data untuk ditampilkan.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.textMuted, fontSize: 13),
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
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.red.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_off_rounded,
                  size: 34, color: AppColors.red),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.textPrimary, fontSize: 13.5),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.indigo700,
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------- Building blocks

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.amber,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: context.textPrimary,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Kartu permukaan standar aplikasi.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(16),
      this.onTap,
      this.margin = EdgeInsets.zero});
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.border),
      ),
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: Padding(padding: padding, child: child),
            ),
    );
  }
}

/// Chip status dengan pewarnaan otomatis dari kata kunci.
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
      return (AppColors.green.withOpacity(0.12), AppColors.green);
    }
    if (redWords.any((w) => text.contains(w))) {
      return (AppColors.red.withOpacity(0.10), AppColors.red);
    }
    if (amberWords.any((w) => text.contains(w))) {
      return (AppColors.amber.withOpacity(0.16), AppColors.orange);
    }
    return (Colors.grey.withOpacity(0.10), AppColors.grey);
  }

  @override
  Widget build(BuildContext context) {
    final text = (label ?? 'Status').toString();
    final (bg, fg) = _colors();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
            color: fg, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Baris key - value; tekan lama untuk salin nilai.
class KeyValueRow extends StatelessWidget {
  const KeyValueRow(
      {super.key, required this.label, required this.value, this.onTapValue});
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
              child: Text(label,
                  style: TextStyle(color: context.textMuted, fontSize: 12.5)),
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartu statistik kecil untuk dashboard.
class StatCard extends StatelessWidget {
  const StatCard(
      {super.key,
      required this.label,
      required this.value,
      required this.icon,
      required this.color});
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10.5, color: context.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Tile menu grid di dashboard.
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
          border: Border.all(color: context.border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.13),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 19, color: color),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// InputDecoration konsisten untuk seluruh form.
InputDecoration appInput(BuildContext context, String label,
    {IconData? icon, Widget? suffix}) {
  OutlineInputBorder border([Color? c, double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c ?? context.border, width: w),
      );
  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: context.textMuted, fontSize: 13.5),
    prefixIcon:
        icon != null ? Icon(icon, size: 20, color: context.textMuted) : null,
    suffixIcon: suffix,
    filled: true,
    fillColor: context.isDark
        ? Colors.white.withOpacity(0.05)
        : const Color(0xFFF5F7FC),
    contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: border(),
    enabledBorder: border(),
    focusedBorder: border(AppColors.indigo500, 1.6),
  );
}

/// Judul kolom kecil untuk item list.
String moneyOrRaw(String key, dynamic v) => formatValue(key, v);
