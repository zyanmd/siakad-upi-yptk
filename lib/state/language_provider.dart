import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/session_store.dart';
import '../theme/app_theme.dart';

/// Bahasa aplikasi yang didukung.
enum AppLanguage {
  id(
    code: 'id',
    name: 'Bahasa Indonesia',
    shortName: 'Indonesia',
    flag: '🇮🇩',
  ),
  en(
    code: 'en',
    name: 'English',
    shortName: 'English',
    flag: '🇬🇧',
  );

  final String code;
  final String name;
  final String shortName;
  final String flag;

  const AppLanguage({
    required this.code,
    required this.name,
    required this.shortName,
    required this.flag,
  });

  Locale get locale => Locale(code);
}

/// Provider penyimpan & pengelola bahasa aplikasi.
class LanguageProvider extends ChangeNotifier {
  LanguageProvider(this._store) {
    if (_store.languageCached == 'en') {
      _lang = AppLanguage.en;
    } else {
      _lang = AppLanguage.id;
    }
  }

  final SessionStore _store;
  AppLanguage _lang = AppLanguage.id;

  AppLanguage get language => _lang;
  Locale get locale => _lang.locale;
  bool get isEnglish => _lang == AppLanguage.en;

  Future<void> setLanguage(AppLanguage lang) async {
    if (_lang == lang) return;
    _lang = lang;
    notifyListeners();
    await _store.saveLanguage(lang.code);
  }

  Future<void> toggleLanguage() async {
    if (_lang == AppLanguage.id) {
      await setLanguage(AppLanguage.en);
    } else {
      await setLanguage(AppLanguage.id);
    }
  }
}

/// Widget switcher bahasa interaktif ala iOS segmented pill bar.
class LanguageSwitcher extends StatelessWidget {
  const LanguageSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final lp = context.watch<LanguageProvider>();
    final isDark = context.isDark;

    return Container(
      decoration: BoxDecoration(
        color: context.softFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.border, width: 0.5),
      ),
      padding: const EdgeInsets.all(3.5),
      child: Row(
        children: AppLanguage.values.map((lang) {
          final isSelected = lp.language == lang;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                lp.setLanguage(lang);
              },
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? const Color(0xFF2C2C2E) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      lang.flag,
                      style: const TextStyle(fontSize: 15),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      lang.shortName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected
                            ? context.textPrimary
                            : context.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
