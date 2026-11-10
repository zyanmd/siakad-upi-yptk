import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'absen_qr_screen.dart';
import '../services/api_client.dart';
import '../state/auth_provider.dart';
import '../state/periode_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/smart.dart';
import '../widgets/common.dart';
import '../widgets/periode_dropdown.dart';
import '../widgets/smart_detail_page.dart';

// ── UPI YPTK Golden Yellow Gradient ──
const _yellowHeaderGradient = [
  Color(0xFFE5A620), // Bright Academic Gold
  Color(0xFFD48B08), // UPI Yellow
  Color(0xFFB87500), // Deep Academic Gold
];

/// Rekap presensi kuliah per mata kuliah untuk periode berjalan
/// dengan pemilih periode dropdown dinamis, metrik kehadiran,
/// filter progres, pencarian real-time, dan rincian 16 pertemuan.
class PresensiScreen extends StatefulWidget {
  const PresensiScreen({super.key});

  @override
  State<PresensiScreen> createState() => _PresensiScreenState();
}

class _PresensiScreenState extends State<PresensiScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  PeriodeProvider? _pp;
  String? _selectedPeriode;
  List<PeriodeOption> _periodeOpts = [];
  String _searchQuery = '';
  String _selectedProgres = 'all'; // all, berjalan, belum dimulai, lengkap
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
    _searchCtrl.dispose();
    _pp?.removeListener(_onPeriode);
    super.dispose();
  }

  Future<Map<String, dynamic>> _load() async {
    final api = context.read<ApiClient>();
    final p = _selectedPeriode ??
        context.read<PeriodeProvider>().value ??
        fallbackPeriode();

    final resp = await api.get('/api/akademik/presensi', query: {'periode': p});
    final data = resp is Map ? (resp['data'] ?? resp) : resp;
    final mapData = asMap(data);

    // Ekstrak opsi periode_tersedia jika dikembalikan oleh server
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
    });
    context.read<PeriodeProvider>().set(newPeriode);
    _reload();
  }

  void _openDetail(Map<String, dynamic> item, String periode) {
    final token = detailTokenOf(item);
    if (token == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SmartDetailPage(
        title: 'Detail Presensi',
        initialData: item,
        load: () => context.read<ApiClient>().get(
              '/api/akademik/presensi/detail/$token',
              query: {'periode': periode},
            ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = context.isDark;
    final bg = context.bg;

    final metrics = asMap(_cachedData?['metrics']);
    final rataKehadiran = pickString(metrics, ['rata_kehadiran'], '');

    return Scaffold(
      backgroundColor: bg,
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
                rataKehadiran: rataKehadiran,
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
                    child: LoadingView(label: 'Memuat rekap presensi...'),
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
                  return const EmptyView(message: 'Data presensi tidak ditemukan');
                }
                return RefreshIndicator(
                  color: AppColors.upiYellowDeep,
                  backgroundColor:
                      context.card,
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
    required String rataKehadiran,
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
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, kCurvedHeaderBottomPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Back + Title + Action button (Refresh)
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
                          'Presensi Kuliah',
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
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AbsenQrScreen(),
                              ),
                            );
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
                            child: const Icon(Icons.qr_code_scanner_rounded,
                                size: 20, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IosBounceTap(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _reload();
                            appToast(context, 'Memuat ulang data presensi...');
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
                const SizedBox(height: 16),

                // Profile Avatar + Name & NIM + Rata Kehadiran Badge
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
                                  color: Colors.white.withValues(alpha: 0.22),
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
                              if (rataKehadiran.isNotEmpty && rataKehadiran != '0%')
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    rataKehadiran,
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
      ),
    );
  }

  // ────────────────────────────────────────────────── FLOATING PERIODE PILL
  Widget _buildFloatingPeriodePill(BuildContext context, bool isDark) {
    final activeValue = _periodeOpts.any((o) => o.value == _selectedPeriode)
        ? _selectedPeriode
        : (_periodeOpts.isNotEmpty ? _periodeOpts.first.value : _selectedPeriode);

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

  Widget _body(BuildContext context, Map<String, dynamic> data) {
    List<Map<String, dynamic>> allItems = [];
    if (data['mata_kuliah'] is List) {
      allItems = (data['mata_kuliah'] as List).whereType<Map>().map((e) => asMap(e)).toList();
    } else {
      allItems = findMapList(data);
    }

    final periode = _selectedPeriode ??
        context.read<PeriodeProvider>().value ??
        '';

    // Hitung counter status progres
    int berjalanCount = 0;
    int belumDimulaiCount = 0;
    int lengkapCount = 0;

    for (final item in allItems) {
      final status = pickString(item, ['status_label', 'status'], '').toLowerCase();
      if (status.contains('berjalan')) {
        berjalanCount++;
      } else if (status.contains('belum')) {
        belumDimulaiCount++;
      } else if (status.contains('lengkap') || status.contains('selesai')) {
        lengkapCount++;
      }
    }

    // Filter berdasarkan pencarian & filter progres
    final filtered = allItems.where((item) {
      final name = pickString(item, ['nama', 'matkul', 'nama_mk', 'mata_kuliah'], '').toLowerCase();
      final code = pickString(item, ['kode', 'kode_mk'], '').toLowerCase();
      final q = _searchQuery.toLowerCase().trim();

      if (q.isNotEmpty && !name.contains(q) && !code.contains(q)) {
        return false;
      }

      final status = pickString(item, ['status_label', 'status'], '').toLowerCase();
      if (_selectedProgres == 'berjalan' && !status.contains('berjalan')) {
        return false;
      }
      if (_selectedProgres == 'belum dimulai' && !status.contains('belum')) {
        return false;
      }
      if (_selectedProgres == 'lengkap' && !(status.contains('lengkap') || status.contains('selesai'))) {
        return false;
      }

      return true;
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
      children: [
        // 1. OVERVIEW CARD: METRIK & RINGKASAN KEHADIRAN
        _buildOverviewCard(context, data),

        const SizedBox(height: 16),

        // 2. SEARCH BAR NEUMORPHIC
        _buildSearchBar(context),

        const SizedBox(height: 12),

        // 3. FILTER PROGRES CHIPS
        _buildFilterChips(
          context,
          allCount: allItems.length,
          berjalanCount: berjalanCount,
          belumDimulaiCount: belumDimulaiCount,
          lengkapCount: lengkapCount,
        ),

        const SizedBox(height: 14),

        // 4. LIST MATA KULIAH PRESENSI
        if (filtered.isEmpty) ...[
          const SizedBox(height: 30),
          _buildEmptyState(context),
          const SizedBox(height: 40),
        ] else ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              'Menampilkan ${filtered.length} mata kuliah',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: context.textMuted,
              ),
            ),
          ),
          for (final item in filtered) ...[
            _PresensiCard(
              item: item,
              neuCardBuilder: _buildNeuCard,
              onTap: detailTokenOf(item) != null
                  ? () => _openDetail(item, periode)
                  : null,
            ),
            const SizedBox(height: 12),
          ],
        ],

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildOverviewCard(BuildContext context, Map<String, dynamic> data) {
    final metrics = asMap(data['metrics']);
    final rataKehadiran = pickString(metrics, ['rata_kehadiran'], '0%');
    final rataKehadiranDesc = pickString(metrics, ['rata_kehadiran_desc'], 'Hadir termasuk terlambat');
    final totalMk = pickString(metrics, ['mata_kuliah'], '8 Saat Ini');
    final pertemuanBerjalan = pickString(metrics, ['pertemuan_berjalan'], '0 Pertemuan');
    final totalAlpa = pickString(metrics, ['alpa'], '0 Alpa');

    final numVal = double.tryParse(rataKehadiran.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
    final Color badgeColor = numVal >= 80
        ? AppColors.green
        : (numVal >= 65 ? AppColors.amber : AppColors.upiYellowDeep);

    return _buildNeuCard(
      context: context,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFF4D9), Color(0xFFFFE6A8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.upiYellowDeep.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.pie_chart_rounded,
                  size: 22,
                  color: AppColors.upiYellowDeep,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Statistik Kehadiran',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      rataKehadiranDesc.isNotEmpty ? rataKehadiranDesc : 'Rekap kumulatif semester ini',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              // Badge Rata Kehadiran
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded, size: 14, color: badgeColor),
                    const SizedBox(width: 5),
                    Text(
                      rataKehadiran,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: badgeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          Divider(height: 1, color: context.border.withValues(alpha: 0.5)),
          const SizedBox(height: 14),

          // Metrik 4 Kolom: Rata Kehadiran, Pertemuan Berjalan, Mata Kuliah, Alpa
          Row(
            children: [
              Expanded(
                child: _statItem(
                  context,
                  label: 'Kehadiran',
                  value: rataKehadiran,
                  icon: Icons.check_circle_outline_rounded,
                  color: AppColors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statItem(
                  context,
                  label: 'Pertemuan',
                  value: pertemuanBerjalan.replaceAll(' Pertemuan', ''),
                  icon: Icons.timelapse_rounded,
                  color: AppColors.upiYellowDeep,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statItem(
                  context,
                  label: 'Mata Kuliah',
                  value: totalMk.replaceAll(' Saat Ini', ' MK'),
                  icon: Icons.auto_stories_rounded,
                  color: AppColors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statItem(
                  context,
                  label: 'Total Alpa',
                  value: totalAlpa.replaceAll(' Alpa', ''),
                  icon: Icons.cancel_outlined,
                  color: AppColors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(
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
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: context.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
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

  Widget _buildFilterChips(
    BuildContext context, {
    required int allCount,
    required int berjalanCount,
    required int belumDimulaiCount,
    required int lengkapCount,
  }) {
    final filters = [
      {'key': 'all', 'label': 'Semua', 'count': allCount, 'color': AppColors.upiYellowDeep},
      {'key': 'belum dimulai', 'label': 'Belum Dimulai', 'count': belumDimulaiCount, 'color': AppColors.grey},
      if (berjalanCount > 0)
        {'key': 'berjalan', 'label': 'Berjalan', 'count': berjalanCount, 'color': AppColors.blue},
      if (lengkapCount > 0)
        {'key': 'lengkap', 'label': 'Lengkap', 'count': lengkapCount, 'color': AppColors.green},
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
          final isSelected = _selectedProgres == key;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IosBounceTap(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedProgres = key;
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

  Widget _buildEmptyState(BuildContext context) {
    return _buildNeuCard(
      context: context,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.amber.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.fact_check_outlined,
              size: 28,
              color: AppColors.upiYellowDeep,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Presensi Tidak Ditemukan',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tidak ada presensi yang cocok dengan filter yang dipilih.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: context.textMuted),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () {
              _searchCtrl.clear();
              setState(() {
                _searchQuery = '';
                _selectedProgres = 'all';
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

/// Kartu Presensi Mata Kuliah yang rapi, informatif, dan interaktif
class _PresensiCard extends StatelessWidget {
  const _PresensiCard({
    required this.item,
    required this.neuCardBuilder,
    this.onTap,
  });

  final Map<String, dynamic> item;
  final Widget Function({
    required BuildContext context,
    required Widget child,
    EdgeInsetsGeometry padding,
    VoidCallback? onTap,
  }) neuCardBuilder;
  final VoidCallback? onTap;

  Color _percentColor(double v) {
    if (v >= 80) return AppColors.green;
    if (v >= 65) return AppColors.amber;
    return AppColors.red;
  }

  @override
  Widget build(BuildContext context) {
    final title = pickString(
      item,
      ['nama', 'matkul', 'nama_mk', 'mata_kuliah'],
      'Mata Kuliah',
    );
    final kode = pickString(item, ['kode', 'kode_mk', 'kd_mk'], '');
    final kelas = pickString(item, ['kelas', 'nama_kelas'], '');
    final dosen = pickString(item, ['dosen', 'nama_dosen'], '');
    final info = pickString(item, ['info'], '');
    final hari = pickString(item, ['hari'], '');
    final jam = pickString(item, ['jam'], '');
    final ruang = pickString(item, ['ruang'], '');
    final progress = pickString(item, ['progress'], '0 / 16');
    final statusLabel = pickString(item, ['status_label'], 'Belum Dimulai');

    final persenRaw = pickString(item, ['kehadiran', 'persen'], '0%');
    final persen = double.tryParse(persenRaw.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;

    // Resolusi warna status progres
    final stLower = statusLabel.toLowerCase();
    final Color statusColor;
    if (stLower.contains('lengkap') || stLower.contains('selesai')) {
      statusColor = AppColors.green;
    } else if (stLower.contains('berjalan')) {
      statusColor = AppColors.blue;
    } else {
      statusColor = AppColors.grey;
    }

    return neuCardBuilder(
      context: context,
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ikon Kuliah Neumorphic
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFF7E6), Color(0xFFFFE8B2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.upiYellowDeep.withValues(alpha: 0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.fact_check_outlined,
                  size: 22,
                  color: AppColors.upiYellowDeep,
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
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (kode.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppColors.upiYellowDeep.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              kode,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.upiYellowDeep,
                              ),
                            ),
                          ),
                        if (kelas.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: context.softFill,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Kelas $kelas',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: context.textMuted,
                              ),
                            ),
                          ),
                        if (info.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: context.softFill,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              info,
                              style: TextStyle(
                                fontSize: 11,
                                color: context.textMuted,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Kehadiran Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _percentColor(persen).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _percentColor(persen).withValues(alpha: 0.3)),
                ),
                child: Text(
                  persenRaw.contains('%') ? persenRaw : '$persenRaw%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _percentColor(persen),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Baris Progress Pertemuan
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pertemuan: $progress',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: context.textMuted,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withValues(alpha: 0.25)),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (persen / 100).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: context.softFill,
              valueColor: AlwaysStoppedAnimation(_percentColor(persen)),
            ),
          ),

          const SizedBox(height: 12),
          Divider(height: 1, color: context.border.withValues(alpha: 0.5)),
          const SizedBox(height: 10),

          // Baris Jadwal & Dosen & Arrow
          Row(
            children: [
              if (hari.isNotEmpty || jam.isNotEmpty || ruang.isNotEmpty) ...[
                Icon(Icons.schedule_rounded, size: 13, color: context.textMuted),
                const SizedBox(width: 4),
                Text(
                  [hari, jam, if (ruang.isNotEmpty) 'R. $ruang'].where((s) => s.isNotEmpty).join(' • '),
                  style: TextStyle(fontSize: 11, color: context.textMuted),
                ),
                const SizedBox(width: 10),
              ],
              if (dosen.isNotEmpty) ...[
                Icon(Icons.person_outline_rounded, size: 13, color: context.textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    dosen,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: context.textMuted),
                  ),
                ),
              ] else
                const Spacer(),

              if (onTap != null)
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '16 Sesi',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.upiYellowDeep,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AppColors.upiYellowDeep,
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
