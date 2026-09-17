import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Penyimpanan lokal (session, user, tema, username terakhir).
class SessionStore {
  static const _kSession = 'siakad.session_id';
  static const _kUser = 'siakad.user';
  static const _kTheme = 'siakad.theme_mode';
  static const _kUsername = 'siakad.username';

  /// Cache in-memory agar header X-Session-Id bisa dibaca sinkron.
  String? sessionIdCached;
  Map<String, dynamic> userCached = {};
  String themeModeCached = 'system';
  String usernameCached = '';

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    sessionIdCached = sp.getString(_kSession);
    themeModeCached = sp.getString(_kTheme) ?? 'system';
    usernameCached = sp.getString(_kUsername) ?? '';
    final rawUser = sp.getString(_kUser);
    if (rawUser != null) {
      try {
        final decoded = jsonDecode(rawUser);
        if (decoded is Map) userCached = decoded.cast<String, dynamic>();
      } catch (_) {
        userCached = {};
      }
    }
  }

  Future<void> saveAuth(String sessionId, Map<String, dynamic> user) async {
    sessionIdCached = sessionId;
    userCached = user;
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kSession, sessionId);
    await sp.setString(_kUser, jsonEncode(user));
  }

  Future<void> saveUsername(String username) async {
    usernameCached = username;
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kUsername, username);
  }

  Future<void> clearAuth() async {
    sessionIdCached = null;
    userCached = {};
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kSession);
    await sp.remove(_kUser);
  }

  Future<void> saveThemeMode(String mode) async {
    themeModeCached = mode;
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kTheme, mode);
  }
}
