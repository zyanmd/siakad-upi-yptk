import 'dart:io' show Platform;

import 'package:flutter/foundation.dart'
    show ChangeNotifier, kIsWeb;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/app_update_service.dart';

/// Mengelola pemeriksaan pembaruan aplikasi: memuat versi client, memanggil
/// API `GET /api/app/version`, dan mengingat versi yang sudah di-skip.
class AppUpdateProvider extends ChangeNotifier {
  AppUpdateProvider(this._service);

  final AppUpdateService _service;

  static const _kSkippedVersion = 'siakad.skipped_update_version';

  /// Versi cadangan bila `PackageInfo` gagal dibaca di perangkat.
  static const _fallbackVersion = '1.0.1';

  /// Info update terakhir yang perlu ditampilkan, atau null bila tidak ada.
  AppUpdateInfo? pending;

  bool _checking = false;
  bool get checking => _checking;

  String _currentVersion = '';
  String get currentVersion => _currentVersion;

  bool _loaded = false;

  /// Periksa update. Aman dipanggil berkali-kali (hanya jalan sekali kecuali
  /// [force] true). Kegagalan jaringan diabaikan tanpa mengganggu pengguna.
  Future<void> maybeCheck({bool force = false}) async {
    if (_checking) return;
    if (_loaded && !force) return;
    _checking = true;
    try {
      if (_currentVersion.isEmpty) {
        _currentVersion = await _resolveVersion();
      }
      // Pastikan `current` selalu terkirim supaya server bisa membandingkan
      // versi; tanpa ini server mengembalikan status "ok" terus.
      final current =
          _currentVersion.isEmpty ? _fallbackVersion : _currentVersion;
      final info = await _service.check(
        currentVersion: current,
        platform: _platformName(),
      );
      _loaded = true;

      // Hanya tampilkan bila latest lebih tinggi dari versi aplikasi.
      if (AppUpdateInfo.compareVersion(info.latestVersion, current) <= 0) {
        pending = null;
        notifyListeners();
        return;
      }

      switch (info.status) {
        case AppUpdateStatus.force:
          // Wajib update selalu ditampilkan.
          pending = info;
          notifyListeners();
          break;
        case AppUpdateStatus.optional:
          final skipped = await _skippedVersion();
          if (skipped != info.latestVersion) {
            pending = info;
            notifyListeners();
          }
          break;
        case AppUpdateStatus.ok:
          break;
      }
    } catch (_) {
      // Diamkan; jangan ganggu pengalaman bila server/versi tak tersedia.
    } finally {
      _checking = false;
    }
  }

  /// Tandai pop up (opsional) sebagai ditunda agar tidak muncul lagi untuk
  /// versi yang sama.
  Future<void> dismissOptional(AppUpdateInfo info) async {
    pending = null;
    notifyListeners();
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_kSkippedVersion, info.latestVersion);
    } catch (_) {}
  }

  /// Dipakai saat pengguna menutup paksa/memuat ulang pop up force.
  void clearPending() {
    if (pending == null) return;
    pending = null;
    notifyListeners();
  }

  Future<String> _skippedVersion() async {
    try {
      final sp = await SharedPreferences.getInstance();
      return sp.getString(_kSkippedVersion) ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<String> _resolveVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (_) {
      return '';
    }
  }

  String? _platformName() {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
    } catch (_) {}
    return null;
  }
}
