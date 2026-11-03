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

// ── UPI YPTK Golden Yellow Gradient ──
const _yellowHeaderGradient = [
  Color(0xFFE5A620), // Bright Academic Gold
  Color(0xFFD48B08), // UPI Yellow
  Color(0xFFB87500), // Deep Academic Gold
];

/// Halaman Materi Kuliah:
/// Menampilkan daftar mata kuliah, progres publikasi bahan ajar,
/// metrik materi, pemilih periode dropdown dinamis, dan rincian berkas materi per pertemuan.
class MateriScreen extends StatefulWidget {
  const MateriScreen({super.key});

  @override
  State<MateriScreen> createState() => _MateriScreenState();
}

class _MateriScreenState extends State<MateriScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  PeriodeProvider? _pp;
  String? _selectedPeriode;
  List<PeriodeOption> _periodeOpts = [];
  String _searchQuery = '';
  String _selectedFilter = 'all'; // all, tersedia, menunggu
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

    final resp = await api.get('/api/akademik/materi', query: {'periode': p});
    final data = resp is Map ? (resp['data'] ?? resp) : resp;
    final mapData = asMap(data);

    // Ekstrak opsi periode_tersedia jika dikembalikan oleh backend
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

  void _openMateriKelas(Map<String, dynamic> item, String periode) {
    final token = pickString(item, ['kelas_token', 'token', 'detail_token'], '');
    if (token.isEmpty) return;

    final nama = pickString(item, ['nama', 'nama_mk', 'matkul'], 'Materi Kelas');
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MateriKelasPage(
        kelasToken: token,
        periode: periode,
        judul: nama,
        initialData: item,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = context.isDark;
    final bg = context.bg;

    final metrics = asMap(_cachedData?['metrics']);
    final totalMateri = pickString(metrics, ['total_materi'], '');

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
                totalMateri: totalMateri,
              ),
              Positioned(
                bottom: -18,
                left: 0,
                right: 0,
                child: _buildFloatingPeriodePill(context, isDark),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const SizedBox(height: 32),

          // ──── BODY KONTEN ────
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting &&
                    _cachedData == null) {
                  return const Center(
                    child: LoadingView(label: 'Memuat bahan ajar kuliah...'),
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
                  return const EmptyView(message: 'Data materi kuliah tidak ditemukan');
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
    required String totalMateri,
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
                          'Materi Kuliah',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 21,
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
                        appToast(context, 'Memuat ulang daftar materi...');
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
                const SizedBox(height: 16),

                // Profile Avatar + Name & NIM + Total Materi Pill
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
                              const SizedBox(width: 8),
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
                              if (totalMateri.isNotEmpty) ...[
                                const SizedBox(width: 6),
                              if (totalMateri.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    totalMateri,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ],
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

    // Hitung counter status filter
    int tersediaCount = 0;
    int menungguCount = 0;

    for (final item in allItems) {
      final status = pickString(item, ['status_label', 'status'], '').toLowerCase();
      final progress = pickString(item, ['progress'], '');
      final isTersedia = progress.startsWith(RegExp(r'[1-9]')) ||
          status.contains('tersedia') ||
          status.contains('diterbitkan');

      if (isTersedia) {
        tersediaCount++;
      } else {
        menungguCount++;
      }
    }

    // Filter berdasarkan pencarian & tab status
    final filtered = allItems.where((item) {
      final name = pickString(item, ['nama', 'matkul', 'nama_mk'], '').toLowerCase();
      final code = pickString(item, ['kode', 'kode_mk'], '').toLowerCase();
      final dosen = pickString(item, ['dosen', 'nama_dosen'], '').toLowerCase();
      final kelas = pickString(item, ['kelas'], '').toLowerCase();
      final q = _searchQuery.toLowerCase().trim();

      if (q.isNotEmpty &&
          !name.contains(q) &&
          !code.contains(q) &&
          !dosen.contains(q) &&
          !kelas.contains(q)) {
        return false;
      }

      final status = pickString(item, ['status_label', 'status'], '').toLowerCase();
      final progress = pickString(item, ['progress'], '');
      final isTersedia = progress.startsWith(RegExp(r'[1-9]')) ||
          status.contains('tersedia') ||
          status.contains('diterbitkan');

      if (_selectedFilter == 'tersedia' && !isTersedia) {
        return false;
      }
      if (_selectedFilter == 'menunggu' && isTersedia) {
        return false;
      }

      return true;
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
      children: [
        // 1. OVERVIEW & METRICS CARD NEUMORPHIC
        _buildOverviewCard(context, data),

        const SizedBox(height: 16),

        // 2. SEARCH BAR NEUMORPHIC
        _buildSearchBar(context),

        const SizedBox(height: 12),

        // 3. FILTER CHIPS
        _buildFilterChips(
          context,
          allCount: allItems.length,
          tersediaCount: tersediaCount,
          menungguCount: menungguCount,
        ),

        const SizedBox(height: 14),

        // 4. LIST MATA KULIAH MATERI
        if (filtered.isEmpty) ...[
          const SizedBox(height: 30),
          _buildEmptyState(context),
          const SizedBox(height: 40),
        ] else ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              'Menampilkan ${filtered.length} kelas perkuliahan',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: context.textMuted,
              ),
            ),
          ),
          for (final item in filtered) ...[
            _MateriCard(
              item: item,
              neuCardBuilder: _buildNeuCard,
              onTap: () => _openMateriKelas(item, periode),
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
    final totalMateri = pickString(metrics, ['total_materi'], '0 Berkas');
    final cakupanPertemuan = pickString(metrics, ['cakupan_pertemuan'], '0 Pertemuan');
    final totalKelas = pickString(metrics, ['mata_kuliah'], '8 Kelas');

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
                  Icons.folder_copy_rounded,
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
                      'Statistik Bahan Ajar',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Rangkuman berkas materi kuliah semester ini',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.upiYellowDeep.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.upiYellowDeep.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.file_present_rounded, size: 14, color: AppColors.upiYellowDeep),
                    const SizedBox(width: 5),
                    Text(
                      totalMateri,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.upiYellowDeep,
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

          // Metrik Ringkas 3 Kolom
          Row(
            children: [
              Expanded(
                child: _statItem(
                  context,
                  label: 'Total Materi',
                  value: totalMateri,
                  icon: Icons.inventory_2_outlined,
                  color: AppColors.upiYellowDeep,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statItem(
                  context,
                  label: 'Cakupan Sesi',
                  value: cakupanPertemuan,
                  icon: Icons.calendar_view_week_rounded,
                  color: AppColors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statItem(
                  context,
                  label: 'Mata Kuliah',
                  value: totalKelas,
                  icon: Icons.class_outlined,
                  color: AppColors.blue,
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
          hintText: 'Cari mata kuliah, kode, kelas, atau dosen...',
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
    required int tersediaCount,
    required int menungguCount,
  }) {
    final filters = [
      {'key': 'all', 'label': 'Semua', 'count': allCount, 'color': AppColors.upiYellowDeep},
      {'key': 'menunggu', 'label': 'Menunggu Publikasi', 'count': menungguCount, 'color': AppColors.grey},
      if (tersediaCount > 0)
        {'key': 'tersedia', 'label': 'Tersedia', 'count': tersediaCount, 'color': AppColors.green},
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
          final isSelected = _selectedFilter == key;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IosBounceTap(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedFilter = key;
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
              Icons.menu_book_outlined,
              size: 28,
              color: AppColors.upiYellowDeep,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Materi Tidak Ditemukan',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tidak ada kelas materi yang cocok dengan pencarian atau filter Anda.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: context.textMuted),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () {
              _searchCtrl.clear();
              setState(() {
                _searchQuery = '';
                _selectedFilter = 'all';
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

/// Kartu Kelas Materi
class _MateriCard extends StatelessWidget {
  const _MateriCard({
    required this.item,
    required this.neuCardBuilder,
    required this.onTap,
  });

  final Map<String, dynamic> item;
  final Widget Function({
    required BuildContext context,
    required Widget child,
    EdgeInsetsGeometry padding,
    VoidCallback? onTap,
  }) neuCardBuilder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = pickString(item, ['nama', 'matkul', 'nama_mk'], 'Mata Kuliah');
    final kode = pickString(item, ['kode', 'kode_mk'], '');
    final kelas = pickString(item, ['kelas'], '');
    final dosen = pickString(item, ['dosen'], '');
    final hari = pickString(item, ['hari'], '');
    final jam = pickString(item, ['jam'], '');
    final ruang = pickString(item, ['ruang'], '');
    final info = pickString(item, ['info'], '');
    final progress = pickString(item, ['progress'], '0/16 pertemuan');
    final statusLabel = pickString(item, ['status_label', 'status'], 'Menunggu publikasi dosen');

    // Pakai progress_percent dari API bila tersedia; jika tidak, hitung dari string.
    final progressVal = double.tryParse(RegExp(r'(\d+)').firstMatch(progress)?.group(1) ?? '0') ?? 0;
    final apiPercent = num.tryParse('${item['progress_percent'] ?? ''}');
    final progressPct = apiPercent != null
        ? (apiPercent / 100).clamp(0.0, 1.0).toDouble()
        : (progressVal / 16).clamp(0.0, 1.0).toDouble();

    final isTersedia = progressVal > 0 || statusLabel.toLowerCase().contains('tersedia');
    final statusColor = isTersedia ? AppColors.green : AppColors.grey;

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
                  Icons.folder_open_rounded,
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
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.upiYellowDeep),
            ],
          ),

          const SizedBox(height: 12),

          // Baris Progress Materi & Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Materi: $progress',
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
              value: progressPct,
              minHeight: 6,
              backgroundColor: context.softFill,
              valueColor: AlwaysStoppedAnimation(statusColor),
            ),
          ),

          const SizedBox(height: 12),
          Divider(height: 1, color: context.border.withValues(alpha: 0.5)),
          const SizedBox(height: 10),

          // Baris Jadwal, Ruang, Dosen
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

              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Lihat Materi',
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

// ====================================================================
// Halaman Rincian Materi Kelas (16 Pertemuan + Materi Umum)
// ====================================================================

class MateriKelasPage extends StatefulWidget {
  const MateriKelasPage({
    super.key,
    required this.kelasToken,
    required this.periode,
    required this.judul,
    this.initialData,
  });

  final String kelasToken;
  final String periode;
  final String judul;
  final Map<String, dynamic>? initialData;

  @override
  State<MateriKelasPage> createState() => _MateriKelasPageState();
}

class _MateriKelasPageState extends State<MateriKelasPage> {
  late Future<Map<String, dynamic>> _future;
  Map<String, dynamic>? _cachedData;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = _fetch();
    });
  }

  Future<Map<String, dynamic>> _fetch() async {
    final api = context.read<ApiClient>();
    final resp = await api.get(
      '/api/akademik/materi/kelas/${widget.kelasToken}',
      query: {'periode': widget.periode},
    );
    final data = resp is Map ? (resp['data'] ?? resp) : resp;
    final mapData = asMap(data);
    if (mounted) {
      setState(() {
        _cachedData = mapData;
      });
    }
    return mapData;
  }

  // ────────────────────────────────────────────────── NEUMORPHIC CARD HELPER
  Widget _buildNeuCard({
    required BuildContext context,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    final isDark = context.isDark;
    return Container(
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
  }

  @override
  Widget build(BuildContext context) {
    final bg = context.bg;

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          // ──── HEADER KUNING DENGAN LEKUKAN BERSAMBUNG ────
          _buildCurvedHeader(context),

          // ──── DAFTAR PERTEMUAN ────
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting &&
                    _cachedData == null) {
                  return const Center(
                    child: LoadingView(label: 'Memuat berkas pertemuan...'),
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
                  return const EmptyView(message: 'Data materi kelas tidak tersedia.');
                }
                return RefreshIndicator(
                  color: AppColors.upiYellowDeep,
                  backgroundColor:
                      context.card,
                  onRefresh: () async {
                    _reload();
                    await _future;
                  },
                  child: _buildBody(context, _cachedData!),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurvedHeader(BuildContext context) {
    final kode = pickString(_cachedData ?? {}, ['kode'], pickString(widget.initialData ?? {}, ['kode'], ''));
    final kelas = pickString(_cachedData ?? {}, ['kelas'], pickString(widget.initialData ?? {}, ['kelas'], ''));

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
                        IconButton(
                          onPressed: () {
                            Navigator.of(context).maybePop();
                          },
                          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                          tooltip: 'Kembali',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Bahan Ajar Kelas',
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
                        appToast(context, 'Memuat ulang materi...');
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
                  widget.judul,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (kode.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          kode,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (kelas.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Kelas $kelas',
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

  Widget _buildBody(BuildContext context, Map<String, dynamic> data) {
    final dosen = pickString(data, ['dosen'], pickString(widget.initialData ?? {}, ['dosen'], ''));
    final sks = pickString(data, ['sks'], pickString(widget.initialData ?? {}, ['info'], ''));
    final materiTersedia = pickString(data, ['materi_tersedia', 'total_materi_tampil'], '0 Materi');
    final materiDesc = pickString(data, ['materi_desc'], '');

    final pertemuanList = asList(data['pertemuan']).map((e) => asMap(e)).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 104),
      children: [
        // 1. INFO CARD NEUMORPHIC
        _buildNeuCard(
          context: context,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.upiYellowDeep.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.menu_book_rounded,
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
                          'Ringkasan Perkuliahan',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: context.textPrimary,
                          ),
                        ),
                        if (dosen.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            dosen,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: context.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.upiYellowDeep.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.upiYellowDeep.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      materiTersedia,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.upiYellowDeep,
                      ),
                    ),
                  ),
                ],
              ),
              if (sks.isNotEmpty || materiDesc.isNotEmpty) ...[
                const SizedBox(height: 12),
                Divider(height: 1, color: context.border.withValues(alpha: 0.5)),
                const SizedBox(height: 8),
                if (sks.isNotEmpty)
                  Text(
                    'Beban: $sks',
                    style: TextStyle(fontSize: 11.5, color: context.textMuted, fontWeight: FontWeight.w600),
                  ),
                if (materiDesc.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      materiDesc,
                      style: TextStyle(fontSize: 11.5, color: context.textMuted),
                    ),
                  ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 20),

        // 2. SECTION TITLE
        SectionTitle('Rincian Bahan Ajar (${pertemuanList.length} Sesi)'),
        const SizedBox(height: 12),

        // 3. DAFTAR PERTEMUAN & BERKAS MATERI
        if (pertemuanList.isEmpty)
          const EmptyView(message: 'Belum ada data pertemuan untuk kelas ini.')
        else
          for (final p in pertemuanList)
            _buildPertemuanItem(context, p),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildPertemuanItem(BuildContext context, Map<String, dynamic> p) {
    final judul = pickString(p, ['judul'], 'Pertemuan');
    final label = pickString(p, ['label'], '');
    final total = pickString(p, ['total'], '0 materi');
    final kosongMsg = pickString(p, ['kosong_msg'], 'Belum ada materi yang diterbitkan.');
    final materiList = asList(p['materi']).map((e) => asMap(e)).toList();

    final hasMateri = materiList.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _buildNeuCard(
        context: context,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Sesi Pertemuan
            Row(
              children: [
                if (label.isNotEmpty)
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: hasMateri
                          ? AppColors.green.withValues(alpha: 0.12)
                          : AppColors.upiYellowDeep.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: hasMateri ? AppColors.green : AppColors.upiYellowDeep,
                      ),
                    ),
                  ),
                Expanded(
                  child: Text(
                    judul,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: hasMateri
                        ? AppColors.green.withValues(alpha: 0.12)
                        : context.softFill,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: hasMateri
                          ? AppColors.green.withValues(alpha: 0.3)
                          : context.border,
                    ),
                  ),
                  child: Text(
                    total,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: hasMateri ? AppColors.green : context.textMuted,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Daftar Berkas Materi atau Pesan Kosong
            if (hasMateri) ...[
              for (final m in materiList)
                _buildFileCard(context, m),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.softFill,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 15, color: context.textMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        kosongMsg,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: context.textMuted,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFileCard(BuildContext context, Map<String, dynamic> m) =>
      _MateriFileCard(item: m);
}
// ─────────────────────────────────────────────────────────────────────────
// Kartu berkas materi: menampilkan tipe/ikon/tanggal, serta tombol buka yang
// memakai POST /api/akademik/materi/resolve untuk memperoleh tautan
// PDF/Drive langsung (pdf_url) sebelum membuka. Bila resolve gagal,
// fallback ke URL materi asli.
// ─────────────────────────────────────────────────────────────────────────
class _MateriFileCard extends StatefulWidget {
  const _MateriFileCard({required this.item});

  final Map<String, dynamic> item;

  @override
  State<_MateriFileCard> createState() => _MateriFileCardState();
}

class _MateriFileCardState extends State<_MateriFileCard> {
  bool _resolving = false;

  Map<String, dynamic> get _m => widget.item;

  bool get _isGdrive => pickString(_m, ['kind'], '').toLowerCase() == 'gdrive';

  Future<void> _open() async {
    final raw = pickString(_m, ['url', 'download_url', 'link'], '');
    final existing = pickString(_m, ['pdf_url', 'final_url'], '');
    HapticFeedback.selectionClick();

    // Sudah ada URL langsung → langsung buka.
    if (existing.isNotEmpty) {
      await openExternal(context, existing);
      return;
    }
    if (raw.isEmpty || !raw.startsWith('http')) {
      appToast(context, 'Tautan materi tidak tersedia.', error: true);
      return;
    }

    final api = context.read<ApiClient>();
    setState(() => _resolving = true);
    try {
      final resp = await api.post('/api/akademik/materi/resolve',
          body: {'url': raw});
      final data = resp is Map ? (resp['data'] ?? resp) : resp;
      final map = asMap(data);
      final resolved = pickString(map, ['pdf_url', 'final_url'], '');
      if (!mounted) return;
      setState(() => _resolving = false);
      await openExternal(context, resolved.isNotEmpty ? resolved : raw);
    } catch (_) {
      if (!mounted) return;
      setState(() => _resolving = false);
      // Fallback: buka tautan SIAKAD asli (butuh sesi login di browser).
      await openExternal(context, raw);
    }
  }

  IconData _iconFor(String tipe) {
    // Prioritaskan nama icon MDI dari API bila dikenali.
    switch (pickString(_m, ['icon'], '')) {
      case 'play-circle-outline':
      case 'play-circle':
        return Icons.play_circle_outline_rounded;
      case 'file-pdf-box':
      case 'file-pdf-outline':
        return Icons.picture_as_pdf_rounded;
      case 'file-powerpoint':
      case 'file-powerpoint-box':
        return Icons.slideshow_rounded;
      case 'file-word':
      case 'file-word-box':
        return Icons.article_rounded;
      case 'folder-zip':
      case 'zip-box':
        return Icons.folder_zip_rounded;
      case 'link':
      case 'link-variant':
        return Icons.link_rounded;
    }
    if (tipe.contains('pdf')) return Icons.picture_as_pdf_rounded;
    if (tipe.contains('video')) return Icons.play_circle_outline_rounded;
    if (tipe.contains('ppt') || tipe.contains('presentation')) {
      return Icons.slideshow_rounded;
    }
    if (tipe.contains('doc') || tipe.contains('word')) {
      return Icons.article_rounded;
    }
    if (tipe.contains('zip') || tipe.contains('rar')) {
      return Icons.folder_zip_rounded;
    }
    if (tipe.contains('link') || tipe.contains('tautan')) {
      return Icons.link_rounded;
    }
    return Icons.insert_drive_file_rounded;
  }

  Color _colorFor(String tipe) {
    if (tipe.contains('pdf')) return AppColors.red;
    if (tipe.contains('video')) return AppColors.blue;
    if (tipe.contains('ppt')) return AppColors.orange;
    if (tipe.contains('doc')) return AppColors.blue;
    if (tipe.contains('zip') || tipe.contains('rar')) return AppColors.orange;
    return AppColors.upiYellowDeep;
  }

  Widget _pill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      );
  @override
  Widget build(BuildContext context) {
    final title = pickString(_m, ['judul', 'nama', 'title'], 'Berkas Materi');
    final desc = pickString(_m, ['deskripsi', 'keterangan'], '');
    final tipe = pickString(_m, ['tipe'], 'pdf').toLowerCase();
    final tanggal = pickString(_m, ['tanggal'], '');
    final actionLabel = pickString(_m, ['action_label'], 'Buka');
    final hasUrl =
        pickString(_m, ['url', 'download_url', 'link', 'pdf_url'], '')
            .startsWith('http');

    final fileIcon = _iconFor(tipe);
    final fileColor = _colorFor(tipe);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fileColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fileColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(fileIcon, size: 20, color: fileColor),
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
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: context.textMuted),
                  ),
                ],
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _pill(tipe.isEmpty ? 'berkas' : tipe, fileColor),
                    if (_isGdrive) _pill('Google Drive', AppColors.green),
                    if (tanggal.isNotEmpty)
                      Text(
                        tanggal,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: context.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (hasUrl)
            IosBounceTap(
              onTap: _resolving ? null : _open,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.upiYellowDeep.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: _resolving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: AppColors.upiYellowDeep,
                        ),
                      )
                    : Icon(
                        tipe.contains('video')
                            ? Icons.play_arrow_rounded
                            : Icons.open_in_new_rounded,
                        color: AppColors.upiYellowDeep,
                        size: 20,
                        semanticLabel: actionLabel,
                      ),
              ),
            ),
        ],
      ),
    );
  }
}
