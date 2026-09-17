import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Kumpulan warna khas aplikasi - Estetika iOS Modern dengan Aksen Kuning #F3CB32.
class AppColors {
  AppColors._();

  // Warna Utama Aplikasi: Kuning iOS Tint #F3CB32
  static const Color primaryYellow = Color(0xFFF3CB32);
  static const Color upiYellowDark = Color(0xFFC49E18);
  static const Color upiYellowDeep = Color(0xFFF3CB32);
  static const Color upiYellow = Color(0xFFF3CB32);
  static const Color upiYellowBright = Color(0xFFFFD747);
  static const Color upiYellowLight = Color(0xFFFFF7D6);

  // Kompatibilitas alias warna lama
  static const Color indigo950 = Color(0xFF000000);
  static const Color indigo900 = Color(0xFF1C1C1E);
  static const Color indigo700 = Color(0xFFF3CB32);
  static const Color indigo500 = Color(0xFFE2BA26);
  static const Color indigo300 = Color(0xFFFFD747);

  static const Color amber = Color(0xFFF3CB32);
  static const Color amberLight = Color(0xFFFFF7D6);

  // iOS System Semantic Colors
  static const Color green = Color(0xFF34C759);
  static const Color red = Color(0xFFFF3B30);
  static const Color orange = Color(0xFFFF9500);
  static const Color blue = Color(0xFF007AFF);
  static const Color teal = Color(0xFF30B0C7);
  static const Color purple = Color(0xFFAF52DE);
  static const Color grey = Color(0xFF8E8E93);

  /// Header Gradient bergaya iOS Dark Graphite yang mewah & bersih
  static const List<Color> headerGradient = [
    Color(0xFF0A0A0C),
    Color(0xFF161618),
  ];

  /// Gradient logo aksen kuning #F3CB32
  static const List<Color> logoGradient = [
    Color(0xFFFFDF66),
    Color(0xFFF3CB32),
  ];
}

/// Ekstensi palet berbasis iOS System Backgrounds & Labels
extension AppPalette on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  // Latar belakang utama (OLED Black pada Dark Mode, Grouped Grey #F2F2F7 pada Light Mode)
  Color get bg => isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);

  // Permukaan kartu (iOS secondarySystemGroupedBackground)
  Color get card => isDark ? const Color(0xFF1C1C1E) : Colors.white;

  // Kartu bertingkat / elevated (iOS tertiarySystemGroupedBackground)
  Color get elevatedCard => isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);

  // Garis pemisah hairline
  Color get border => isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);

  // Tipografi label
  Color get textPrimary => isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
  Color get textMuted => const Color(0xFF8E8E93);
  Color get textTertiary => isDark ? const Color(0xFF48484A) : const Color(0xFFC7C7CC);

  // Fill lembut untuk badge / input
  Color get softFill => isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);

  Color get primary => AppColors.primaryYellow;
  Color get accent => AppColors.primaryYellow;
}

class AppTheme {
  AppTheme._();

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryYellow,
      primary: AppColors.primaryYellow,
      brightness: brightness,
      surface: isDark ? const Color(0xFF1C1C1E) : Colors.white,
    );

    // Tipografi Inter (Identik dengan Apple San Francisco / SF Pro)
    final baseTextTheme = ThemeData(brightness: brightness).textTheme;
    final interTextTheme = GoogleFonts.interTextTheme(baseTextTheme).apply(
      bodyColor: isDark ? Colors.white : Colors.black,
      displayColor: isDark ? Colors.white : Colors.black,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: interTextTheme,
      scaffoldBackgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
        thickness: 0.5,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFF1C1C1E),
        contentTextStyle: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
