import 'api_client.dart';

/// Status update yang dikembalikan server pada `GET /api/app/version`.
enum AppUpdateStatus { ok, optional, force }

/// Hasil pemeriksaan versi aplikasi.
class AppUpdateInfo {
  const AppUpdateInfo({
    required this.status,
    required this.currentVersion,
    required this.latestVersion,
    required this.minVersion,
    required this.forceUpdate,
    required this.downloadUrl,
    required this.title,
    required this.message,
    this.githubUrl,
  });

  final AppUpdateStatus status;
  final String? currentVersion;
  final String latestVersion;
  final String minVersion;
  final bool forceUpdate;
  final String downloadUrl;
  final String title;
  final String message;
  final String? githubUrl;

  bool get hasUpdate => status != AppUpdateStatus.ok;

  /// Bandingkan versi (a<b → -1, a==b → 0, a>b → 1).
  static int compareVersion(String a, String b) {
    final pa = parseVersion(a);
    final pb = parseVersion(b);
    for (var i = 0; i < 3; i++) {
      if (pa[i] != pb[i]) return pa[i] < pb[i] ? -1 : 1;
    }
    return 0;
  }

  static List<int> parseVersion(String v) {
    var clean = v.trim();
    if (clean.startsWith('v') || clean.startsWith('V')) {
      clean = clean.substring(1);
    }
    if (clean.contains('+')) {
      clean = clean.split('+').first;
    }
    if (clean.contains('-')) {
      clean = clean.split('-').first;
    }
    final out = <int>[0, 0, 0];
    final parts = clean.split('.');
    for (var i = 0; i < 3 && i < parts.length; i++) {
      out[i] = int.tryParse(parts[i].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }
    return out;
  }

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json, String fallbackCurrent) {
    final rawStatus = (json['status'] ?? 'ok').toString().toLowerCase();
    var status = switch (rawStatus) {
      'force' => AppUpdateStatus.force,
      'optional' => AppUpdateStatus.optional,
      _ => AppUpdateStatus.ok,
    };
    final current = _str(json['current_version']) ?? fallbackCurrent;
    final latest = _str(json['latest_version']) ?? fallbackCurrent;
    final minimum = _str(json['min_version']) ?? fallbackCurrent;

    // Jaring pengaman: bila server tidak menghitung status (mis. `current`
    // tidak terkirim) tetapi versi client jelas lebih rendah, hitung sendiri.
    if (status == AppUpdateStatus.ok && current.isNotEmpty) {
      if (compareVersion(current, minimum) < 0) {
        status = AppUpdateStatus.force;
      } else if (compareVersion(current, latest) < 0) {
        status = AppUpdateStatus.optional;
      }
    }

    return AppUpdateInfo(
      status: status,
      currentVersion: current,
      latestVersion: latest,
      minVersion: minimum,
      forceUpdate:
          json['force_update'] == true || status == AppUpdateStatus.force,
      downloadUrl: _str(json['download_url']) ?? '',
      title: _str(json['title']) ?? 'Pembaruan Tersedia',
      message: _str(json['message']) ??
          'Versi terbaru aplikasi sudah tersedia. Silakan perbarui untuk pengalaman terbaik.',
      githubUrl: _str(json['github_url']),
    );
  }

  static String? _str(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }
}

/// Layanan pemeriksaan update aplikasi (endpoint publik, tanpa sesi).
class AppUpdateService {
  AppUpdateService(this._api);

  final ApiClient _api;

  /// Panggil `GET /api/app/version?current=...&platform=...`.
  ///
  /// [currentVersion] adalah versi client (mis. "1.0.0"), [platform] salah
  /// satu dari `android`, `ios`, `web`.
  Future<AppUpdateInfo> check({
    required String currentVersion,
    String? platform,
  }) async {
    final resp = await _api.get('/api/app/version', query: {
      if (currentVersion.isNotEmpty) 'current': currentVersion,
      if (platform != null && platform.isNotEmpty) 'platform': platform,
    });
    final map = resp is Map ? resp.cast<String, dynamic>() : <String, dynamic>{};
    return AppUpdateInfo.fromJson(map, currentVersion);
  }
}
