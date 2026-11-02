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

/// Dialog konfirmasi Material bersih; return true bila setuju.
Future<bool> confirmDialog(
    BuildContext context, String title, String message) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: ctx.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: ctx.textPrimary,
        ),
      ),
      content: Text(
        message,
        style: TextStyle(
          fontSize: 14,
          color: ctx.textMuted,
          height: 1.45,
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(
            'Batal',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: ctx.textMuted,
            ),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.red,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
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

Future<void> copyText(BuildContext context, String value, [String? message]) async {
  await Clipboard.setData(ClipboardData(text: value));
  if (context.mounted) appToast(context, message ?? 'Disalin ke clipboard');
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
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryYellow),
            ),
          ),
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
              child: const Icon(Icons.error_outline_rounded,
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
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
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

/// Header seksi bergaya bersih & rapi.
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
                fontSize: 15,
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

/// Pembungkus interaksi tap bersih dan responsif tanpa efek memantul iOS.
class IosBounceTap extends StatelessWidget {
  const IosBounceTap({
    super.key,
    required this.child,
    this.onTap,
    this.scaleFactor = 1.0,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scaleFactor;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: child,
    );
  }
}

/// Kartu permukaan Material bersih dengan border halus dan bayangan lembut.
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
    final decoration = BoxDecoration(
      color: context.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: context.border, width: 1),
      boxShadow: context.isDark
          ? null
          : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
    );

    if (onTap == null) {
      return Container(
        margin: margin,
        decoration: decoration,
        child: Padding(padding: padding, child: child),
      );
    }

    return Container(
      margin: margin,
      decoration: decoration,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
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

/// Tile menu grid modern dan rapi dengan efek tap bersih.
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
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.border, width: 1),
        boxShadow: context.isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
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
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: context.textPrimary,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// InputDecoration modern dan rapi.
InputDecoration appInput(
  BuildContext context,
  String label, {
  IconData? icon,
  Widget? suffix,
}) {
  OutlineInputBorder border([Color? c, double w = 1.0]) => OutlineInputBorder(
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
        icon != null ? Icon(icon, size: 20, color: context.textMuted) : null,
    suffixIcon: suffix,
    filled: true,
    fillColor: context.card,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: border(),
    enabledBorder: border(),
    focusedBorder: border(AppColors.primaryYellow, 1.5),
  );
}

/// Judul kolom kecil untuk item list.
String moneyOrRaw(String key, dynamic v) => formatValue(key, v);

// ═══════════════════════════════════════════════════════════════════
//  SEAMLESS WAVE CLIPPER (DIPERBAIKI TOTAL)
// ═══════════════════════════════════════════════════════════════════

/// Clipper kurva gelombang asimetris organik yang **SEAMLESS** —
/// dapat disambung sempurna antar widget/header tanpa celah.
///
/// Karakteristik:
/// - **Tinggi ujung kiri == tinggi ujung kanan** (`baseY`), sehingga bila
///   dipakai pada dua header bertumpuk atau disambung ke widget lain,
///   tidak akan muncul celah/step.
/// - **C1-continuous**: dua segmen cubic Bezier yang tangen-nya nyambung
///   di titik tengah (0.5w), sehingga tidak ada "patahan" halus.
/// - **Natural**: lekukan turun membentuk ombak asimetris (lebih dalam di
///   kiri-tengah, lalu naik lembut ke kanan) — persis seperti kurva IPB /
///   header akademik modern.
///
/// Parameter:
/// - [waveHeight]: kedalaman dasar lekukan dari bawah widget (kiri == kanan).
/// - [waveDip]:    ekstra kedalaman di titik ombak terendah.
///
/// **Penting**: `padding.bottom` pada header yang memakai clipper ini
/// harus `>= waveHeight + waveDip + 8` agar konten tidak tertutup.
class SeamlessWaveClipper extends CustomClipper<Path> {
  const SeamlessWaveClipper({
    this.waveHeight = 28,
    this.waveDip = 14,
  });

  final double waveHeight;
  final double waveDip;

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;

    // Garis dasar lekukan (kiri == kanan) → seamless.
    final baseY = h - waveHeight;

    final path = Path()..moveTo(0, 0);

    // Sisi kiri turun lurus ke awal lekukan.
    path.lineTo(0, baseY);

    // ── Segmen 1: turun membentuk lembah ombak (0 → 0.5w) ──
    path.cubicTo(
      w * 0.16, baseY + waveDip * 1.55, // cp1: mulai turun
      w * 0.34, baseY + waveDip * 2.00, // cp2: titik terendah
      w * 0.50, baseY + waveDip * 1.05, // akhir segmen 1 (tengah)
    );

    // ── Segmen 2: naik kembali ke kanan (0.5w → w) ──
    // Tangen di titik sambung (0.5w) searah dengan segmen 1 → C1-continuous.
    path.cubicTo(
      w * 0.66, baseY + waveDip * 0.10, // cp1: lanjut naik
      w * 0.84, baseY - waveDip * 0.05, // cp2: sedikit di atas base
      w,        baseY,                  // akhir: kembali ke baseY (sama dgn kiri)
    );

    // Naik ke kanan atas & tutup path.
    path.lineTo(w, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant SeamlessWaveClipper oldClipper) =>
      oldClipper.waveHeight != waveHeight || oldClipper.waveDip != waveDip;
}

/// Helper: tinggi total area lekukan yang perlu diakomodasi sebagai padding.
/// Gunakan ini untuk menghitung `padding.bottom` header agar konsisten.
double seamlessWaveReservedHeight({double waveHeight = 28, double waveDip = 14}) =>
    waveHeight + waveDip + 8;

/// Padding bawah standar untuk SEMUA header berlekuk.
///
/// Dipakai seragam oleh seluruh halaman agar lekukan/curve header terlihat
/// persis sama di mana pun dan tidak menutupi teks/badge di bawahnya.
const double kCurvedHeaderBottomPadding = 68;

// ═══════════════════════════════════════════════════════════════════
//  RESPONSIVE DESKTOP HELPERS
// ═══════════════════════════════════════════════════════════════════

/// Lebar maksimum konten agar tetap nyaman dibaca pada layar desktop lebar
/// (browser / tablet landscape). Tanpa batas ini, konten akan melebar
/// penuh dari tepi ke tepi pada monitor besar.
const double kMaxContentWidth = 1100;

/// Ambang lebar layar untuk dianggap sebagai "desktop" (web/browser lebar).
const double kDesktopBreakpoint = 900;

/// `true` bila lebar layar berada pada rentang desktop.
bool isDesktopWidth(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;

/// Membungkus konten anak agar terpusat dengan lebar maksimum [maxWidth]
/// pada layar lebar, dan tetap penuh pada layar sempit/hp.
///
/// Aman dipakai sebagai pembungkus utama maupun di dalam kolom scroll.
class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = kMaxContentWidth,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double maxWidth;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    // Pada layar yang lebih sempit dari [maxWidth] (mis. semua HP), jangan
    // membungkus apa pun supaya layout mobile 100% identik dengan sebelumnya.
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth || constraints.maxWidth <= maxWidth) {
          return child;
        }
        return Align(
          alignment: alignment,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        );
      },
    );
  }
}

/// Bingkai aplikasi untuk layar lebar.
///
/// Pada desktop/web, aplikasi mengisi seluruh jendela (navigation rail di
/// kiri + konten di kanan). Kelas ini disediakan agar `MaterialApp.builder`
/// tetap punya titik ekstensi tunggal bila kelak perlu menambahkan
/// kanvas/padding global, tanpa mengganggu layout mobile.
class DesktopFrame extends StatelessWidget {
  const DesktopFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Aplikasi mengisi penuh layar di semua ukuran; pembatas lebar konten
    // ditangani oleh [ResponsiveCenter] per-halaman.
    return child;
  }
}
