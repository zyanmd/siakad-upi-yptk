import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Header gradien indigo dengan ornamen kuning ala SIAKAD modern.
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
        ? const BorderRadius.vertical(bottom: Radius.circular(24))
        : BorderRadius.zero;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.headerGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: radius,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            // Ornamen dekoratif
            Positioned(
              right: -30,
              top: -34,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.amber.withOpacity(0.14),
                ),
              ),
            ),
            Positioned(
              right: 56,
              bottom: -46,
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                        leading != null ? 6 : 18, 10, 6, tall ? 16 : 13),
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
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (subtitle != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  subtitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.72),
                                    fontSize: 12,
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
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                      child: bottom!,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tombol kembali bulat transparan untuk dipakai di dalam header.
class HeaderBackButton extends StatelessWidget {
  const HeaderBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: IconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        tooltip: 'Kembali',
      ),
    );
  }
}

/// Tombol aksi ikon bulat transparan di header.
class HeaderActionButton extends StatelessWidget {
  const HeaderActionButton(
      {super.key, required this.icon, this.onPressed, this.tooltip});
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white, size: 21),
      tooltip: tooltip,
    );
  }
}
