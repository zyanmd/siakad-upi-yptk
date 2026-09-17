/// Helper pintar untuk membaca JSON hasil scraper yang bentuknya
/// bisa berubah-ubah: akses key defensif, pencarian rekursif (BFS),
/// dan deteksi list of map.

Map<String, dynamic> asMap(dynamic v) =>
    v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};

List<dynamic> asList(dynamic v) => v is List ? v : <dynamic>[];

/// Ambil nilai pertama yang tidak kosong dari daftar kandidat key
/// (case-insensitive, tanpa memedulikan separator).
dynamic pick(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v != null && v.toString().trim().isNotEmpty && v.toString() != 'null') {
      return v;
    }
  }
  // Fallback: normalisasi nama key.
  final normalized = <String, dynamic>{
    for (final e in m.entries)
      e.key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), ''): e.value,
  };
  for (final k in keys) {
    final kk = k.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final v = normalized[kk];
    if (v != null && v.toString().trim().isNotEmpty) return v;
  }
  return null;
}

String pickString(Map<String, dynamic> m, List<String> keys,
    [String fallback = '-']) {
  final v = pick(m, keys);
  if (v == null) return fallback;
  final s = v.toString().trim();
  return s.isEmpty ? fallback : s;
}

/// Cari nilai pertama yang cocok dengan [keys] di seluruh struktur JSON
/// secara BFS (level dulu) supaya key di level luar menang sebelum
/// masuk ke list yang lebih dalam.
dynamic deepFind(dynamic json, List<String> keys, {int maxDepth = 6}) {
  final queue = <_Node>[_Node(json, 0)];
  final seen = <dynamic>{};
  while (queue.isNotEmpty) {
    final node = queue.removeAt(0);
    if (node.depth > maxDepth) continue;
    final v = node.value;
    if (v == null) continue;
    if (v is Map) {
      final direct = pick(asMap(v), keys);
      if (direct != null) return direct;
      for (final child in v.values) {
        if (child is Map || child is List) {
          if (seen.add(child.hashCode)) queue.add(_Node(child, node.depth + 1));
        }
      }
    } else if (v is List) {
      for (final child in v) {
        if (child is Map || child is List) {
          if (seen.add(child.hashCode)) queue.add(_Node(child, node.depth + 1));
        }
      }
    }
  }
  return null;
}

/// Sama seperti [deepFind] tapi mencari List berisi Map di bawah key tertentu.
List<Map<String, dynamic>> deepFindMapList(dynamic json, List<String> keys,
    {int maxDepth = 6}) {
  final queue = <_Node>[_Node(json, 0)];
  final seen = <dynamic>{};
  while (queue.isNotEmpty) {
    final node = queue.removeAt(0);
    if (node.depth > maxDepth) continue;
    final v = node.value;
    if (v is Map) {
      final m = asMap(v);
      for (final k in keys) {
        final val = m[k];
        if (val is List && val.isNotEmpty && val.every((e) => e is Map)) {
          return val.map((e) => asMap(e)).toList();
        }
      }
      for (final child in v.values) {
        if (child is Map || child is List) {
          if (seen.add(child.hashCode)) queue.add(_Node(child, node.depth + 1));
        }
      }
    } else if (v is List) {
      for (final child in v) {
        if (child is Map || child is List) {
          if (seen.add(child.hashCode)) queue.add(_Node(child, node.depth + 1));
        }
      }
    }
  }
  return const [];
}

/// Cari list of map pertama di mana pun dalam struktur JSON.
List<Map<String, dynamic>> findMapList(dynamic json, {int maxDepth = 5}) {
  if (json == null || maxDepth <= 0) return const [];
  if (json is List) {
    if (json.isNotEmpty && json.every((e) => e is Map)) {
      return json.map((e) => asMap(e)).toList();
    }
    return const [];
  }
  if (json is Map) {
    for (final v in json.values) {
      final r = findMapList(v, maxDepth: maxDepth - 1);
      if (r.isNotEmpty) return r;
    }
  }
  return const [];
}

/// Deteksi struktur "map of list" (mis. jadwal per hari).
/// Return hanya pasangan yang value-nya list of map.
Map<String, List<Map<String, dynamic>>> mapOfLists(Map<String, dynamic> m) {
  final result = <String, List<Map<String, dynamic>>>{};
  m.forEach((key, value) {
    if (value is List && value.isNotEmpty && value.every((e) => e is Map)) {
      result[key] = value.map((e) => asMap(e)).toList();
    }
  });
  return result;
}

/// Kumpulkan semua pasangan token -> nilai dari sebuah item.
Map<String, String> tokensOf(Map<String, dynamic> item) {
  final out = <String, String>{};
  item.forEach((k, v) {
    final lk = k.toLowerCase();
    if (lk.contains('token') && v != null && v.toString().trim().isNotEmpty) {
      out[k] = v.toString();
    }
  });
  return out;
}

/// Ambil token detail dari item (untuk halaman detail).
String? detailTokenOf(Map<String, dynamic> item) {
  final v = pick(item, ['detail_token', 'token', 'kelas_token', 'id_token']);
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

/// Parse respons endpoint periode menjadi daftar opsi.
List<PeriodeOption> parsePeriode(dynamic resp) {
  dynamic raw = resp;
  if (raw is Map) {
    raw = raw['data'] ?? raw['periode'] ?? raw['list'] ?? raw['items'] ?? raw;
  }
  final out = <PeriodeOption>[];
  if (raw is List) {
    for (final e in raw) {
      if (e is Map) {
        final m = asMap(e);
        final value = pickString(m, ['periode', 'value', 'kode', 'id', 'tahun'],
            '');
        if (value.isEmpty) continue;
        final label = pickString(m,
            ['nama', 'label', 'text', 'keterangan', 'periode', 'tahun'], value);
        out.add(PeriodeOption(value: value, label: label));
      } else if (e != null && e.toString().trim().isNotEmpty) {
        final s = e.toString().trim();
        out.add(PeriodeOption(value: s, label: s));
      }
    }
  }
  return out;
}

/// Periode fallback berdasarkan tanggal hari ini (format 20261 / 20252).
String fallbackPeriode() {
  final now = DateTime.now();
  if (now.month >= 8) return '${now.year}1';
  return '${now.year - 1}2';
}

/// Tahun akademik berjalan, mis. "2026/2027".
String currentTahunAkademik() {
  final now = DateTime.now();
  if (now.month >= 8) return '${now.year}/${now.year + 1}';
  return '${now.year - 1}/${now.year}';
}

class _Node {
  _Node(this.value, this.depth);
  final dynamic value;
  final int depth;
}

class PeriodeOption {
  const PeriodeOption({required this.value, required this.label});
  final String value;
  final String label;
}
