import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/session_store.dart';
import '../theme/app_theme.dart';

/// Mode tema aplikasi.
enum AppThemeMode { system, light, dark }

/// Menyimpan & menyebarkan pilihan tema terang/gelap/sistem.
class ThemeProvider extends ChangeNotifier {
  ThemeProvider(this._store) {
    switch (_store.themeModeCached) {
      case 'light':
        _mode = AppThemeMode.light;
        break;
      case 'dark':
        _mode = AppThemeMode.dark;
        break;
      default:
        _mode = AppThemeMode.system;
    }
  }

  final SessionStore _store;
  AppThemeMode _mode = AppThemeMode.system;

  AppThemeMode get mode => _mode;

  ThemeMode get materialMode {
    switch (_mode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  Future<void> setMode(AppThemeMode m) async {
    if (m == _mode) return;
    _mode = m;
    notifyListeners();
    await _store.saveThemeMode(m.name);
  }

  Future<void> toggleTheme() async {
    if (_mode == AppThemeMode.dark) {
      await setMode(AppThemeMode.light);
    } else {
      await setMode(AppThemeMode.dark);
    }
  }
}

/// Widget kecil untuk menampilkan pilihan tema (dipakai di halaman Profil).
class ThemeModeSwitcher extends StatelessWidget {
  const ThemeModeSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<ThemeProvider>();
    return SegmentedButton<AppThemeMode>(
      segments: const [
        ButtonSegment(
          value: AppThemeMode.system,
          label: Text('Sistem'),
          icon: Icon(Icons.brightness_auto_rounded, size: 17),
        ),
        ButtonSegment(
          value: AppThemeMode.light,
          label: Text('Terang'),
          icon: Icon(Icons.light_mode_rounded, size: 17),
        ),
        ButtonSegment(
          value: AppThemeMode.dark,
          label: Text('Gelap'),
          icon: Icon(Icons.dark_mode_rounded, size: 17),
        ),
      ],
      selected: {tp.mode},
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: AppColors.indigo700,
        selectedForegroundColor: Colors.white,
        backgroundColor: context.softFill,
        foregroundColor: context.textMuted,
        textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
        side: BorderSide(color: context.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onSelectionChanged: (selection) {
        tp.setMode(selection.first);
      },
    );
  }
}
