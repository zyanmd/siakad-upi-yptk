import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

import 'common.dart';

// ═══════════════════════════════════════════════════════════════════
//  WAVE CLIPPER UNTUK HEADER LENGKUNG
// ═══════════════════════════════════════════════════════════════════

class CurvedHeaderClipper extends CustomClipper<Path> {
  const CurvedHeaderClipper({this.waveHeight = 28, this.waveDip = 14});
  final double waveHeight;
  final double waveDip;

  @override
  Path getClip(Size size) =>
      SeamlessWaveClipper(waveHeight: waveHeight, waveDip: waveDip)
          .getClip(size);

  @override
  bool shouldReclip(covariant CurvedHeaderClipper oldClipper) =>
      oldClipper.waveHeight != waveHeight || oldClipper.waveDip != waveDip;
}

// ═══════════════════════════════════════════════════════════════════
//  CURVED GRADIENT HEADER - Header Lengkung dengan Gradien Kuning UPI
// ═══════════════════════════════════════════════════════════════════

class CurvedGradientHeader extends StatelessWidget {
  const CurvedGradientHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.showBackButton = true,
    this.actions,
    this.height = 180,
  });

  final String title;
  final String? subtitle;
  final bool showBackButton;
  final List<Widget>? actions;
  final double height;

  static const List<Color> _gradientColors = [
    Color(0xFFE5A620), // Bright Academic Gold
    Color(0xFFD48B08), // UPI Yellow
    Color(0xFFB87500), // Deep Academic Gold
  ];

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: const SeamlessWaveClipper(),
      child: Container(
        height: height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: _gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: GoldenHeaderBackdrop()),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    22, 12, 22, kCurvedHeaderBottomPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Navigation Bar
                    Row(
                      children: [
                        if (showBackButton)
                          IconButton(
                            onPressed: () {
                              Navigator.of(context).maybePop();
                            },
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                            tooltip: 'Kembali',
                          ),
                        const Spacer(),
                        if (actions != null) ...actions!,
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Title & Subtitle
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1,
                              height: 1.1,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              subtitle!,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.90),
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  ORIGINAL FLAT HEADER (untuk halaman yang tidak perlu lengkung)
// ═══════════════════════════════════════════════════════════════════

/// Header navigasi bergaya iOS modern dengan border hairline dan tipografi bersih.
class GradientHeader extends StatelessWidget {
  const GradientHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions,
    this.bottom,
    this.tall = false,
    this.roundBottom = true,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget>? actions;
  final Widget? bottom;
  final bool tall;
  final bool roundBottom;

  @override
  Widget build(BuildContext context) {
    final radius = roundBottom
        ? const BorderRadius.vertical(bottom: Radius.circular(20))
        : BorderRadius.zero;

    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: radius,
        border: Border(
          bottom: BorderSide(
            color: context.border,
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                leading != null ? 4 : 16,
                8,
                8,
                tall ? 14 : 10,
              ),
              child: Row(
                children: [
                  if (leading != null) leading!,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.textMuted,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (actions != null) ...actions!,
                ],
              ),
            ),
            if (bottom != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: bottom!,
              ),
          ],
        ),
      ),
    );
  }
}

/// Tombol kembali header yang rapi dan konsisten.
class HeaderBackButton extends StatelessWidget {
  const HeaderBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {
        Navigator.of(context).maybePop();
      },
      icon: Icon(
        Icons.arrow_back_rounded,
        color: context.textPrimary,
        size: 22,
      ),
      tooltip: 'Kembali',
    );
  }
}

/// Tombol aksi ikon di header.
class HeaderActionButton extends StatelessWidget {
  const HeaderActionButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, color: context.textPrimary, size: 21),
      tooltip: tooltip,
    );
  }
}

/// Header Action Button untuk Curved Header (warna putih)
class CurvedHeaderActionButton extends StatelessWidget {
  const CurvedHeaderActionButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white, size: 24),
      tooltip: tooltip,
    );
  }
}
