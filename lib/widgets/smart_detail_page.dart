import 'package:flutter/material.dart';

import '../screens/kurikulum_screen.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/smart.dart';
import 'async_page.dart';
import 'common.dart';
import 'gradient_header.dart';
import 'smart_json.dart';

/// Halaman detail ramah pengguna: menampilkan data mata kuliah / jadwal,
/// presensi, kurikulum, dan modul lainnya secara bersih dan elegan,
/// tanpa memaparkan kode JSON mentah ke pengguna.
class SmartDetailPage extends StatelessWidget {
  const SmartDetailPage({
    super.key,
    required this.title,
    this.subtitle,
    required this.load,
    this.printLoader,
    this.initialData,
  });

  final String title;
  final String? subtitle;
  final Future<dynamic> Function() load;

  /// Opsional: loader yang mengembalikan URL cetak (dibuka di browser).
  final Future<dynamic> Function()? printLoader;

  /// Data awal yang sudah diketahui (mis. dari kartu yang diklik di KRS/Jadwal)
  final Map<String, dynamic>? initialData;

  Future<void> _doPrint(BuildContext context) async {
    try {
      final resp = await printLoader!();
      String? url;
      if (resp is Map) {
        for (final key in ['url', 'cetak_url', 'link', 'file']) {
          final v = resp[key] ?? (resp['data'] is Map ? resp['data'][key] : null);
          if (v is String && v.startsWith('http')) {
            url = v;
            break;
          }
        }
      }
      if (url == null && context.mounted) {
        appToast(context, 'URL cetak tidak ditemukan.', error: true);
        return;
      }
      if (context.mounted) await openExternal(context, url!);
    } catch (e) {
      if (context.mounted) appToast(context, errorText(e), error: true);
    }
  }

  static String cleanText(dynamic raw) {
    if (raw == null) return '';
    final s = raw.toString().trim();
    if (s.isEmpty || s == 'null') return '';
    // Hapus tag HTML jika ada
    final stripped = s
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return stripped == 'null' ? '' : stripped;
  }

  Map<String, dynamic> _extractMergedData(dynamic data) {
    final merged = <String, dynamic>{};
    if (initialData != null) {
      merged.addAll(initialData!);
    }

    dynamic raw = data;
    if (raw is Map) {
      // Unpack { "raw_json": { "data": { ... } } } atau { "data": { ... } }
      if (raw['raw_json'] is Map) {
        raw = raw['raw_json'];
      }
      if (raw is Map && raw['data'] is Map) {
        raw = raw['data'];
      }
      if (raw is Map) {
        merged.addAll(asMap(raw));
      } else if (raw is List) {
        merged['items'] = raw;
      }
    } else if (raw is List) {
      merged['items'] = raw;
    }

    // Pastikan jika ada key 'data' yang berupa map di dalam merged, di-unwrap
    if (merged['data'] is Map) {
      final inner = asMap(merged['data']);
      merged.remove('data');
      merged.addAll(inner);
    }
    merged.remove('raw_json');
    merged.remove('success');

    return merged;
  }

  bool _isJadwal(String t, Map<String, dynamic> m) {
    final lt = t.toLowerCase();
    if (lt.contains('jadwal') || lt.contains('mata kuliah') || lt.contains('kuliah')) {
      return true;
    }
    const scheduleKeys = [
      'name', 'nama_mk', 'nm_mk', 'mata_kuliah', 'matakuliah',
      'code', 'kode_mk', 'kd_mk', 'credits', 'sks',
      'day', 'hari', 'start_time', 'end_time', 'jam',
      'room', 'ruang', 'class', 'kelas', 'lecturers', 'dosen',
    ];
    return scheduleKeys.any((k) => m.containsKey(k) && m[k] != null && m[k].toString().isNotEmpty);
  }

  bool _isPresensi(String t, Map<String, dynamic> m) {
    final lt = t.toLowerCase();
    if (lt.contains('presensi') || lt.contains('kehadiran') || lt.contains('absensi')) {
      return true;
    }
    return m.containsKey('pertemuan') && m['pertemuan'] is List;
  }

  bool _isKurikulum(String t, Map<String, dynamic> m) {
    final lt = t.toLowerCase();
    if (lt.contains('kurikulum')) return true;
    return m.containsKey('mata_kuliah') &&
        (m.containsKey('info') || m.containsKey('stats') || m.containsKey('summary'));
  }

  @override
  Widget build(BuildContext context) {
    final effectiveSubtitle = subtitle ??
        (title.toLowerCase().contains('jadwal')
            ? 'Rincian jadwal perkuliahan'
            : (title.toLowerCase().contains('kurikulum')
                ? 'Struktur kurikulum & status mata kuliah'
                : (title.toLowerCase().contains('presensi')
                    ? 'Catatan kehadiran 16 pertemuan'
                    : 'Detail informasi')));

    return AsyncPage<dynamic>(
      title: title,
      subtitle: effectiveSubtitle,
      load: load,
      headerActions: printLoader != null
          ? [
              HeaderActionButton(
                icon: Icons.print_rounded,
                tooltip: 'Cetak',
                onPressed: () => _doPrint(context),
              )
            ]
          : null,
      builder: (context, data) {
        final merged = _extractMergedData(data);
        if (_isPresensi(title, merged)) {
          return _PresensiDetailBody(data: merged);
        }
        if (_isJadwal(title, merged)) {
          return _JadwalDetailBody(data: merged);
        }
        if (_isKurikulum(title, merged)) {
          return KurikulumDetailView(data: merged);
        }
        return _GenericDetailBody(data: merged);
      },
    );
  }
}

// ====================================================================
// Tampilan Khusus Detail Jadwal / Mata Kuliah (Bersih, Rapi & Elegan)
// ====================================================================

class _JadwalDetailBody extends StatelessWidget {
  const _JadwalDetailBody({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    // 1. Judul / Nama Mata Kuliah
    final title = pickString(data, [
      'name', 'nama_mk', 'nm_mk', 'mata_kuliah', 'nama', 'matakuliah', 'mk',
      'course_name', 'course_title',
    ], 'Mata Kuliah');

    // 2. Kode MK
    final kode = pickString(data, [
      'code', 'kode', 'kode_mk', 'kd_mk', 'course_code',
    ], '');

    // 3. SKS
    final sks = pickString(data, [
      'credits', 'credit', 'sks', 'bobot_sks', 'jml_sks', 'course_sks',
    ], '');

    // 4. Kelas
    final kelas = pickString(data, [
      'class', 'kelas', 'nama_kelas', 'kls', 'course_class',
    ], '');

    // 5. Semester
    final semester = pickString(data, [
      'semester', 'sem', 'smt', 'tingkat',
    ], '');

    // 6. Hari
    final hari = pickString(data, [
      'day', 'hari', 'hari_kuliah',
    ], '');

    // 7. Jam / Waktu
    String jam = pickString(data, [
      'jam', 'jam_kuliah', 'waktu', 'jadwal_waktu', 'time',
    ], '');
    if (jam.isEmpty) {
      final st = pickString(data, ['start_time', 'jam_mulai', 'mulai'], '');
      final et = pickString(data, ['end_time', 'jam_selesai', 'selesai'], '');
      if (st.isNotEmpty && et.isNotEmpty) {
        jam = '$st - $et';
      } else if (st.isNotEmpty) {
        jam = st;
      }
    }

    // 8. Ruang
    final ruang = pickString(data, [
      'room', 'ruang', 'kd_ruang', 'nama_ruang', 'ruangan', 'lokasi',
    ], '');

    // 9. Dosen Pengampu (Mendukung String ataupun List)
    String dosen = '';
    if (data['lecturers'] is List && (data['lecturers'] as List).isNotEmpty) {
      dosen = (data['lecturers'] as List)
          .map((e) => SmartDetailPage.cleanText(e))
          .where((s) => s.isNotEmpty)
          .join(', ');
    } else {
      dosen = pickString(data, [
        'dosen', 'nama_dosen', 'pengajar', 'dosen_pengampu', 'lecturer',
      ], '');
    }

    // 10. Kapasitas & Peserta
    final kapasitas = pickString(data, [
      'capacity', 'kapasitas', 'kuota', 'daya_tampung',
    ], '');
    final peserta = pickString(data, [
      'participants', 'peserta', 'terisi', 'jumlah_peserta',
    ], '');

    // 11. Status MK & Metode
    final status = pickString(data, [
      'status', 'status_mk', 'keterangan',
    ], '');
    final metode = pickString(data, [
      'metode', 'metode_utama', 'jenis_kuliah', 'sistem_kuliah',
    ], '');

    // 12. Prasyarat Mata Kuliah
    String prereqSummary = '';
    bool? prereqEligible;
    if (data['prerequisite'] is Map) {
      final prMap = asMap(data['prerequisite']);
      prereqSummary = pickString(prMap, ['summary', 'keterangan', 'desc', 'prasyarat'], '');
      if (prMap.containsKey('eligible')) {
        prereqEligible = prMap['eligible'] == true;
      }
    } else {
      prereqSummary = pickString(data, ['prasyarat', 'prerequisite_summary'], '');
      if (data.containsKey('prasyarat_eligible')) {
        prereqEligible = data['prasyarat_eligible'] == true;
      }
    }

    // 13. Tautan WhatsApp jika ada
    final waUrl = pickString(data, [
      'whatsapp_url', 'wa_url', 'link_wa', 'grup_wa',
    ], '');

    // Kumpulkan key tambahan yang belum ditampilkan
    const excludeKeys = {
      'name', 'nama', 'nama_mk', 'nm_mk', 'mata_kuliah', 'matakuliah', 'mk',
      'course_name', 'course_title',
      'code', 'kode', 'kode_mk', 'kd_mk', 'course_code',
      'credits', 'credit', 'sks', 'bobot_sks', 'jml_sks', 'course_sks',
      'class', 'kelas', 'nama_kelas', 'kls', 'course_class',
      'semester', 'sem', 'smt', 'tingkat',
      'day', 'hari', 'hari_kuliah',
      'start_time', 'end_time', 'jam_mulai', 'jam_selesai', 'mulai', 'selesai',
      'jam', 'jam_kuliah', 'waktu', 'jadwal_waktu', 'time',
      'room', 'ruang', 'kd_ruang', 'nama_ruang', 'ruangan', 'lokasi',
      'lecturers', 'lecturer', 'dosen', 'nama_dosen', 'pengajar', 'dosen_pengampu',
      'capacity', 'kapasitas', 'kuota', 'daya_tampung',
      'participants', 'peserta', 'terisi', 'jumlah_peserta',
      'status', 'status_mk', 'keterangan',
      'metode', 'metode_utama', 'jenis_kuliah', 'sistem_kuliah',
      'prerequisite', 'prasyarat', 'prasyarat_eligible', 'prerequisite_summary',
      'whatsapp_url', 'wa_url', 'link_wa', 'grup_wa',
      'token', 'delete_token', 'detail_token', 'kelas_token', 'id_token',
      'session', 'password', 'scraper', 'html', 'raw_json', 'data',
      'success', 'status_code', 'csrf', 'message', 'items', 'pertemuan',
    };

    final extraEntries = data.entries.where((e) {
      final k = e.key.toLowerCase().trim();
      if (excludeKeys.contains(k)) return false;
      if (k.contains('token') || k.contains('html') || k.contains('json') || k.contains('session')) {
        return false;
      }
      final v = e.value;
      if (v == null) return false;
      final s = v.toString().trim();
      return s.isNotEmpty && s != 'null' && s != '-';
    }).toList();

    // Cek apakah ada list sesi / pertemuan / materi
    final listItems = data['pertemuan'] is List
        ? (data['pertemuan'] as List)
        : (data['items'] is List ? (data['items'] as List) : null);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ----------------- Hero Card Mata Kuliah -----------------
        SurfaceCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // SKS Badge UPI Gold
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.upiYellowBright, AppColors.upiYellowDeep],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.upiYellowDeep.withValues(alpha: 0.25),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      '${sks.isNotEmpty ? sks : '-'} SKS',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (status.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                      decoration: BoxDecoration(
                        color: status.toLowerCase().contains('batal')
                            ? AppColors.red.withValues(alpha: 0.12)
                            : AppColors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: status.toLowerCase().contains('batal')
                              ? AppColors.red.withValues(alpha: 0.3)
                              : AppColors.green.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: status.toLowerCase().contains('batal')
                              ? AppColors.red
                              : AppColors.green,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (kode.isNotEmpty)
                    _heroChip(context, Icons.tag_rounded, 'Kode: $kode',
                        AppColors.upiYellowDeep),
                  if (kelas.isNotEmpty)
                    _heroChip(context, Icons.groups_rounded, 'Kelas $kelas',
                        AppColors.indigo700),
                  if (semester.isNotEmpty)
                    _heroChip(context, Icons.layers_rounded, 'Semester $semester',
                        AppColors.grey),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ----------------- Jadwal & Waktu Kuliah -----------------
        const SectionTitle('Jadwal & Ruangan'),
        const SizedBox(height: 10),
        SurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              _infoRow(
                context,
                icon: Icons.calendar_today_rounded,
                label: 'Hari Kuliah',
                value: hari.isNotEmpty ? hari : '-',
              ),
              const Divider(height: 1),
              _infoRow(
                context,
                icon: Icons.schedule_rounded,
                label: 'Jam Kuliah',
                value: jam.isNotEmpty ? '$jam WIB' : '-',
              ),
              const Divider(height: 1),
              _infoRow(
                context,
                icon: Icons.meeting_room_outlined,
                label: 'Ruang Kuliah',
                value: ruang.isNotEmpty ? ruang : '-',
              ),
              const Divider(height: 1),
              _infoRow(
                context,
                icon: Icons.person_outline_rounded,
                label: 'Dosen Pengampu',
                value: dosen.isNotEmpty ? dosen : '-',
              ),
              if (kapasitas.isNotEmpty || peserta.isNotEmpty) ...[
                const Divider(height: 1),
                _infoRow(
                  context,
                  icon: Icons.group_outlined,
                  label: 'Kapasitas Kelas',
                  value: (peserta.isNotEmpty && kapasitas.isNotEmpty)
                      ? '$peserta / $kapasitas Mahasiswa'
                      : (kapasitas.isNotEmpty ? '$kapasitas Mahasiswa' : '$peserta Peserta'),
                ),
              ],
              if (metode.isNotEmpty) ...[
                const Divider(height: 1),
                _infoRow(
                  context,
                  icon: Icons.cast_for_education_rounded,
                  label: 'Metode Pembelajaran',
                  value: metode,
                ),
              ],
            ],
          ),
        ),

        // ----------------- Prasyarat Mata Kuliah jika ada -----------------
        if (prereqSummary.isNotEmpty) ...[
          const SizedBox(height: 16),
          const SectionTitle('Prasyarat Mata Kuliah'),
          const SizedBox(height: 10),
          SurfaceCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: prereqEligible != false
                        ? AppColors.green.withValues(alpha: 0.12)
                        : AppColors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    prereqEligible != false
                        ? Icons.verified_rounded
                        : Icons.info_outline_rounded,
                    size: 20,
                    color: prereqEligible != false ? AppColors.green : AppColors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Status Prasyarat',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: context.textMuted,
                            ),
                          ),
                          const Spacer(),
                          if (prereqEligible != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: prereqEligible
                                    ? AppColors.green.withValues(alpha: 0.12)
                                    : AppColors.red.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                prereqEligible ? 'Memenuhi' : 'Belum Memenuhi',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: prereqEligible
                                      ? AppColors.green
                                      : AppColors.red,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        prereqSummary,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimary,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        // ----------------- Tombol WhatsApp jika ada -----------------
        if (waUrl.isNotEmpty && waUrl.startsWith('http')) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => openExternal(context, waUrl),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.chat_rounded, size: 19),
              label: const Text(
                'Gabung WhatsApp Grup Kelas',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
              ),
            ),
          ),
        ],

        // ----------------- Informasi Tambahan jika ada -----------------
        if (extraEntries.isNotEmpty) ...[
          const SizedBox(height: 18),
          const SectionTitle('Informasi Tambahan'),
          const SizedBox(height: 10),
          SurfaceCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(
              children: extraEntries.map((e) {
                final cleanedVal = SmartDetailPage.cleanText(e.value);
                return KeyValueRow(
                  label: labelify(e.key),
                  value: cleanedVal.isNotEmpty ? cleanedVal : '-',
                );
              }).toList(),
            ),
          ),
        ],

        // ----------------- List Sesi / Pertemuan jika ada -----------------
        if (listItems != null && listItems.isNotEmpty) ...[
          const SizedBox(height: 18),
          SectionTitle('Rincian Sesi (${listItems.length})'),
          const SizedBox(height: 10),
          for (var i = 0; i < listItems.length; i++)
            _sessionItemCard(context, i + 1, listItems[i]),
        ],

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _heroChip(BuildContext context, IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.upiYellowDeep.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.upiYellowDeep),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: context.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sessionItemCard(BuildContext context, int index, dynamic raw) {
    final m = asMap(raw);
    final judul = pickString(m, ['judul', 'topik', 'materi', 'nama', 'kegiatan'], 'Sesi $index');
    final tanggal = pickString(m, ['tanggal', 'tgl', 'waktu'], '');
    final ruang = pickString(m, ['ruang', 'lokasi'], '');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.border),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$index',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: AppColors.upiYellowDeep,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    judul,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimary,
                    ),
                  ),
                  if (tanggal.isNotEmpty || ruang.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        [if (tanggal.isNotEmpty) tanggal, if (ruang.isNotEmpty) 'Ruang $ruang'].join(' • '),
                        style: TextStyle(fontSize: 11.5, color: context.textMuted),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ====================================================================
// Tampilan Generik Bersih untuk Detail Lain (Kurikulum, Agenda, dll.)
// ====================================================================

class _GenericDetailBody extends StatelessWidget {
  const _GenericDetailBody({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    const hiddenKeys = {
      'token', 'session', 'password', 'scraper', 'html', 'raw_json',
      'success', 'status_code', 'csrf', 'message',
    };

    final entries = data.entries.where((e) {
      final k = e.key.toLowerCase().trim();
      if (hiddenKeys.contains(k)) return false;
      if (k.contains('token') || k.contains('html') || k.contains('session')) return false;
      return e.value != null;
    }).toList();

    if (entries.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          EmptyView(message: 'Tidak ada rincian data tersedia.'),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Column(
            children: entries.map((e) {
              final val = e.value;
              if (val is Map || val is List) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: SmartJson(data: val),
                );
              }
              final cleaned = SmartDetailPage.cleanText(val);
              return KeyValueRow(
                label: labelify(e.key),
                value: cleaned.isNotEmpty ? cleaned : '-',
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }
}

// ====================================================================
// Tampilan Khusus Detail Presensi / 16 Pertemuan (Rapi & Elegan)
// ====================================================================

class _PresensiDetailBody extends StatelessWidget {
  const _PresensiDetailBody({required this.data});
  final Map<String, dynamic> data;

  Color _percentColor(double v) {
    if (v >= 80) return AppColors.green;
    if (v >= 65) return AppColors.amber;
    return AppColors.red;
  }

  @override
  Widget build(BuildContext context) {
    final nama = pickString(data, ['nama', 'matkul', 'nama_mk', 'mata_kuliah'], 'Mata Kuliah');
    final kode = pickString(data, ['kode', 'kode_mk'], '');
    final kelas = pickString(data, ['kelas'], '');
    final dosen = pickString(data, ['dosen'], '');
    final hari = pickString(data, ['hari'], '');
    final jam = pickString(data, ['jam'], '');
    final catatan = pickString(data, ['catatan'], '');
    final kehadiranStr = pickString(data, ['kehadiran'], '0%');
    final kehadiranNum = double.tryParse(kehadiranStr.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;

    final pertemuanList = asList(data['pertemuan']).map((e) => asMap(e)).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      children: [
        // 1. HERO HEADER CARD
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.upiYellowDeep.withValues(alpha: 0.25)),
            boxShadow: [
              BoxShadow(
                color: AppColors.upiYellowDeep.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nama,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: context.textPrimary,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (kode.isNotEmpty)
                              _chip(context, Icons.tag_rounded, kode, AppColors.upiYellowDeep),
                            if (kelas.isNotEmpty)
                              _chip(context, Icons.groups_rounded, 'Kelas $kelas', AppColors.indigo700),
                            if (hari.isNotEmpty || jam.isNotEmpty)
                              _chip(context, Icons.schedule_rounded, [hari, jam].where((s) => s.isNotEmpty).join(', '), AppColors.grey),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _percentColor(kehadiranNum).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _percentColor(kehadiranNum).withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          kehadiranStr,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: _percentColor(kehadiranNum),
                          ),
                        ),
                        Text(
                          'Kehadiran',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _percentColor(kehadiranNum),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (dosen.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.person_outline_rounded, size: 14, color: context.textMuted),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        dosen,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.textMuted),
                      ),
                    ),
                  ],
                ),
              ],
              if (catatan.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.blue.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 15, color: AppColors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          catatan,
                          style: const TextStyle(fontSize: 11, color: AppColors.blue, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 18),

        // 2. SECTION TITLE: RINCIAN 16 PERTEMUAN
        SectionTitle('Rincian Pertemuan (${pertemuanList.length})'),
        const SizedBox(height: 10),

        // 3. DAFTAR PERTEMUAN
        if (pertemuanList.isEmpty)
          const EmptyView(message: 'Belum ada catatan pertemuan untuk mata kuliah ini.')
        else
          for (final p in pertemuanList)
            _pertemuanCard(context, p),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _chip(BuildContext context, IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }

  Widget _pertemuanCard(BuildContext context, Map<String, dynamic> p) {
    final pertemuanNo = pickString(p, ['pertemuan'], '01');
    final tanggal = pickString(p, ['tanggal'], '-');
    final jam = pickString(p, ['jam'], '-');
    final materi = pickString(p, ['materi'], 'Materi belum tersedia');
    final metode = pickString(p, ['metode'], '-');
    final status = pickString(p, ['status'], 'Belum Dilaksanakan');
    final statusKehadiran = pickString(p, ['status_kehadiran'], '');

    final Color badgeColor;
    final String badgeLabel;
    final IconData badgeIcon;

    final skLower = statusKehadiran.toLowerCase();
    final stLower = status.toLowerCase();

    if (skLower.contains('hadir')) {
      badgeColor = AppColors.green;
      badgeLabel = 'Hadir';
      badgeIcon = Icons.check_circle_rounded;
    } else if (skLower.contains('izin')) {
      badgeColor = AppColors.amber;
      badgeLabel = 'Izin';
      badgeIcon = Icons.event_available_rounded;
    } else if (skLower.contains('sakit')) {
      badgeColor = Colors.purple;
      badgeLabel = 'Sakit';
      badgeIcon = Icons.sick_rounded;
    } else if (skLower.contains('alpa') || skLower.contains('alpha')) {
      badgeColor = AppColors.red;
      badgeLabel = 'Alpa';
      badgeIcon = Icons.cancel_rounded;
    } else if (stLower.contains('belum')) {
      badgeColor = AppColors.grey;
      badgeLabel = status;
      badgeIcon = Icons.schedule_rounded;
    } else {
      badgeColor = AppColors.blue;
      badgeLabel = statusKehadiran.isNotEmpty ? statusKehadiran : status;
      badgeIcon = Icons.info_outline_rounded;
    }

    final isMateriAvailable = materi.toLowerCase() != 'materi belum tersedia' && materi.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.border),
      ),
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                decoration: BoxDecoration(
                  color: AppColors.upiYellowDeep.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Pertemuan $pertemuanNo',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.upiYellowDeep,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, size: 12, color: badgeColor),
                    const SizedBox(width: 4),
                    Text(
                      badgeLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: badgeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            materi,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isMateriAvailable ? FontWeight.w700 : FontWeight.w500,
              color: isMateriAvailable ? context.textPrimary : context.textMuted,
              fontStyle: isMateriAvailable ? FontStyle.normal : FontStyle.italic,
              height: 1.25,
            ),
          ),
          if (tanggal != '-' || jam != '-' || metode != '-') ...[
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                if (tanggal != '-')
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 11, color: context.textMuted),
                      const SizedBox(width: 4),
                      Text(tanggal, style: TextStyle(fontSize: 11, color: context.textMuted)),
                    ],
                  ),
                if (jam != '-')
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule_rounded, size: 11, color: context.textMuted),
                      const SizedBox(width: 4),
                      Text(jam, style: TextStyle(fontSize: 11, color: context.textMuted)),
                    ],
                  ),
                if (metode != '-')
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.apartment_rounded, size: 11, color: context.textMuted),
                      const SizedBox(width: 4),
                      Text(metode, style: TextStyle(fontSize: 11, color: context.textMuted)),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
