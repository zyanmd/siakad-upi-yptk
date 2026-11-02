import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../state/language_provider.dart';

/// Kamus multibahasa (Bahasa Indonesia & English) untuk SIAKAD App.
class AppStrings {
  static const Map<String, Map<String, String>> _dict = {
    // ---------------- General & Bottom Nav
    'nav_home': {
      'id': 'Beranda',
      'en': 'Home',
    },
    'nav_schedule': {
      'id': 'Jadwal',
      'en': 'Schedule',
    },
    'nav_billing': {
      'id': 'Tagihan',
      'en': 'Billing',
    },
    'nav_profile': {
      'id': 'Profil',
      'en': 'Profile',
    },

    // ---------------- Profile Screen
    'profile_title': {
      'id': 'Profil Saya',
      'en': 'My Profile',
    },
    'profile_subtitle': {
      'id': 'Informasi akun & pengaturan',
      'en': 'Account info & preferences',
    },
    'nim_label': {
      'id': 'NIM',
      'en': 'Student ID',
    },
    'academic_advisor': {
      'id': 'Dosen Pembimbing (PA)',
      'en': 'Academic Advisor (PA)',
    },
    'student_status': {
      'id': 'Status Kemahasiswaan',
      'en': 'Student Status',
    },
    'status_active': {
      'id': 'Aktif',
      'en': 'Active',
    },
    'email_label': {
      'id': 'Email',
      'en': 'Email Address',
    },
    'view_full_biodata': {
      'id': 'Lihat Biodata & Riwayat Lengkap',
      'en': 'View Full Academic Record',
    },

    // ---------------- Appearance & Theme
    'appearance_section': {
      'id': 'Tampilan',
      'en': 'Appearance',
    },
    'display_mode': {
      'id': 'Mode Tampilan',
      'en': 'Display Theme',
    },
    'theme_system': {
      'id': 'Sistem',
      'en': 'System',
    },
    'theme_light': {
      'id': 'Terang',
      'en': 'Light',
    },
    'theme_dark': {
      'id': 'Gelap',
      'en': 'Dark',
    },

    // ---------------- Language Section
    'language_section': {
      'id': 'Bahasa / Language',
      'en': 'Language / Bahasa',
    },
    'language_title': {
      'id': 'Bahasa Aplikasi',
      'en': 'Application Language',
    },
    'language_desc': {
      'id': 'Pilih bahasa antarmuka aplikasi',
      'en': 'Choose display language',
    },

    // ---------------- About & Developer
    'about_section': {
      'id': 'Tentang Aplikasi',
      'en': 'About Application',
    },
    'about_app_desc': {
      'id': 'Informasi versi & pengembang',
      'en': 'Version & developer info',
    },
    'unofficial_title': {
      'id': 'SIAKAD UNOFFICIAL',
      'en': 'SIAKAD UNOFFICIAL',
    },
    'unofficial_desc': {
      'id':
          'Aplikasi pihak ketiga (Unofficial Client) modern, cepat, dan responsif untuk mahasiswa Universitas Putra Indonesia YPTK Padang. Terhubung ke SIAKAD UPI YPTK secara tidak resmi.',
      'en':
          'Modern, fast, and responsive third-party client for Universitas Putra Indonesia YPTK Padang students. Connected to SIAKAD UPI YPTK unofficially.',
    },
    'developer_contact': {
      'id': 'Hubungi Pengembang via Telegram',
      'en': 'Contact Developer via Telegram',
    },
    'developer_sub': {
      'id': 'Kritik, saran, atau laporan kendala',
      'en': 'Feedback, suggestions, or bug reports',
    },

    // ---------------- Logout & Actions
    'logout_btn': {
      'id': 'Logout',
      'en': 'Sign Out',
    },
    'logout_confirm_title': {
      'id': 'Logout',
      'en': 'Sign Out',
    },
    'logout_confirm_desc': {
      'id': 'Yakin ingin keluar dari aplikasi?',
      'en': 'Are you sure you want to sign out?',
    },
    'cancel': {
      'id': 'Batal',
      'en': 'Cancel',
    },

    // ---------------- Dashboard & Shortcuts
    'academic_services': {
      'id': 'Layanan Akademik',
      'en': 'Academic Services',
    },
    'today_schedule': {
      'id': 'Jadwal Kuliah Hari Ini',
      'en': 'Today\'s Class Schedule',
    },
    'view_all': {
      'id': 'Lihat Semua',
      'en': 'View All',
    },
    'announcement': {
      'id': 'Pengumuman',
      'en': 'Announcements',
    },
    'assistant_ai': {
      'id': 'Asisten AI',
      'en': 'AI Assistant',
    },
    'no_class_title': {
      'id': 'Tidak ada jadwal kuliah hari ini',
      'en': 'No classes scheduled for today',
    },
    'no_class_subtitle': {
      'id': 'Selamat istirahat dan selamat mengerjakan tugas ✨',
      'en': 'Enjoy your rest and happy working on your assignments ✨',
    },
  };

  /// Ambil teks terjemahan berdasarkan key dan context.
  static String tr(BuildContext context, String key, [String? fallback]) {
    try {
      final isEnglish = context.watch<LanguageProvider>().isEnglish;
      final langKey = isEnglish ? 'en' : 'id';
      final entry = _dict[key];
      if (entry != null && entry.containsKey(langKey)) {
        return entry[langKey]!;
      }
    } catch (_) {}
    return fallback ?? key;
  }

  /// Ambil teks terjemahan tanpa listening (untuk callback atau initState).
  static String trRead(BuildContext context, String key, [String? fallback]) {
    try {
      final isEnglish = context.read<LanguageProvider>().isEnglish;
      final langKey = isEnglish ? 'en' : 'id';
      final entry = _dict[key];
      if (entry != null && entry.containsKey(langKey)) {
        return entry[langKey]!;
      }
    } catch (_) {}
    return fallback ?? key;
  }
}

/// Extension helper pada BuildContext agar pemanggilan sangat ringkas: context.tr('key')
extension AppStringsContextX on BuildContext {
  String tr(String key, [String? fallback]) => AppStrings.tr(this, key, fallback);
  String trRead(String key, [String? fallback]) => AppStrings.trRead(this, key, fallback);
  bool get isEnglish {
    try {
      return watch<LanguageProvider>().isEnglish;
    } catch (_) {
      return false;
    }
  }
}

