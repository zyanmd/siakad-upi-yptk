import 'package:flutter/material.dart';

import '../main.dart' show appNavigatorKey;
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
      NotificationService.instance.onLogin(nim);
    }
    notifyListeners();
  }

  /// Login ke SIAKAD; melempar [ApiException] bila gagal.
  Future<void> login(String username, String password) async {
    // Bersihkan sesi lama sebelum mencoba login baru
    _sessionId = null;
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
    expired = false;
    await _store.saveAuth(sid, _user);
    await _store.saveUsername(username);

    // Daftarkan NIM ke OneSignal untuk push notification pengingat kuliah
    NotificationService.instance.onLogin(username);

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
      final resp = await _auth.me();
      final map = asMap(resp);
      if (map['success'] == true) {
        if (map['user'] is Map) {
          _user = asMap(map['user']);
          await _store.saveAuth(_sessionId!, _user);
        }
        return true;
      }
      _onUnauthorized();
      return false;
    } catch (e) {
      if (e is ApiException && (e.isAuthError || e.statusCode == 401)) {
        _onUnauthorized();
        return false;
      }
      // Error koneksi/offline sementara: jangan paksa logout
      return true;
    }
  }

  /// Logout + bersihkan penyimpanan lokal.
  Future<void> logout({bool callApi = true}) async {
    if (callApi && _sessionId != null) {
      try {
        await _auth.logout();
      } catch (_) {
        // Tetap logout lokal walau API gagal.
      }
    }
    _sessionId = null;
    _user = {};
    await _store.clearAuth();
    NotificationService.instance.onLogout();
    notifyListeners();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      appNavigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    });
  }

  void _onUnauthorized() {
    final hadSession = _sessionId != null;
    _sessionId = null;
    _user = {};
    expired = true;
    _store.clearAuth();
    NotificationService.instance.onLogout();
    notifyListeners();

    if (hadSession) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        appNavigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );
      });
    }
  }
}
