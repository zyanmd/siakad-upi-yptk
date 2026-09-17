import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../utils/smart.dart';

/// Daftar periode akademik global (dipakai KRS, Jadwal, Presensi,
/// Materi, Kartu Ujian). Diambil sekali lalu dibagikan antar halaman.
class PeriodeProvider extends ChangeNotifier {
  PeriodeProvider(this._api);

  final ApiClient _api;

  List<PeriodeOption> items = const [];
  String? value;
  bool loaded = false;
  bool _loading = false;

  String get label =>
      items.where((e) => e.value == value).firstOrNull?.label ??
      (value ?? '-');

  Future<void> ensureLoaded() async {
    if (loaded || _loading) return;
    _loading = true;
    try {
      final resp = await _api.get('/api/akademik/periode');
      items = parsePeriode(resp);
      loaded = true;
      if (value == null || !items.any((e) => e.value == value)) {
        value = items.isNotEmpty ? items.first.value : fallbackPeriode();
      }
    } catch (_) {
      // API gagal: pakai periode fallback agar aplikasi tetap jalan.
      items = const [];
      value ??= fallbackPeriode();
      loaded = true;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> forceReload() async {
    loaded = false;
    await ensureLoaded();
  }

  void set(String v) {
    if (v == value) return;
    value = v;
    notifyListeners();
  }

  void reset() {
    items = const [];
    value = null;
    loaded = false;
    _loading = false;
  }
}
