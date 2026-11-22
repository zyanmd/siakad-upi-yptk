import 'package:dio/dio.dart';
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

  factory AppUpdateInfo.fromJson(
      Map<String, dynamic> json, String fallbackCurrent) {
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
  /// Bila gagal atau server offline, fallback ke GitHub Releases API langsung.
  Future<AppUpdateInfo> check({
    required String currentVersion,
    String? platform,
  }) async {
    try {
      final resp = await _api.get('/api/app/version', query: {
        if (currentVersion.isNotEmpty) 'current': currentVersion,
        if (platform != null && platform.isNotEmpty) 'platform': platform,
      });
      final map =
          resp is Map ? resp.cast<String, dynamic>() : <String, dynamic>{};
      final info = AppUpdateInfo.fromJson(map, currentVersion);
      if (info.hasUpdate) return info;
    } catch (_) {
      // Server offline / IP berubah, fallback langsung ke GitHub
    }

    try {
      final gh = await _checkGitHubDirectly(currentVersion);
      if (gh != null) return gh;
    } catch (_) {}

    return AppUpdateInfo.fromJson(const {}, currentVersion);
  }

  Future<AppUpdateInfo?> _checkGitHubDirectly(String currentVersion) async {
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        headers: {'User-Agent': 'Siakad-App-Mobile'},
      ));
      final resp = await dio.get<Map<String, dynamic>>(
        'https://api.github.com/repos/zyanmd/siakad-upi-yptk/releases/latest',
      );
      final data = resp.data;
      if (data == null) return null;

      final tag = (data['tag_name'] ?? '')
          .toString()
          .replaceAll(RegExp(r'^[vV]'), '')
          .trim();
      if (tag.isEmpty) return null;

      if (AppUpdateInfo.compareVersion(currentVersion, tag) >= 0) {
        return null;
      }

      String downloadUrl = (data['html_url'] ?? '').toString();
      final assets = data['assets'];
      if (assets is List) {
        for (final a in assets) {
          if (a is Map) {
            final name = (a['name'] ?? '').toString().toLowerCase();
            if (name.endsWith('.apk')) {
              downloadUrl =
                  (a['browser_download_url'] ?? downloadUrl).toString();
              break;
            }
          }
        }
      }

      final body = (data['body'] ?? '').toString().trim();
      final name = (data['name'] ?? 'Pembaruan v$tag Tersedia').toString();

      return AppUpdateInfo(
        status: AppUpdateStatus.optional,
        currentVersion: currentVersion,
        latestVersion: tag,
        minVersion: '1.0.0',
        forceUpdate: false,
        downloadUrl: downloadUrl,
        title: name,
        message: body.isNotEmpty
            ? body
            : 'Versi $tag telah dirilis di GitHub dengan berbagai fitur baru dan perbaikan.',
        githubUrl: (data['html_url'] ?? '').toString(),
      );
    } catch (_) {
      return null;
    }
  }
}
