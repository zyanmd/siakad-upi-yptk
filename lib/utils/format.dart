/// Util format tampilan (rupiah, label, inisial).
library;

const Map<String, String> _kLabels = {
  'nim': 'NIM',
  'npm': 'NPM',
  'nidn': 'NIDN',
  'ipk': 'IPK',
  'ips': 'IPS',
  'ip': 'IP',
  'sks': 'SKS',
  'krs': 'KRS',
  'khs': 'KHS',
  'uts': 'UTS',
  'uas': 'UAS',
  'va': 'VA',
  'no_va': 'No. Virtual Account',
  'id': 'ID',
  'url': 'URL',
  'api': 'API',
  'prodi': 'Program Studi',
  'program_studi': 'Program Studi',
  'fakultas': 'Fakultas',
  'dosen': 'Dosen',
  'dosen_pa': 'Dosen Pembimbing',
  'wali': 'Dosen Wali',
  'sem': 'Semester',
  'smt': 'Semester',
  'tgl': 'Tanggal',
  'tgl_ujian': 'Tanggal Ujian',
  'no_kursi': 'No. Kursi',
  'ruang': 'Ruang',
  'ruangan': 'Ruang',
  'kd_mk': 'Kode MK',
  'kode_mk': 'Kode MK',
  'nm_mk': 'Mata Kuliah',
  'nama_mk': 'Mata Kuliah',
  'mk': 'Mata Kuliah',
  'jam': 'Jam',
  'hari': 'Hari',
  'kelas': 'Kelas',
  'status': 'Status',
  'catatan': 'Catatan',
  'updated_at': 'Diperbarui',
  'created_at': 'Dibuat',
};

const Set<String> _moneyExact = {
  'nominal',
  'total',
  'total_invoice',
  'total_tagihan',
  'biaya',
  'harga',
  'denda',
  'subtotal',
  'amount',
  'sisa',
  'dibayar',
  'terbayar',
  'nilai_bayar',
};

/// "nomor_va" -> "Nomor Va" dengan bantuan kamus khusus.
String labelify(String key) {
  final k = key.trim();
  if (k.isEmpty) return k;
  final lower = k.toLowerCase();
  if (_kLabels.containsKey(lower)) return _kLabels[lower]!;
  final words = lower.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim().split(' ');
  final titled = words
      .where((w) => w.isNotEmpty)
      .map((w) =>
          w.substring(0, 1).toUpperCase() + w.substring(1))
      .join(' ');
  return titled.isEmpty ? k : titled;
}

bool _isMoneyKey(String key) {
  final lk = key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
  if (_moneyExact.contains(lk)) return true;
  const suffixes = ['nominal', 'total', 'denda', 'biaya', 'harga', 'amount'];
  for (final s in suffixes) {
    if (lk.endsWith('_$s') || lk == s) return true;
  }
  return false;
}

String _groupDigits(String digits) {
  final buf = StringBuffer();
  final n = digits.length;
  for (var i = 0; i < n; i++) {
    buf.write(digits[i]);
    final left = n - i - 1;
    if (left > 0 && left % 3 == 0) buf.write('.');
  }
  return buf.toString();
}

/// Format nilai jadi Rupiah bila memungkinkan, apa adanya bila bukan angka.
String rupiah(dynamic v) {
  if (v == null) return '-';
  if (v is num) {
    if (v == v.roundToDouble()) return 'Rp ${_groupDigits(v.round().toString())}';
    return 'Rp ${_groupDigits(v.toStringAsFixed(0))}';
  }
  final s = v.toString().trim();
  if (s.isEmpty) return '-';
  if (s.toLowerCase().contains('rp')) return s;
  final cleaned = s.replaceAll(RegExp(r'[^0-9]'), '');
  if (cleaned.isEmpty || cleaned.length > 15) return s;
  return 'Rp ${_groupDigits(cleaned)}';
}

/// Format nilai untuk baris key-value dengan heuristik sederhana.
String formatValue(String key, dynamic v) {
  if (v == null) return '-';
  if (v is bool) return v ? 'Ya' : 'Tidak';
  final lk = key.toLowerCase();
  if (_isMoneyKey(key)) return rupiah(v);
  if (lk.contains('persen') && v is num) return '$v%';
  final s = v.toString().trim();
  return s.isEmpty ? '-' : s;
}

/// Inisial nama untuk avatar, mis. "Budi Santoso" -> "BS".
String initialsOf(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    return parts.first.substring(0, parts.first.length > 1 ? 2 : 1).toUpperCase();
  }
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
}
