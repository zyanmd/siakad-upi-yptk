import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../state/auth_provider.dart';
import '../state/periode_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/smart.dart';
import '../widgets/common.dart';
import '../widgets/periode_dropdown.dart';
import '../widgets/smart_detail_page.dart';
import 'jadwal_cetak_screen.dart';

// ── UPI YPTK Golden Yellow Gradient ──
const _yellowHeaderGradient = [
  Color(0xFFE5A620), // Bright Academic Gold
  Color(0xFFD48B08), // UPI Yellow
  Color(0xFFB87500), // Deep Academic Gold
];

/// Jadwal kuliah per periode, dikelompokkan berdasarkan hari
/// dengan header kuning lengkung khas UPI YPTK, floating periode pill,
/// metrik perkuliahan, dan tautan grup kelas.
class JadwalScreen extends StatefulWidget {
  const JadwalScreen({super.key});

  @override
  State<JadwalScreen> createState() => _JadwalScreenState();
}

class _JadwalScreenState extends State<JadwalScreen> {
  PeriodeProvider? _pp;
  String? _selectedPeriode;
  List<PeriodeOption> _periodeOpts = [];
  Future<Map<String, dynamic>>? _future;
  Map<String, dynamic>? _cachedData;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _pp = context.read<PeriodeProvider>();
      _pp!.addListener(_onPeriode);
      _selectedPeriode = _pp!.value;
      if (_pp!.items.isNotEmpty) {
        _periodeOpts = List.from(_pp!.items);
      }
      _reload();
      _pp!.ensureLoaded().then((_) {
        if (mounted) {
          if (_periodeOpts.isEmpty && _pp!.items.isNotEmpty) {
            _periodeOpts = List.from(_pp!.items);
          }
          _reload();
        }
      });
    });
  }

  void _onPeriode() {
    if (mounted && _pp != null && _pp!.value != _selectedPeriode) {
      setState(() {
        _selectedPeriode = _pp!.value;
      });
      _reload();
    }
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  @override
  void dispose() {
    _pp?.removeListener(_onPeriode);
    super.dispose();
  }

  Future<Map<String, dynamic>> _load() async {
    final api = context.read<ApiClient>();
    final p = _selectedPeriode ??
        context.read<PeriodeProvider>().value ??
        fallbackPeriode();

    final resp = await api.get('/api/akademik/jadwal', query: {'periode': p});
    final data = resp is Map ? (resp['data'] ?? resp) : resp;
    final mapData = asMap(data);

    // Ekstrak periode_tersedia jika dikembalikan oleh backend
    if (mapData['periode_tersedia'] is List) {
      final list = <PeriodeOption>[];
      for (final e in (mapData['periode_tersedia'] as List)) {
        if (e is Map) {
          final m = asMap(e);
          final k = pickString(m, ['kode', 'code', 'value'], '');
          final l = pickString(m, ['label', 'nama', 'title'], k);
          if (k.isNotEmpty) {
            list.add(PeriodeOption(value: k, label: l));
          }
        }
      }
      if (list.isNotEmpty) {
        _periodeOpts = list;
      }
    }

    if (mounted) {
      setState(() {
        _cachedData = mapData;
      });
    }

    return mapData;
  }

  void _onSelectPeriode(String? newPeriode) {
    if (newPeriode == null || newPeriode == _selectedPeriode) return;
    setState(() {
      _selectedPeriode = newPeriode;
      _cachedData = null;
    });
    context.read<PeriodeProvider>().set(newPeriode);
    _reload();
  }

  void _cetak() {
    final p = _selectedPeriode ??
        context.read<PeriodeProvider>().value ??
        fallbackPeriode();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => JadwalCetakScreen(periode: p),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = context.isDark;

    final metrics = _cachedData != null
        ? asMap(_cachedData!['metrics'])
        : <String, dynamic>{};
    final totalSks = pickString(metrics, ['total_sks', 'sks'], '')
        .replaceAll(' terjadwal', '');

    return Scaffold(
      backgroundColor: context.bg,
      body: Column(
        children: [
          // ──── HEADER KUNING DENGAN LEKUKAN BERSAMBUNG & FLOATING PERIODE PILL ────
          Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              _buildCurvedYellowHeader(
                nama: auth.nama,
                nim: auth.nim,
                totalSks: totalSks,
              ),
              Positioned(
                bottom: -18,
                left: 0,
                right: 0,
                child: _buildFloatingPeriodePill(context, isDark),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // ──── BODY KONTEN ────
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting &&
                    _cachedData == null) {
                  return const Center(
                    child: LoadingView(label: 'Memuat jadwal perkuliahan...'),
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
                  return const EmptyView(
                    icon: Icons.event_busy_rounded,
                    message: 'Data jadwal belum tersedia.',
                  );
                }
                return RefreshIndicator(
                  color: AppColors.upiYellowDeep,
                  backgroundColor: context.card,
                  onRefresh: () async {
                    _reload();
                    await _future;
                  },
                  child: _body(context, _cachedData!),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────── HEADER KUNING DENGAN LEKUKAN BERSAMBUNG
  Widget _buildCurvedYellowHeader({
    required String nama,
    required String nim,
    required String totalSks,
  }) {
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
        child: Stack(
          children: [
            const Positioned.fill(child: GoldenHeaderBackdrop()),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    22, 12, 22, kCurvedHeaderBottomPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Row: Back + Title + Action Buttons (Cetak, Refresh)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (canPop) ...[
                              IconButton(
                                onPressed: () =>
                                    Navigator.of(context).maybePop(),
                                icon: const Icon(Icons.arrow_back_rounded,
                                    color: Colors.white, size: 24),
                                tooltip: 'Kembali',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 8),
                            ],
                            const Text(
                              'Jadwal Kuliah',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IosBounceTap(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                _cetak();
                              },
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.22),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.10),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.print_rounded,
                                    size: 20, color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IosBounceTap(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                _reload();
                                appToast(context,
                                    'Memuat ulang jadwal perkuliahan...');
                              },
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.22),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.10),
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
                    const SizedBox(height: 16),

                    // Profile Avatar + Name & NIM + SKS Badge
                    Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.18),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.85),
                              width: 1.8,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              initialsOf(nama),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nama.isNotEmpty ? nama : 'Mahasiswa UPI YPTK',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    nim.isNotEmpty ? 'NIM $nim' : '-',
                                    style: const TextStyle(
                                      color: Color(0xE6FFFFFF),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.22),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'UPI YPTK',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                  if (totalSks.isNotEmpty && totalSks != '-')
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: Colors.white
                                            .withValues(alpha: 0.25),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        totalSks,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────── FLOATING PERIODE PILL
  Widget _buildFloatingPeriodePill(BuildContext context, bool isDark) {
    final activeValue = _periodeOpts.any((o) => o.value == _selectedPeriode)
        ? _selectedPeriode
        : (_periodeOpts.isNotEmpty
            ? _periodeOpts.first.value
            : _selectedPeriode);

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.40)
                  : Colors.black.withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: _periodeOpts.isNotEmpty
            ? PillDropdown(
                value: activeValue,
                hint: 'Pilih Periode',
                items: [
                  for (final o in _periodeOpts)
                    DropdownMenuItem<String>(
                      value: o.value,
                      child: Text(o.label),
                    ),
                ],
                onChanged: _onSelectPeriode,
              )
            : const PeriodeSelector(),
      ),
    );
  }

  Widget _body(BuildContext context, Map<String, dynamic> data) {
    // 1. Deteksi struktur jadwal
    Map<String, dynamic> scheduleMap = {};
    if (data['jadwal'] is Map) {
      scheduleMap = asMap(data['jadwal']);
    } else {
      scheduleMap = data;
    }

    final groups = mapOfLists(scheduleMap);
    final ordered = <String, List<Map<String, dynamic>>>{};

    const dayOrder = [
      'senin',
      'selasa',
      'rabu',
      'kamis',
      'jumat',
      'sabtu',
      'minggu'
    ];

    if (groups.isNotEmpty) {
      final keys = groups.keys.toList();
      keys.sort((a, b) {
        final na = a.toLowerCase().replaceAll("'", '').trim();
        final nb = b.toLowerCase().replaceAll("'", '').trim();
        final ia = dayOrder.indexOf(na);
        final ib = dayOrder.indexOf(nb);
        if (ia == -1 && ib == -1) return 0;
        if (ia == -1) return 1;
        if (ib == -1) return -1;
        return ia.compareTo(ib);
      });
      for (final k in keys) {
        ordered[k] = groups[k]!;
      }
    } else {
      final flat = findMapList(scheduleMap);
      if (flat.isNotEmpty) {
        ordered['Jadwal'] = flat;
      }
    }

    final periode =
        _selectedPeriode ?? context.read<PeriodeProvider>().value ?? '';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      children: [
        // ============================================================
        // 1. OVERVIEW CARD: Metrik Jadwal & Status Pengingat
        // ============================================================
        _buildPeriodeOverviewCard(context, data),

        const SizedBox(height: 16),

        // ============================================================
        // 2. DAFTAR JADWAL PER HARI
        // ============================================================
        if (ordered.isEmpty) ...[
          const SizedBox(height: 40),
          const EmptyView(
            icon: Icons.event_busy_rounded,
            message: 'Belum ada jadwal untuk periode ini.',
          ),
          const SizedBox(height: 40),
        ] else ...[
          for (final entry in ordered.entries) ...[
            _buildDayHeader(context, entry.key, entry.value.length),
            const SizedBox(height: 9),
            for (final item in entry.value) ...[
              _SessionCard(
                item: item,
                onTap: () => _openDetail(item, periode),
              ),
              const SizedBox(height: 9),
            ],
            const SizedBox(height: 12),
          ],
        ],

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildPeriodeOverviewCard(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final metrics = asMap(data['metrics']);
    final hariKuliah = pickString(metrics, ['hari_kuliah', 'hari'], '');
    final mataKuliah = pickString(metrics, ['mata_kuliah', 'mk'], '');
    final totalSks = pickString(metrics, ['total_sks', 'sks'], '');

    final statusKrs = pickString(
      data,
      ['status_krs_label', 'status_krs'],
      'KRS Valid',
    );
    final tglMulai = pickString(data, ['tanggal_mulai'], '');
    final tglSelesai = pickString(data, ['tanggal_selesai'], '');

    final activeLabel = _periodeOpts
        .where((o) => o.value == _selectedPeriode)
        .map((o) => o.label)
        .firstOrNull;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.upiYellowDeep.withValues(alpha: 0.25),
        ),
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
          // Row Periode & Status KRS
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  size: 20,
                  color: AppColors.upiYellowDeep,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Periode Akademik',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      activeLabel ??
                          pickString(
                              data, ['periode'], _selectedPeriode ?? '-'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Status KRS Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 13,
                      color: AppColors.green,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      statusKrs,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Tanggal Rentang Kuliah jika ada
          if (tglMulai.isNotEmpty && tglSelesai.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.date_range_rounded,
                  size: 13,
                  color: context.textMuted,
                ),
                const SizedBox(width: 5),
                Text(
                  '$tglMulai – $tglSelesai',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: context.textMuted,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Metrik Ringkas: Hari Kuliah, SKS, Mata Kuliah
          Row(
            children: [
              Expanded(
                child: _miniMetric(
                  context,
                  label: 'Hari Kuliah',
                  value: hariKuliah.isNotEmpty ? hariKuliah : '-',
                  icon: Icons.view_week_rounded,
                  color: AppColors.upiYellowDeep,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniMetric(
                  context,
                  label: 'Total SKS',
                  value: totalSks.isNotEmpty
                      ? totalSks.replaceAll(' terjadwal', '')
                      : '-',
                  icon: Icons.stars_rounded,
                  color: AppColors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniMetric(
                  context,
                  label: 'Mata Kuliah',
                  value: mataKuliah.isNotEmpty
                      ? mataKuliah.replaceAll(' Valid', ' MK')
                      : '-',
                  icon: Icons.auto_stories_rounded,
                  color: AppColors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Badge Pengingat Kuliah Otomatis (15 Menit Sebelum & Saat Kuliah Dimulai)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.green.withValues(alpha: 0.25),
                width: 0.8,
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.notifications_active_rounded,
                  size: 15,
                  color: AppColors.green,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pengingat Kuliah Aktif (15 Menit Sebelum & Saat Kuliah Dimulai)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.green,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniMetric(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: context.softFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: context.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
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
        ],
      ),
    );
  }

  Widget _buildDayHeader(BuildContext context, String day, int count) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.upiYellowDeep,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.today_rounded, size: 13, color: Colors.white),
              const SizedBox(width: 5),
              Text(
                _prettyDay(day),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$count sesi perkuliahan',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: context.textMuted,
          ),
        ),
      ],
    );
  }

  String _prettyDay(String raw) {
    final s = raw.trim();
    if (s.length <= 2) return s.toUpperCase();
    return s[0].toUpperCase() + s.substring(1);
  }

  void _openDetail(Map<String, dynamic> item, String periode) {
    final token = detailTokenOf(item);
    if (token == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SmartDetailPage(
        title: 'Detail Jadwal',
        initialData: item,
        load: () => context.read<ApiClient>().get(
          '/api/akademik/jadwal/detail/$token',
          query: {'periode': periode},
        ),
      ),
    ));
  }
}

/// Kartu Sesi Mata Kuliah yang rapi dan informatif
class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.item, this.onTap});

  final Map<String, dynamic> item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final title = pickString(
      item,
      ['matkul', 'nama_mk', 'nm_mk', 'mata_kuliah', 'nama', 'mk'],
      'Mata Kuliah',
    );
    final kode = pickString(item, ['kode', 'kode_mk', 'kd_mk'], '');
    final ruang = pickString(item, ['ruang', 'ruangan', 'lokasi'], '');
    final kelas = pickString(item, ['kelas', 'nama_kelas'], '');
    final dosen = pickString(item, ['dosen', 'nama_dosen', 'pengajar'], '');
    final info = pickString(item, ['info'], '');
    final metodeDetail = pickString(item, ['metode_detail', 'metode'], '');
    final waUrl = pickString(item, ['whatsapp_url', 'wa_url', 'link_wa'], '');
    final token = detailTokenOf(item);

    // Format Jam Perkuliahan
    String jamDisplay = '';
    final wm = pickString(item, ['waktu_mulai', 'jam_mulai'], '');
    final ws = pickString(item, ['waktu_selesai', 'jam_selesai'], '');
    if (wm.isNotEmpty && ws.isNotEmpty) {
      final cleanWs = ws.replaceFirst('s.d. ', '').trim();
      jamDisplay = '$wm - $cleanWs WIB';
    } else {
      jamDisplay = pickString(item, ['jam', 'waktu', 'jam_kuliah'], '');
    }

    final isDaring = metodeDetail.toLowerCase().contains('daring') ||
        ruang.toLowerCase().contains('e-learning');

    return SurfaceCard(
      onTap: token != null ? onTap : null,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ikon Kuliah
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDaring
                      ? AppColors.blue.withValues(alpha: 0.1)
                      : AppColors.upiYellowDeep.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isDaring ? Icons.devices_rounded : Icons.menu_book_rounded,
                  size: 22,
                  color: isDaring ? AppColors.blue : AppColors.upiYellowDeep,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (kode.isNotEmpty)
                          Text(
                            kode,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.upiYellowDeep,
                            ),
                          ),
                        if (kode.isNotEmpty && info.isNotEmpty)
                          Text(
                            ' • ',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: context.textMuted,
                            ),
                          ),
                        if (info.isNotEmpty)
                          Text(
                            info,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: context.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (token != null)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: context.textMuted,
                ),
            ],
          ),

          const SizedBox(height: 10),

          // Badges: Jam, Ruang, Kelas, Metode
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (jamDisplay.isNotEmpty)
                _chip(
                  context,
                  Icons.schedule_rounded,
                  jamDisplay,
                  color: AppColors.upiYellowDeep,
                ),
              if (ruang.isNotEmpty)
                _chip(
                  context,
                  Icons.meeting_room_outlined,
                  ruang,
                  color: isDaring ? AppColors.blue : AppColors.grey,
                ),
              if (kelas.isNotEmpty)
                _chip(
                  context,
                  Icons.groups_rounded,
                  'Kelas $kelas',
                  color: AppColors.indigo700,
                ),
              if (metodeDetail.isNotEmpty)
                _chip(
                  context,
                  isDaring ? Icons.wifi_rounded : Icons.apartment_rounded,
                  metodeDetail,
                  color: isDaring ? AppColors.blue : AppColors.amber,
                ),
            ],
          ),

          // Dosen Pengampu & Grup WA
          if (dosen.isNotEmpty ||
              (waUrl.isNotEmpty && waUrl.startsWith('http'))) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                if (dosen.isNotEmpty) ...[
                  Icon(
                    Icons.person_outline_rounded,
                    size: 14,
                    color: context.textMuted,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      dosen,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: context.textMuted,
                      ),
                    ),
                  ),
                ] else
                  const Spacer(),

                // Tombol Grup WhatsApp
                if (waUrl.isNotEmpty && waUrl.startsWith('http'))
                  InkWell(
                    onTap: () => openExternal(context, waUrl),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF25D366).withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_rounded,
                            size: 12.5,
                            color: Color(0xFF25D366),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Grup WA',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF25D366),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context,
    IconData icon,
    String label, {
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
