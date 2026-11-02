import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../screens/kurikulum_screen.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/smart.dart';
import 'common.dart';
import 'smart_json.dart';

// ── UPI YPTK Golden Yellow Gradient ──
const _yellowHeaderGradient = [
  Color(0xFFE5A620), // Bright Academic Gold
  Color(0xFFD48B08), // UPI Yellow
  Color(0xFFB87500), // Deep Academic Gold
];

/// Halaman detail ramah pengguna: menampilkan data mata kuliah / jadwal,
/// presensi, kurikulum, dan modul lainnya secara bersih dan elegan dengan
/// Header Kurva Gelombang Emas UPI YPTK dan kartu Neumorphic.
class SmartDetailPage extends StatefulWidget {
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

  static String cleanText(dynamic raw) {
    if (raw == null) return '';
    final s = raw.toString().trim();
    if (s.isEmpty || s == 'null') return '';
    final stripped = s
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return stripped == 'null' ? '' : stripped;
  }

  @override
  State<SmartDetailPage> createState() => _SmartDetailPageState();
}

class _SmartDetailPageState extends State<SmartDetailPage> {
  late Future<dynamic> _future;
  dynamic _cachedData;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = widget.load();
    });
  }

  Future<void> _doPrint() async {
    if (widget.printLoader == null) return;
    try {
      final resp = await widget.printLoader!();
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
      if (!mounted) return;
      if (url == null) {
        appToast(context, 'URL cetak tidak ditemukan.', error: true);
        return;
      }
      await openExternal(context, url);
    } catch (e) {
      if (!mounted) return;
      appToast(context, errorText(e), error: true);
    }
  }

  Map<String, dynamic> _extractMergedData(dynamic data) {
    final merged = <String, dynamic>{};
    if (widget.initialData != null) {
      merged.addAll(widget.initialData!);
    }

    dynamic raw = data;
    if (raw is Map) {
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

  // ────────────────────────────────────────────────── NEUMORPHIC CARD HELPER
  Widget _buildNeuCard({
    required BuildContext context,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
    VoidCallback? onTap,
  }) {
    final isDark = context.isDark;
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF1F5F9),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.35)
                : const Color(0xFF94A3B8).withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
          if (!isDark)
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.9),
              blurRadius: 10,
              offset: const Offset(-2, -2),
            ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return IosBounceTap(onTap: onTap, child: content);
    }
    return content;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final bg = isDark ? const Color(0xFF000000) : const Color(0xFFF9FAFB);

    final mergedPreview = _extractMergedData(_cachedData ?? widget.initialData ?? {});

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          // ──── HEADER KUNING DENGAN LEKUKAN BERSAMBUNG ────
          _buildCurvedHeader(context, mergedPreview),

          // ──── BODY DETAIL CONTENT ────
          Expanded(
            child: FutureBuilder<dynamic>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting &&
                    _cachedData == null) {
                  return const Center(
                    child: LoadingView(label: 'Memuat rincian informasi...'),
                  );
                }
                if (snap.hasError && _cachedData == null) {
                  return ErrorRetry(
                    message: errorText(snap.error!),
                    onRetry: _reload,
                  );
                }
                if (snap.hasData) {
                  _cachedData = snap.data;
                }
                if (_cachedData == null && widget.initialData == null) {
                  return const EmptyView(message: 'Rincian data tidak ditemukan');
                }

                final merged = _extractMergedData(_cachedData ?? widget.initialData ?? {});

                return RefreshIndicator(
                  color: AppColors.upiYellowDeep,
                  backgroundColor:
                      isDark ? const Color(0xFF1E1E22) : Colors.white,
                  onRefresh: () async {
                    _reload();
                    await _future;
                  },
                  child: _buildDetailContent(context, merged),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurvedHeader(BuildContext context, Map<String, dynamic> merged) {
    final canPop = Navigator.of(context).canPop();
    final effectiveSubtitle = widget.subtitle ??
        (widget.title.toLowerCase().contains('jadwal')
            ? 'Rincian jadwal perkuliahan'
            : (widget.title.toLowerCase().contains('kurikulum')
                ? 'Struktur kurikulum & status mata kuliah'
                : (widget.title.toLowerCase().contains('presensi')
                    ? 'Catatan kehadiran 16 pertemuan'
                    : 'Detail informasi')));

    // Ekstrak info mata kuliah jika tersedia
    final courseName = pickString(merged, [
      'name', 'nama_mk', 'nm_mk', 'mata_kuliah', 'nama', 'matakuliah', 'judul'
    ], '');
    final courseCode = pickString(merged, ['code', 'kode', 'kode_mk', 'kd_mk'], '');
    final courseClass = pickString(merged, ['class', 'kelas', 'nama_kelas'], '');
    final sks = pickString(merged, ['credits', 'credit', 'sks', 'bobot_sks'], '');

    return ClipPath(
      clipper: const SeamlessWaveClipper(),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: _yellowHeaderGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, kCurvedHeaderBottomPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Back + Title + Action buttons (Print / Refresh)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (canPop) ...[
                          IconButton(
                            onPressed: () {
                              Navigator.of(context).maybePop();
                            },
                            icon: const Icon(Icons.arrow_back_rounded,
                                color: Colors.white, size: 24),
                            tooltip: 'Kembali',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.printLoader != null) ...[
                          IosBounceTap(
                            onTap: _doPrint,
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.10),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.print_rounded,
                                  size: 19, color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 7),
                        ],
                        IosBounceTap(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _reload();
                            appToast(context, 'Memuat ulang detail...');
                          },
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.22),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.10),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.refresh_rounded,
                                size: 20, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Subtitle atau Course Quick Banner
                if (courseName.isNotEmpty) ...[
                  Text(
                    courseName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (courseCode.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            courseCode,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (courseClass.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Kelas $courseClass',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (sks.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$sks SKS',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ] else ...[
                  Text(
                    effectiveSubtitle,
                    style: const TextStyle(
                      color: Color(0xE6FFFFFF),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailContent(BuildContext context, Map<String, dynamic> merged) {
    if (_isPresensi(widget.title, merged)) {
      return _PresensiDetailBody(
        data: merged,
        neuCardBuilder: _buildNeuCard,
      );
    }
    if (_isJadwal(widget.title, merged)) {
      return _JadwalDetailBody(
        data: merged,
        neuCardBuilder: _buildNeuCard,
      );
    }
    if (_isKurikulum(widget.title, merged)) {
      return KurikulumDetailView(data: merged);
    }
    return _GenericDetailBody(
      data: merged,
      neuCardBuilder: _buildNeuCard,
    );
  }
}

// ====================================================================
// Tampilan Khusus Detail Jadwal / Mata Kuliah (Bersih, Rapi & Elegan)
// ====================================================================

class _JadwalDetailBody extends StatelessWidget {
  const _JadwalDetailBody({
    required this.data,
    required this.neuCardBuilder,
  });

  final Map<String, dynamic> data;
  final Widget Function({
    required BuildContext context,
    required Widget child,
    EdgeInsetsGeometry padding,
    VoidCallback? onTap,
  }) neuCardBuilder;

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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 104),
      children: [
        // ----------------- Hero Card Mata Kuliah -----------------
        neuCardBuilder(
          context: context,
          padding: const EdgeInsets.all(18),
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
        neuCardBuilder(
          context: context,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
          neuCardBuilder(
            context: context,
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: prereqEligible != false
                        ? AppColors.green.withValues(alpha: 0.12)
                        : AppColors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
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
                          fontWeight: FontWeight.w700,
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
          IosBounceTap(
            onTap: () => openExternal(context, waUrl),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF25D366),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF25D366).withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_rounded, size: 20, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Gabung WhatsApp Grup Kelas',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        // ----------------- Informasi Tambahan jika ada -----------------
        if (extraEntries.isNotEmpty) ...[
          const SizedBox(height: 18),
          const SectionTitle('Informasi Tambahan'),
          const SizedBox(height: 10),
          neuCardBuilder(
            context: context,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

        const SizedBox(height: 32),
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
            width: 38,
            height: 38,
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
      padding: const EdgeInsets.only(bottom: 10),
      child: neuCardBuilder(
        context: context,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$index',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                  color: AppColors.upiYellowDeep,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    judul,
                    style: TextStyle(
                      fontSize: 13.5,
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
  const _GenericDetailBody({
    required this.data,
    required this.neuCardBuilder,
  });

  final Map<String, dynamic> data;
  final Widget Function({
    required BuildContext context,
    required Widget child,
    EdgeInsetsGeometry padding,
    VoidCallback? onTap,
  }) neuCardBuilder;

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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 104),
      children: [
        neuCardBuilder(
          context: context,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
  const _PresensiDetailBody({
    required this.data,
    required this.neuCardBuilder,
  });

  final Map<String, dynamic> data;
  final Widget Function({
    required BuildContext context,
    required Widget child,
    EdgeInsetsGeometry padding,
    VoidCallback? onTap,
  }) neuCardBuilder;

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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 104),
      children: [
        // 1. HERO HEADER CARD NEUMORPHIC
        neuCardBuilder(
          context: context,
          padding: const EdgeInsets.all(18),
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
                const SizedBox(height: 12),
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
        SectionTitle('Rincian Pertemuan (${pertemuanList.length} Sesi)'),
        const SizedBox(height: 12),

        // 3. DAFTAR PERTEMUAN NEUMORPHIC
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: neuCardBuilder(
        context: context,
        padding: const EdgeInsets.all(14),
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
            const SizedBox(height: 10),
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
              const SizedBox(height: 10),
              Divider(height: 1, color: context.border.withValues(alpha: 0.5)),
              const SizedBox(height: 8),
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
      ),
    );
  }
}
