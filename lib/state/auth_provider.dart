import 'dart:async' show unawaited;
import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/session_store.dart';
import '../utils/smart.dart';

/// Status login aplikasi: bootstrap sesi tersimpan, login, logout,
/// dan penanganan sesi kedaluwarsa otomatis (HTTP 401).
class AuthProvider extends ChangeNotifier {
  AuthProvider(this._api, this._store)
      : _auth = AuthService(_api) {
    _api.onUnauthorized = _onUnauthorized;
  }

  final ApiClient _api;
  final SessionStore _store;
  final AuthService _auth;

  String? _sessionId;
  Map<String, dynamic> _user = {};
  Map<String, dynamic>? initialDashboard;
  bool _booted = false;

  /// True bila sesi berakhir dipaksa (401), untuk banner di login.
  bool expired = false;

  bool get isAuthed => _sessionId != null;
  String? get sessionId => _sessionId;
  Map<String, dynamic> get user => _user;

  String get nama {
    final v = pickString(_user, ['nama', 'name', 'nama_mahasiswa', 'fullname'],
        'Mahasiswa');
    return v;
  }

  String get nim {
    return pickString(_user, ['nim', 'username', 'npm', 'nomor_induk'], '-');
  }

  /// Muat sesi tersimpan saat aplikasi dibuka.
  Future<void> bootstrap() async {
    if (_booted) return;
    await _store.load();
    _sessionId = _store.sessionIdCached;
    _user = _store.userCached;
    _booted = true;
    if (_sessionId != null && nim != '-') {
      unawaited(NotificationService.instance.onLogin(nim));
    }
    notifyListeners();
  }

  /// Login ke SIAKAD; melempar [ApiException] bila gagal.
  Future<void> login(String username, String password) async {
    // Bersihkan sesi lama sebelum mencoba login baru
    _sessionId = null;
    initialDashboard = null;
    await _store.clearAuth();

    final resp = await _auth.login(username, password);
    final map = asMap(resp);
    if (map['success'] != true) {
      throw ApiException(
          pickString(map, ['message'], 'Login gagal. Periksa NIM/password.'));
    }
    final sid = map['session_id']?.toString();
    if (sid == null || sid.isEmpty) {
      throw ApiException('Respons login tidak valid (session_id kosong).');
    }
    _sessionId = sid;
    _user = asMap(map['user']);
    if (map['dashboard'] is Map) {
      initialDashboard = asMap(map['dashboard']);
    }
    expired = false;
    await _store.saveAuth(sid, _user);
    await _store.saveUsername(username);

    // Daftarkan NIM ke OneSignal untuk push notification pengingat kuliah di background
    unawaited(NotificationService.instance.onLogin(username));

    notifyListeners();
  }

  /// Perpanjang masa aktif sesi ke server (sliding refresh manual).
  Future<bool> refreshSession() async {
    if (_sessionId == null) return false;
    try {
      final resp = await _auth.refresh();
      final map = asMap(resp);
      return map['success'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Validasi apakah sesi yang tersimpan di memori/storage masih aktif di server.
  /// Bila sesi sudah kadaluarsa (HTTP 401), otomatis hapus sesi dan tandai [expired] = true.
  Future<bool> validateSession() async {
    if (_sessionId == null) return false;
    try {
      final resp = await _api.get('/api/auth/me');
      final map = asMap(resp);
      return map['success'] == true;
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.isAuthError) {
        _onUnauthorized();
      }
      return false;
    } catch (_) {
      // Kesalahan jaringan umum (offline dsb) jangan membatalkan sesi lokal
      return true;
    }
  }

  /// Logout lokal dan server; abaikan error server agar user tetap bisa keluar.
  Future<void> logout() async {
    try {
      if (_sessionId != null) {
        await _auth.logout();
      }
    } catch (_) {}
    _sessionId = null;
    _user = {};
    initialDashboard = null;
    expired = false;
    await _store.clearAuth();
    unawaited(NotificationService.instance.onLogout());
    notifyListeners();
  }

  /// Callback otomatis dipanggil oleh [ApiClient] bila menerima HTTP 401.
  /// Memastikan user langsung diarahkan ke halaman login dari layar mana pun.
  void _onUnauthorized() {
    // Hanya picu redirect bila user memang sebelumnya memegang sesi aktif.
    if (_sessionId == null) return;
    _sessionId = null;
    _user = {};
    initialDashboard = null;
    expired = true;
    _store.clearAuth();
    notifyListeners();
  }
}
