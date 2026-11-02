import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

/// Service untuk menangani OneSignal Push Notifications & Pengingat Kuliah
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const String oneSignalAppId = '22a91a3c-c65f-422c-a5a6-1039ed15729c';
  static const String _prefEnabledKey = 'notif_pengingat_kuliah_enabled';

  bool _initialized = false;
  String? _currentNim;

  /// Inisialisasi OneSignal saat aplikasi start
  Future<void> init() async {
    if (_initialized) return;

    try {
      if (kDebugMode) {
        OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      } else {
        OneSignal.Debug.setLogLevel(OSLogLevel.none);
      }

      // Initialize OneSignal
      OneSignal.initialize(oneSignalAppId);

      // Minta izin notifikasi ke user (Android 13+ & iOS)
      await OneSignal.Notifications.requestPermission(true);

      // Listener ketika notifikasi diklik oleh user
      OneSignal.Notifications.addClickListener((event) {
        debugPrint('[OneSignal] Notification clicked: ${event.notification.title}');
        final data = event.notification.additionalData;
        if (data != null && data['type'] == 'jadwal_reminder') {
          debugPrint('[OneSignal] Clicked reminder for: ${data['matkul']}');
        }
      });

      // Listener notifikasi muncul di foreground
      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        debugPrint('[OneSignal] Foreground notification received: ${event.notification.title}');
      });

      _initialized = true;
      debugPrint('[OneSignal] Inisialisasi berhasil dengan App ID: $oneSignalAppId');
    } catch (e) {
      debugPrint('[OneSignal] Gagal inisialisasi: $e');
    }
  }

  /// Hubungkan user login (NIM) ke OneSignal External ID
  Future<void> onLogin(String nim) async {
    _currentNim = nim.trim();
    if (_currentNim == null || _currentNim!.isEmpty) return;

    try {
      if (!_initialized) await init();

      // Set OneSignal External User ID = NIM
      await OneSignal.login(_currentNim!);
      await OneSignal.User.addTagWithKey('nim', _currentNim!);
      await OneSignal.User.addTagWithKey('reminder_15m', 'true');

      debugPrint('[OneSignal] Berhasil login user external_id: $_currentNim');
    } catch (e) {
      debugPrint('[OneSignal] Error onLogin: $e');
    }
  }

  /// Lepas user saat logout
  Future<void> onLogout() async {
    // Catatan: external_id tetap dipertahankan di device agar mahasiswa tetap
    // menerima notifikasi jadwal kuliahnya secara konsisten walaupun sesi app berakhir.
    // Jika ada akun lain yang login di device ini, OneSignal.login(newNim) akan otomatis menimpanya.
    _currentNim = null;
    debugPrint('[OneSignal] onLogout: token push tetap terikat pada NIM mahasiswa untuk pengingat perkuliahan');
  }

  /// Memastikan jadwal kuliah mahasiswa tersimpan permanen di HP dan server VPS.
  /// Dipanggil otomatis begitu user masuk atau membuka dashboard.
  Future<void> ensureJadwalSynced(ApiClient api, String nim) async {
    if (nim.isEmpty || nim == '-') return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncKey = 'jadwal_last_sync_$nim';
      final lastSync = prefs.getInt(lastSyncKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      // Sinkronisasi otomatis jika belum pernah sync atau sudah lewat 6 jam
      if (now - lastSync > 6 * 3600 * 1000) {
        final resp = await api.get('/api/akademik/jadwal');
        final raw = resp is Map ? (resp['data'] ?? resp) : resp;
        if (raw != null) {
          await syncJadwalWithServer(api, nim, raw);
          await prefs.setInt(lastSyncKey, now);
          debugPrint('[OneSignal] Jadwal untuk NIM $nim berhasil disimpan otomatis ke server');
        }
      }
    } catch (e) {
      debugPrint('[OneSignal] Info ensureJadwalSynced: $e');
    }
  }

  /// Apakah fitur pengingat kuliah diaktifkan oleh pengguna
  Future<bool> isReminderEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefEnabledKey) ?? true;
  }

  /// Ubah status pengingat kuliah
  Future<void> setReminderEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabledKey, enabled);
    try {
      await OneSignal.User.addTagWithKey('reminder_15m', enabled ? 'true' : 'false');
    } catch (_) {}
  }

  /// Sinkronisasikan data jadwal kuliah ke server agar server dapat mengirim notif 15 menit sebelum jam kuliah
  Future<void> syncJadwalWithServer(ApiClient api, String nim, dynamic rawJadwalData) async {
    if (nim.isEmpty || rawJadwalData == null) return;
    try {
      final payload = {
        'nim': nim,
        'jadwal': rawJadwalData,
        'app_id': oneSignalAppId,
      };

      await api.post(
        '/api/notifications/sync-jadwal',
        body: payload,
      );
      debugPrint('[OneSignal] Berhasil sinkronisasi jadwal reminder ke server untuk NIM $nim');
    } catch (e) {
      debugPrint('[OneSignal] Info: Sync jadwal reminder ke server: $e');
    }
  }
}
