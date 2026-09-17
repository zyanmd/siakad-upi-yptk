import 'package:flutter/material.dart';

/// Kumpulan warna khas aplikasi - Nuansa Kuning Emas khas UPI YPTK Padang.
class AppColors {
  AppColors._();

  // Warna Utama UPI YPTK Padang (Kuning Emas & Amber)
  static const Color upiYellowDark = Color(0xFF78350F);   // Deep Warm Amber
  static const Color upiYellowDeep = Color(0xFFB45309);   // Kuning Tua / Emas Almamater
  static const Color upiYellow = Color(0xFFD97706);       // Kuning Emas UPI YPTK
  static const Color upiYellowBright = Color(0xFFF59E0B); // Kuning Cerah
  static const Color upiYellowLight = Color(0xFFFDE68A);  // Kuning Muda

  // Alias kompatibilitas kode widget lama (sekarang memakai palet Kuning UPI YPTK)
  static const Color indigo950 = Color(0xFF1C1917);       // Dark Espresso / Hitam Hangat
  static const Color indigo900 = Color(0xFF292524);       // Dark Stone
  static const Color indigo700 = Color(0xFFB45309);       // UPI YPTK Gold Primer
  static const Color indigo500 = Color(0xFFD97706);       // UPI YPTK Amber
  static const Color indigo300 = Color(0xFFF59E0B);       // UPI YPTK Gold Aksen

  static const Color amber = Color(0xFFF59E0B);
  static const Color amberLight = Color(0xFFFEF3C7);

  static const Color green = Color(0xFF16A34A);
  static const Color red = Color(0xFFDC2626);
  static const Color orange = Color(0xFFEA580C);
  static const Color blue = Color(0xFF2563EB);
  static const Color grey = Color(0xFF78716C);

  /// Gradient untuk header halaman khas Kuning Emas UPI YPTK Padang.
  static const List<Color> headerGradient = [
    Color(0xFF78350F), // Deep Warm Gold
    Color(0xFFB45309), // UPI YPTK Gold
    Color(0xFFD97706), // Bright Amber Gold
  ];

  /// Gradient untuk logo / elemen kuning.
  static const List<Color> logoGradient = [
    Color(0xFFFDE047),
    Color(0xFFF59E0B),
  ];
}

/// Ekstensi palet berdasarkan mode terang / gelap (Warm Gold UPI YPTK).
extension AppPalette on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get bg => isDark ? const Color(0xFF141210) : const Color(0xFFFAF8F5);
  Color get card => isDark ? const Color(0xFF1E1B18) : Colors.white;
  Color get border =>
      isDark ? const Color(0xFF332D26) : const Color(0xFFEDE6DA);
  Color get textPrimary =>
      isDark ? const Color(0xFFFAF7F2) : const Color(0xFF1C1917);
  Color get textMuted =>
      isDark ? const Color(0xFFA8A29E) : const Color(0xFF78716C);
  Color get softFill =>
      isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFFDFBF7);
  Color get primary => AppColors.indigo700;
  Color get accent => AppColors.amber;
}

class AppTheme {
  AppTheme._();

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFD97706),
      brightness: brightness,
      secondary: const Color(0xFFF59E0B),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF141210) : const Color(0xFFFAF8F5),
      appBarTheme: AppBarTheme(
        backgroundColor:
            isDark ? const Color(0xFF141210) : const Color(0xFFFAF8F5),
        foregroundColor: isDark ? Colors.white : const Color(0xFF1C1917),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? const Color(0xFF332D26) : const Color(0xFFEDE6DA),
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isDark ? const Color(0xFF292524) : const Color(0xFF1C1917),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13.5),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 80,
        indicatorColor: AppColors.amber.withValues(alpha: 0.22),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected
                ? AppColors.indigo700
                : (isDark ? const Color(0xFFA8A29E) : const Color(0xFF78716C)),
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11.5,
            letterSpacing: -0.2,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            color: selected
                ? AppColors.indigo700
                : (isDark ? const Color(0xFFA8A29E) : const Color(0xFF78716C)),
          );
        }),
      ),
    );
  }
}
