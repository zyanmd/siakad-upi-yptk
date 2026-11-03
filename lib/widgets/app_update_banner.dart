import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_update_provider.dart';
import '../theme/app_theme.dart';
import 'app_update_dialog.dart';

/// Banner pembaruan aplikasi yang tampil di halaman depan (Dashboard & Login)
/// bila terdapat versi baru di server/GitHub.
class AppUpdateBanner extends StatelessWidget {
  const AppUpdateBanner({
    super.key,
    this.margin = const EdgeInsets.only(bottom: 16),
  });

  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppUpdateProvider>();
    if (!provider.hasUpdateBanner) return const SizedBox.shrink();

    final info = provider.availableUpdate;
    if (info == null) return const SizedBox.shrink();

    final isDark = context.isDark;
    final isForce = info.forceUpdate;
    final accentColor = isForce ? const Color(0xFFEF4444) : AppColors.primaryYellow;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withValues(alpha: isDark ? 0.45 : 0.6),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: isDark ? 0.12 : 0.16),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => showAppUpdateDialog(context, info: info),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Ikon badge roket/update modern
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accentColor,
                        isForce ? const Color(0xFFDC2626) : const Color(0xFFD48B08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.rocket_launch_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),

                // Info teks versi & judul pembaruan
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Pembaruan v${info.latestVersion} Tersedia',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                                color: context.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isForce ? 'WAJIB' : 'BARU',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: isForce
                                    ? const Color(0xFFEF4444)
                                    : context.primaryContrast,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        info.title.isNotEmpty
                            ? info.title
                            : 'Ketuk untuk mengunduh dan memasang versi terbaru.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w400,
                          color: context.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Tombol aksi "Perbarui"
                FilledButton(
                  onPressed: () => showAppUpdateDialog(context, info: info),
                  style: FilledButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: isForce ? Colors.white : Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: const Size(0, 34),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Perbarui',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),

                // Tombol tutup opsional bila bukan force update
                if (!isForce) ...[
                  const SizedBox(width: 2),
                  IconButton(
                    onPressed: () => provider.dismissBanner(),
                    tooltip: 'Tutup Banner',
                    icon: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: context.textMuted.withValues(alpha: 0.7),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

