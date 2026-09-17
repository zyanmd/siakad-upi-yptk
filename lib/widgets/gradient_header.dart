import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

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
                            fontSize: 17.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 1.5),
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
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

/// Tombol kembali bergaya chevron iOS.
class HeaderBackButton extends StatelessWidget {
  const HeaderBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => Navigator.of(context).maybePop(),
      icon: Icon(
        CupertinoIcons.chevron_back,
        color: context.textPrimary,
        size: 24,
      ),
      tooltip: 'Kembali',
      splashRadius: 20,
    );
  }
}

/// Tombol aksi ikon di header ala iOS.
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
      splashRadius: 20,
    );
  }
}
