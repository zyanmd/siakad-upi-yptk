import 'api_client.dart';

/// Seluruh endpoint akademik: /api/akademik/*
class AkademikService {
  AkademikService(this._api);

  final ApiClient _api;

  // ---------------------------------------------------------- Umum

  Future<dynamic> periode() =>
      _api.get('/api/akademik/periode', query: {'for': 'krs'});

  Future<dynamic> profil() => _api.get('/api/akademik/profil');

  Future<dynamic> updateProfil(Map<String, dynamic> body) =>
      _api.patch('/api/akademik/profil', body: body);

  // ---------------------------------------------------------- KRS

  Future<dynamic> krs(String periode) =>
      _api.get('/api/akademik/krs', query: {'periode': periode});

  Future<dynamic> krsStatus() => _api.get('/api/akademik/krs/status');

  Future<dynamic> krsAvailable(
    String periode, {
    String? matakuliah,
    String? semester,
    String? kelas,
    String? hari,
    int? page,
  }) {
    final q = <String, dynamic>{'periode': periode};
    if (matakuliah != null && matakuliah.isNotEmpty) q['matakuliah'] = matakuliah;
    if (semester != null && semester.isNotEmpty) q['semester'] = semester;
    if (kelas != null && kelas.isNotEmpty) q['kelas'] = kelas;
    if (hari != null && hari.isNotEmpty) q['hari'] = hari;
    if (page != null) q['page'] = page;
    return _api.get('/api/akademik/krs/available', query: q);
  }

  Future<dynamic> krsAdd(Map<String, dynamic> body) =>
      _api.post('/api/akademik/krs/add', body: body);

  Future<dynamic> krsBulk(Map<String, dynamic> body) =>
      _api.post('/api/akademik/krs/bulk', body: body);

  Future<dynamic> krsDelete(String deleteToken) =>
      _api.delete('/api/akademik/krs/$deleteToken');

  Future<dynamic> krsJadwal(String detailToken, String periode) =>
      _api.get('/api/akademik/krs/jadwal/$detailToken',
          query: {'periode': periode});

  Future<dynamic> krsKurikulum(String periode) =>
      _api.get('/api/akademik/krs/kurikulum', query: {'periode': periode});

  Future<dynamic> krsCetakUrl(String periode) =>
      _api.get('/api/akademik/krs/cetak-url', query: {'periode': periode});

  Future<dynamic> krsCetak(String periode) =>
      _api.get('/api/akademik/krs/cetak', query: {'periode': periode});

  // ---------------------------------------------------------- Jadwal

  Future<dynamic> jadwal(String periode) =>
      _api.get('/api/akademik/jadwal', query: {'periode': periode});

  Future<dynamic> jadwalData(String periode) =>
      _api.get('/api/akademik/jadwal/data', query: {'periode': periode});

  Future<dynamic> jadwalDetail(String detailToken, String periode) =>
      _api.get('/api/akademik/jadwal/detail/$detailToken',
          query: {'periode': periode});

  Future<dynamic> jadwalCetakUrl(String periode) =>
      _api.get('/api/akademik/jadwal/cetak-url', query: {'periode': periode});

  Future<dynamic> jadwalCetak(String periode) =>
      _api.get('/api/akademik/jadwal/cetak', query: {'periode': periode});

  // ---------------------------------------------------------- Presensi

  Future<dynamic> presensi(String periode) =>
      _api.get('/api/akademik/presensi', query: {'periode': periode});

  Future<dynamic> presensiData(String periode) =>
      _api.get('/api/akademik/presensi/data', query: {'periode': periode});

  Future<dynamic> presensiDetail(String detailToken, String periode) =>
      _api.get('/api/akademik/presensi/detail/$detailToken',
          query: {'periode': periode});

  // ---------------------------------------------------------- Materi

  Future<dynamic> materi(String periode) =>
      _api.get('/api/akademik/materi', query: {'periode': periode});

  Future<dynamic> materiKelas(String kelasToken, String periode) =>
      _api.get('/api/akademik/materi/kelas/$kelasToken',
          query: {'periode': periode});

  // ---------------------------------------------------------- Kartu Ujian

  Future<dynamic> kartuUjian(String jenis, String periode) =>
      _api.get('/api/akademik/kartu-ujian',
          query: {'jenis': jenis, 'periode': periode});

  Future<dynamic> kartuUjianData(String jenis, String periode) =>
      _api.get('/api/akademik/kartu-ujian/data',
          query: {'jenis': jenis, 'periode': periode});

  Future<dynamic> kartuUjianCetakUrl(String jenis, String periode) =>
      _api.get('/api/akademik/kartu-ujian/cetak-url',
          query: {'jenis': jenis, 'periode': periode});

  // ---------------------------------------------------------- KHS

  Future<dynamic> khsPeriode() => _api.get('/api/akademik/khs/periode');

  Future<dynamic> khs(String periode) =>
      _api.get('/api/akademik/khs', query: {'periode': periode});

  Future<dynamic> khsData(String periode) =>
      _api.get('/api/akademik/khs/data', query: {'periode': periode});

  Future<dynamic> khsCetakUrl(String periode) =>
      _api.get('/api/akademik/khs/cetak-url', query: {'periode': periode});

  // ---------------------------------------------------------- Transkrip

  Future<dynamic> transkrip() => _api.get('/api/akademik/transkrip');

  Future<dynamic> transkripData() => _api.get('/api/akademik/transkrip/data');

  Future<dynamic> transkripCetakUrl() =>
      _api.get('/api/akademik/transkrip/cetak-url');

  // ---------------------------------------------------------- Kalender

  Future<dynamic> kalender(String tahun) =>
      _api.get('/api/akademik/kalender', query: {'tahun': tahun});

  Future<dynamic> kalenderData(String tahun) =>
      _api.get('/api/akademik/kalender/data', query: {'tahun': tahun});

  Future<dynamic> kalenderDetail(String token) =>
      _api.get('/api/akademik/kalender/detail/$token');

  Future<dynamic> kalenderCetakUrl(String token) =>
      _api.get('/api/akademik/kalender/cetak-url/$token');
}
