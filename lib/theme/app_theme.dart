import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Kumpulan warna khas aplikasi - Estetika Bersih, Rapi & Modern dengan Aksen Emas UPI YPTK.
class AppColors {
  AppColors._();

  // Warna Utama Aplikasi: Emas Akademik Kampus UPI YPTK
  static const Color primaryYellow = Color(0xFFF59E0B); // Amber 500
  static const Color upiYellowDark = Color(0xFFD97706); // Amber 600
  static const Color upiYellowDeep = Color(0xFFB45309); // Amber 700
  static const Color upiYellow = Color(0xFFF59E0B);
  static const Color upiYellowBright = Color(0xFFFBBF24); // Amber 400
  static const Color upiYellowLight = Color(0xFFFEF3C7); // Amber 100

  // Semantic Colors
  static const Color green = Color(0xFF10B981);  // Emerald 500
  static const Color red = Color(0xFFEF4444);    // Red 500
  static const Color orange = Color(0xFFF97316); // Orange 500
  static const Color blue = Color(0xFF3B82F6);   // Blue 500
  static const Color teal = Color(0xFF14B8A6);   // Teal 500
  static const Color purple = Color(0xFF8B5CF6); // Purple 500
  static const Color grey = Color(0xFF64748B);   // Slate 500

  // Kompatibilitas alias warna
  static const Color indigo950 = Color(0xFF0F172A);
  static const Color indigo900 = Color(0xFF1E293B);
  static const Color indigo700 = Color(0xFFD97706);
  static const Color indigo500 = Color(0xFFB45309);
  static const Color indigo300 = Color(0xFFFBBF24);
  static const Color amber = Color(0xFFF59E0B);
  static const Color amberLight = Color(0xFFFEF3C7);

  /// Header Gradient bergaya Slate Akademik Kampus
  static const List<Color> headerGradient = [
    Color(0xFF0F172A), // Slate 900
    Color(0xFF1E293B), // Slate 800
  ];

  /// Gradient logo aksen emas akademik kampus
  static const List<Color> logoGradient = [
    Color(0xFFFBBF24),
    Color(0xFFD97706),
  ];
}

/// Ekstensi palet warna adaptif & rapi untuk BuildContext
extension AppPalette on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  // Latar belakang utama:
  // Light: Bersih, cerah Slate-50 (#F8FAFC)
  // Dark: Deep modern Slate-950 (#0B0F19), elegan & nyaman di mata
  Color get bg => isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC);

  // Permukaan kartu (Card & Surfaces):
  // Light: Pure clean White (#FFFFFF)
  // Dark: Slate-900 surface (#151D2E)
  Color get card => isDark ? const Color(0xFF151D2E) : Colors.white;

  // Kartu bertingkat / elevated surface:
  Color get elevatedCard => isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);

  // Garis pemisah hairline rapi:
  Color get border => isDark ? const Color(0xFF222E46) : const Color(0xFFE2E8F0);

  // Tipografi label sangat rapi dan berkontras tinggi:
  Color get textPrimary => isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
  Color get textMuted => isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get textTertiary => isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

  // Fill lembut untuk badge / input field:
  Color get softFill => isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);

  Color get primary => AppColors.primaryYellow;
  Color get accent => AppColors.primaryYellow;

  // Kontras adaptif untuk teks/ikon:
  Color get primaryContrast => isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
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
      onPrimary: const Color(0xFF1C1917),
      brightness: brightness,
      surface: isDark ? const Color(0xFF151D2E) : Colors.white,
      onSurface: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
    );

    // Tipografi Plus Jakarta Sans: Bersih, Rapi, Modern & Keterbacaan Sangat Tinggi
    final baseTextTheme = ThemeData(brightness: brightness).textTheme;
    final cleanTextTheme = GoogleFonts.plusJakartaSansTextTheme(baseTextTheme).apply(
      bodyColor: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
      displayColor: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: cleanTextTheme,
      scaffoldBackgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? const Color(0xFF151D2E) : Colors.white,
        foregroundColor: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: true,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
        ),
      ),
      cardTheme: CardThemeData(
        color: isDark ? const Color(0xFF151D2E) : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? const Color(0xFF222E46) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? const Color(0xFF151D2E) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? const Color(0xFF151D2E) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryYellow,
          foregroundColor: const Color(0xFF1C1917),
          elevation: 0,
          minimumSize: const Size(64, 46),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
          side: BorderSide(
            color: isDark ? const Color(0xFF222E46) : const Color(0xFFCBD5E1),
            width: 1,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.primaryYellow;
            }
            return isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFF1C1917);
            }
            return isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
          }),
          side: WidgetStateProperty.all(BorderSide.none),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? const Color(0xFF222E46) : const Color(0xFFE2E8F0),
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
        contentTextStyle: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.primaryYellow,
        linearTrackColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
      ),
    );
  }
}
