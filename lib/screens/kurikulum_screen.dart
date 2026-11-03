import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../utils/smart.dart';
import '../widgets/common.dart';

// ── UPI YPTK Golden Yellow Gradient ──
const _yellowHeaderGradient = [
  Color(0xFFE5A620), // Bright Academic Gold
  Color(0xFFD48B08), // UPI Yellow
  Color(0xFFB87500), // Deep Academic Gold
];

/// Halaman Panduan Kurikulum:
/// Menampilkan struktur kurikulum, ringkasan SKS, status kelulusan mata kuliah,
/// serta filter interaktif berdasarkan semester dan status (Sudah/Sedang/Belum diambil).
class KurikulumScreen extends StatefulWidget {
  const KurikulumScreen({super.key, required this.periode});

  final String periode;

  @override
  State<KurikulumScreen> createState() => _KurikulumScreenState();
}

class _KurikulumScreenState extends State<KurikulumScreen> {
  late Future<dynamic> _future;
  dynamic _cachedData;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = context.read<ApiClient>().get(
            '/api/akademik/krs/kurikulum',
            query: {'periode': widget.periode},
          );
    });
  }

  static Map<String, dynamic> _normalizeKurikulumData(dynamic data) {
    if (data is! Map) return {};
    var m = asMap(data);
    if (m['raw_json'] is Map) {
      m = asMap(m['raw_json']);
    }
    if (m['data'] is Map) {
      final inner = asMap(m['data']);
      m.addAll(inner);
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    final bg = context.bg;

    final previewMap = _normalizeKurikulumData(_cachedData);
    final info = asMap(previewMap['info']);
    final kurikulumName = pickString(
      info,
      ['kurikulum', 'nama_kurikulum', 'nama'],
      'Kurikulum Akademik',
    );
    final prodi = pickString(info, ['prodi', 'program_studi', 'jurusan'], '');

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          // ──── HEADER KUNING DENGAN LEKUKAN BERSAMBUNG ────
          _buildCurvedHeader(context, kurikulumName, prodi),

          // ──── BODY KONTEN KURIKULUM ────
          Expanded(
            child: FutureBuilder<dynamic>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting &&
                    _cachedData == null) {
                  return const Center(
                    child: LoadingView(label: 'Memuat struktur kurikulum...'),
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
                if (_cachedData == null) {
                  return const EmptyView(message: 'Data kurikulum tidak ditemukan');
                }

                final normalized = _normalizeKurikulumData(_cachedData);
                return RefreshIndicator(
                  color: AppColors.upiYellowDeep,
                  backgroundColor:
                      context.card,
                  onRefresh: () async {
                    _reload();
                    await _future;
                  },
                  child: KurikulumDetailView(data: normalized),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurvedHeader(
    BuildContext context,
    String kurikulumName,
    String prodi,
  ) {
    final canPop = Navigator.of(context).canPop();

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
                        const Text(
                          'Panduan Kurikulum',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ],
                    ),
                    IosBounceTap(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _reload();
                        appToast(context, 'Memuat ulang kurikulum...');
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
                const SizedBox(height: 14),

                Text(
                  kurikulumName,
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
                    if (prodi.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Prodi $prodi',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        widget.periode,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// View interaktif untuk menampilkan detail kurikulum dengan pencarian,
/// filter semester, filter status, dan pengelompokan semester.
class KurikulumDetailView extends StatefulWidget {
  const KurikulumDetailView({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  State<KurikulumDetailView> createState() => _KurikulumDetailViewState();
}

class _KurikulumDetailViewState extends State<KurikulumDetailView> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  int _selectedSemester = 0; // 0 = Semua Semester
  String _selectedStatus = 'all'; // all, taken, current, pending

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  int _parseNum(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    final match = RegExp(r'\d+').firstMatch(v.toString());
    if (match != null) {
      return int.tryParse(match.group(0)!) ?? fallback;
    }
    return fallback;
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
        color: context.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.border,
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
    final info = asMap(widget.data['info']);
    final stats = asMap(widget.data['stats']);
    final summary = asMap(widget.data['summary']);

    final kurikulumName = pickString(
      info,
      ['kurikulum', 'nama_kurikulum', 'nama'],
      'Kurikulum Akademik',
    );
    final prodi = pickString(info, ['prodi', 'program_studi', 'jurusan'], '');
    final rekomendasiSem = pickString(
      info,
      ['rekomendasi_semester', 'rekomendasi', 'semester'],
      '',
    );

    // Ambil list mata kuliah
    List<dynamic> rawMkList = [];
    if (widget.data['mata_kuliah'] is List) {
      rawMkList = widget.data['mata_kuliah'] as List;
    } else if (widget.data['items'] is List) {
      rawMkList = widget.data['items'] as List;
    } else if (widget.data['courses'] is List) {
      rawMkList = widget.data['courses'] as List;
    }

    final allCourses = rawMkList.map((e) => asMap(e)).toList();

    // Hitung statistik aktual
    int takenCount = 0;
    int currentCount = 0;
    int pendingCount = 0;
    int totalSksCalc = 0;

    final availableSemesters = <int>{};

    for (final mk in allCourses) {
      final sks = _parseNum(mk['sks_num'] ?? mk['sks'], 0);
      totalSksCalc += sks;

      final sem = _parseNum(mk['semester_num'] ?? mk['semester'], 0);
      if (sem > 0) availableSemesters.add(sem);

      final statusKind = _resolveStatusKind(mk);
      if (statusKind == 'taken') {
        takenCount++;
      } else if (statusKind == 'current') {
        currentCount++;
      } else {
        pendingCount++;
      }
    }

    final sortedSemesters = availableSemesters.toList()..sort();

    final totalMk = stats['total_mk'] is num
        ? (stats['total_mk'] as num).toInt()
        : allCourses.length;

    final sudahDiambil = stats['sudah_diambil'] is num
        ? (stats['sudah_diambil'] as num).toInt()
        : takenCount;

    final belumDiambil = stats['belum_diambil'] is num
        ? (stats['belum_diambil'] as num).toInt()
        : pendingCount;

    final totalSksText = pickString(
      summary,
      ['total_sks', 'sks'],
      totalSksCalc > 0 ? '$totalSksCalc SKS' : '-',
    );

    // Filter data
    final filteredCourses = allCourses.where((mk) {
      final name = pickString(mk, ['nama', 'name', 'nama_mk'], '').toLowerCase();
      final code = pickString(mk, ['kode', 'code', 'kode_mk'], '').toLowerCase();
      final q = _searchQuery.toLowerCase().trim();

      if (q.isNotEmpty && !name.contains(q) && !code.contains(q)) {
        return false;
      }

      if (_selectedSemester > 0) {
        final sem = _parseNum(mk['semester_num'] ?? mk['semester'], 0);
        if (sem != _selectedSemester) return false;
      }

      final kind = _resolveStatusKind(mk);
      if (_selectedStatus != 'all' && kind != _selectedStatus) {
        return false;
      }

      return true;
    }).toList();

    // Persentase kelulusan
    final progress = totalMk > 0 ? (sudahDiambil / totalMk).clamp(0.0, 1.0) : 0.0;
    final percentInt = (progress * 100).round();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 104),
      children: [
        // ============================================================
        // 1. HERO HEADER CARD: Kurikulum, Rekomendasi, & Progress
        // ============================================================
        _buildHeroCard(
          context,
          kurikulumName: kurikulumName,
          prodi: prodi,
          rekomendasiSem: rekomendasiSem,
          progress: progress,
          percentInt: percentInt,
          sudahDiambil: sudahDiambil,
          totalMk: totalMk,
        ),

        const SizedBox(height: 14),

        // ============================================================
        // 2. STATS ROW: Total SKS, Total MK, Sudah, Belum
        // ============================================================
        _buildStatsGrid(
          context,
          totalSks: totalSksText,
          totalMk: totalMk,
          sudahDiambil: sudahDiambil,
          belumDiambil: belumDiambil,
        ),

        const SizedBox(height: 18),

        // ============================================================
        // 3. SEARCH BAR NEUMORPHIC
        // ============================================================
        _buildSearchBar(context),

        const SizedBox(height: 12),

        // ============================================================
        // 4. FILTER STATUS CHIPS
        // ============================================================
        _buildStatusFilterRow(
          context,
          allCount: allCourses.length,
          takenCount: takenCount,
          currentCount: currentCount,
          pendingCount: pendingCount,
        ),

        const SizedBox(height: 10),

        // ============================================================
        // 5. FILTER SEMESTER CHIPS
        // ============================================================
        if (sortedSemesters.isNotEmpty) ...[
          _buildSemesterFilterRow(context, sortedSemesters),
          const SizedBox(height: 14),
        ],

        // ============================================================
        // 6. LIST MATA KULIAH
        // ============================================================
        if (filteredCourses.isEmpty) ...[
          const SizedBox(height: 24),
          _buildEmptyState(context),
          const SizedBox(height: 40),
        ] else if (_selectedSemester == 0 && _searchQuery.isEmpty) ...[
          // Tampilkan dikelompokkan per semester
          ..._buildGroupedBySemester(context, filteredCourses, sortedSemesters),
        ] else ...[
          // Tampilkan flat list dengan counter
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10, top: 4),
            child: Text(
              'Menampilkan ${filteredCourses.length} mata kuliah',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: context.textMuted,
              ),
            ),
          ),
          for (final mk in filteredCourses)
            _KurikulumMkCard(
              mk: mk,
              parseNum: _parseNum,
              statusKind: _resolveStatusKind(mk),
              neuCardBuilder: _buildNeuCard,
            ),
        ],

        const SizedBox(height: 32),
      ],
    );
  }

  // Helper resolusi status MK ('taken', 'current', 'pending')
  String _resolveStatusKind(Map<String, dynamic> mk) {
    final statusObj = mk['status'];
    String key = '';
    String label = '';

    if (statusObj is Map) {
      key = pickString(asMap(statusObj), ['key', 'code', 'status'], '').toLowerCase();
      label = pickString(asMap(statusObj), ['label', 'nama', 'title'], '').toLowerCase();
    } else if (statusObj != null) {
      key = statusObj.toString().toLowerCase();
      label = key;
    }

    final riwayat = asMap(mk['riwayat']);
    final nilai = pickString(riwayat, ['nilai', 'grade'], '');
    final bool kosong = riwayat['kosong'] == true;

    if (key == 'taken' || label.contains('sudah') || (!kosong && nilai.isNotEmpty)) {
      return 'taken';
    }
    if (key == 'current' || label.contains('periode ini') || label.contains('sedang')) {
      return 'current';
    }
    return 'pending';
  }

  Widget _buildHeroCard(
    BuildContext context, {
    required String kurikulumName,
    required String prodi,
    required String rekomendasiSem,
    required double progress,
    required int percentInt,
    required int sudahDiambil,
    required int totalMk,
  }) {
    return _buildNeuCard(
      context: context,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFF4D9), Color(0xFFFFE6A8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.upiYellowDeep.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_stories_rounded,
                  color: AppColors.upiYellowDeep,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kurikulumName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (prodi.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: context.softFill,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Prodi $prodi',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: context.textMuted,
                              ),
                            ),
                          ),
                        if (rekomendasiSem.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.upiYellowDeep.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: AppColors.upiYellowDeep.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.flag_rounded,
                                  size: 11,
                                  color: AppColors.upiYellowDeep,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Rekomendasi Sem $rekomendasiSem',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.upiYellowDeep,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          Divider(height: 1, color: context.border.withValues(alpha: 0.5)),
          const SizedBox(height: 14),

          // Progres Kelulusan
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.trending_up_rounded,
                    size: 16,
                    color: AppColors.green,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Progres Kelulusan MK',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimary,
                    ),
                  ),
                ],
              ),
              Text(
                '$percentInt% ($sudahDiambil/$totalMk MK)',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: context.softFill,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.green),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(
    BuildContext context, {
    required String totalSks,
    required int totalMk,
    required int sudahDiambil,
    required int belumDiambil,
  }) {
    return Row(
      children: [
        Expanded(
          child: _statTile(
            context,
            label: 'Total SKS',
            value: totalSks,
            icon: Icons.stars_rounded,
            color: AppColors.upiYellowDeep,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statTile(
            context,
            label: 'Total MK',
            value: '$totalMk MK',
            icon: Icons.layers_rounded,
            color: AppColors.blue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statTile(
            context,
            label: 'Diambil',
            value: '$sudahDiambil MK',
            icon: Icons.check_circle_rounded,
            color: AppColors.green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statTile(
            context,
            label: 'Sisa MK',
            value: '$belumDiambil MK',
            icon: Icons.pending_actions_rounded,
            color: AppColors.amber,
          ),
        ),
      ],
    );
  }

  Widget _statTile(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: context.softFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: context.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final isDark = context.isDark;
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.border,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.30)
                : const Color(0xFF94A3B8).withValues(alpha: 0.10),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (val) {
          setState(() {
            _searchQuery = val;
          });
        },
        style: TextStyle(fontSize: 13.5, color: context.textPrimary),
        decoration: InputDecoration(
          hintText: 'Cari mata kuliah atau kode...',
          hintStyle: TextStyle(fontSize: 13, color: context.textMuted),
          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.upiYellowDeep),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: InputBorder.none,
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildStatusFilterRow(
    BuildContext context, {
    required int allCount,
    required int takenCount,
    required int currentCount,
    required int pendingCount,
  }) {
    final filters = [
      {'key': 'all', 'label': 'Semua', 'count': allCount, 'color': AppColors.upiYellowDeep},
      {'key': 'taken', 'label': 'Sudah Diambil', 'count': takenCount, 'color': AppColors.green},
      if (currentCount > 0)
        {'key': 'current', 'label': 'Periode Ini', 'count': currentCount, 'color': AppColors.amber},
      {'key': 'pending', 'label': 'Belum Diambil', 'count': pendingCount, 'color': AppColors.grey},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: filters.map((f) {
          final key = f['key'] as String;
          final label = f['label'] as String;
          final count = f['count'] as int;
          final color = f['color'] as Color;
          final isSelected = _selectedStatus == key;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IosBounceTap(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedStatus = key;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color
                      : color.withValues(alpha: context.isDark ? 0.12 : 0.08),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isSelected ? color : color.withValues(alpha: 0.25),
                    width: 1.2,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? Colors.white : color,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.28)
                            : color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? Colors.white : color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSemesterFilterRow(BuildContext context, List<int> semesters) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _semesterChip(
            context,
            label: 'Semua Sem',
            semNum: 0,
            isSelected: _selectedSemester == 0,
          ),
          for (final sem in semesters)
            _semesterChip(
              context,
              label: 'Sem $sem',
              semNum: sem,
              isSelected: _selectedSemester == sem,
            ),
        ],
      ),
    );
  }

  Widget _semesterChip(
    BuildContext context, {
    required String label,
    required int semNum,
    required bool isSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: IosBounceTap(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _selectedSemester = semNum;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5.5),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.upiYellowDeep
                : (context.isDark ? const Color(0xFF222226) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.upiYellowDeep : context.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? Colors.white : context.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildGroupedBySemester(
    BuildContext context,
    List<Map<String, dynamic>> courses,
    List<int> sortedSemesters,
  ) {
    final widgets = <Widget>[];

    for (final sem in sortedSemesters) {
      final semCourses = courses.where((mk) {
        final mkSem = _parseNum(mk['semester_num'] ?? mk['semester'], 0);
        return mkSem == sem;
      }).toList();

      if (semCourses.isEmpty) continue;

      int semSks = 0;
      for (final mk in semCourses) {
        semSks += _parseNum(mk['sks_num'] ?? mk['sks'], 0);
      }

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 8),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: AppColors.upiYellowDeep,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Semester $sem',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: context.softFill,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.border),
                ),
                child: Text(
                  '${semCourses.length} MK • $semSks SKS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      for (final mk in semCourses) {
        widgets.add(
          _KurikulumMkCard(
            mk: mk,
            parseNum: _parseNum,
            statusKind: _resolveStatusKind(mk),
            neuCardBuilder: _buildNeuCard,
          ),
        );
      }
    }

    return widgets;
  }

  Widget _buildEmptyState(BuildContext context) {
    return _buildNeuCard(
      context: context,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.amber.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_off_rounded,
              size: 28,
              color: AppColors.upiYellowDeep,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Mata Kuliah Tidak Ditemukan',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tidak ada mata kuliah yang cocok dengan kata kunci atau filter yang Anda pilih.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: context.textMuted),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () {
              _searchCtrl.clear();
              setState(() {
                _searchQuery = '';
                _selectedSemester = 0;
                _selectedStatus = 'all';
              });
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.upiYellowDeep,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Reset Filter',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

/// Kartu Mata Kuliah Kurikulum yang rapi, bergradasi status,
/// dan menampilkan nilai kelulusan secara jelas.
class _KurikulumMkCard extends StatelessWidget {
  const _KurikulumMkCard({
    required this.mk,
    required this.parseNum,
    required this.statusKind,
    required this.neuCardBuilder,
  });

  final Map<String, dynamic> mk;
  final int Function(dynamic v, [int fallback]) parseNum;
  final String statusKind;
  final Widget Function({
    required BuildContext context,
    required Widget child,
    EdgeInsetsGeometry padding,
    VoidCallback? onTap,
  }) neuCardBuilder;

  @override
  Widget build(BuildContext context) {
    final kode = pickString(mk, ['kode', 'code', 'kode_mk'], '-');
    final nama = pickString(mk, ['nama', 'name', 'nama_mk'], 'Mata Kuliah');
    final jenis = pickString(mk, ['jenis', 'jenis_kind', 'sifat'], 'Wajib');
    final sksNum = parseNum(mk['sks_num'] ?? mk['sks'], 0);
    final semNum = parseNum(mk['semester_num'] ?? mk['semester'], 0);

    final isWajib = jenis.toLowerCase().contains('wajib');

    final riwayat = asMap(mk['riwayat']);
    final nilai = pickString(riwayat, ['nilai', 'grade'], '');
    final periodeRiwayat = pickString(riwayat, ['periode', 'smt', 'tahun'], '');

    // Pewarnaan status
    final Color statusColor;
    final String statusLabelText;
    final IconData statusIcon;

    if (statusKind == 'taken') {
      statusColor = AppColors.green;
      statusLabelText = 'Sudah Diambil';
      statusIcon = Icons.check_circle_rounded;
    } else if (statusKind == 'current') {
      statusColor = AppColors.upiYellowDeep;
      statusLabelText = 'Sedang Ditempuh (Periode Ini)';
      statusIcon = Icons.schedule_rounded;
    } else {
      statusColor = AppColors.grey;
      statusLabelText = 'Belum Diambil';
      statusIcon = Icons.radio_button_unchecked_rounded;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: neuCardBuilder(
        context: context,
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Baris Top: Semester Pill, Kode, SKS, Jenis
            Row(
              children: [
                if (semNum > 0)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: context.softFill,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Sem $semNum',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: context.textMuted,
                      ),
                    ),
                  ),

                // Kode MK (klik untuk salin)
                IosBounceTap(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: kode));
                    appToast(context, 'Kode $kode disalin.');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: AppColors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          kode,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.upiYellowDeep,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.copy_rounded,
                          size: 10,
                          color: AppColors.upiYellowDeep,
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // SKS Pill
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: AppColors.upiYellowDeep.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$sksNum SKS',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.upiYellowDeep,
                    ),
                  ),
                ),

                // Jenis (Wajib / Pilihan)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: isWajib
                        ? AppColors.blue.withValues(alpha: 0.1)
                        : Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    jenis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isWajib ? AppColors.blue : Colors.purple,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Nama Mata Kuliah
            Text(
              nama,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: context.textPrimary,
                height: 1.25,
              ),
            ),

            const SizedBox(height: 10),

            // Baris Status & Riwayat Nilai
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: context.isDark ? 0.1 : 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: statusColor.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Icon(statusIcon, size: 16, color: statusColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      statusLabelText,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),

                  // Jika sudah diambil dan ada nilai
                  if (statusKind == 'taken' && nilai.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.green,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        nilai,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (periodeRiwayat.isNotEmpty) const SizedBox(width: 6),
                  ],

                  // Periode Riwayat (misal "Periode 20251")
                  if (periodeRiwayat.isNotEmpty)
                    Text(
                      periodeRiwayat.replaceFirst('Periode ', 'P.'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.textMuted,
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
