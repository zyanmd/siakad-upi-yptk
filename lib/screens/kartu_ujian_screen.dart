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

// ── UPI YPTK Academic Gold Gradient ──
const _yellowHeaderGradient = [
  Color(0xFFE5A620), // Bright Academic Gold
  Color(0xFFD48B08), // UPI Yellow
  Color(0xFFB87500), // Deep Academic Gold
];

/// Kartu Ujian (UTS, UAS, SISKOM) dengan identitas mahasiswa, status cetak,
/// metrik ringkas, pencarian real-time, dan daftar mata kuliah terverifikasi
/// berdesain Seamless Wave Header & Neumorphic UI.
class KartuUjianScreen extends StatefulWidget {
  const KartuUjianScreen({super.key});

  @override
  State<KartuUjianScreen> createState() => _KartuUjianScreenState();
}

class _KartuUjianScreenState extends State<KartuUjianScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  PeriodeProvider? _pp;
  String _jenis = 'uts'; // uts, uas, siskom
  String? _selectedPeriode;
  List<PeriodeOption> _periodeOpts = [];
  String _searchQuery = '';
  String _filterStatus = 'all'; // all, eligible, ineligible
  bool _isPrinting = false;

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

    final resp = await api.get(
      '/api/akademik/kartu-ujian',
      query: {'jenis': _jenis, 'periode': p},
    );
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

  Future<void> _handleCetak(Map<String, dynamic>? data) async {
    final pb = asMap(data?['print_button']);
    final bool isEnabled = pb['enabled'] == true;
    final String defaultMsg = pickString(
      pb,
      ['message'],
      'Pencetakan kartu ${_jenis.toUpperCase()} pada periode ini belum dibuka.',
    );

    if (!isEnabled) {
      _showPrintInfoDialog(defaultMsg, data);
      return;
    }

    setState(() => _isPrinting = true);
    try {
      final api = context.read<ApiClient>();
      final p = _selectedPeriode ??
          context.read<PeriodeProvider>().value ??
          fallbackPeriode();

      final resp = await api.get(
        '/api/akademik/kartu-ujian/cetak-url',
        query: {'jenis': _jenis, 'periode': p},
      );

      final isSuccess = resp is Map && resp['success'] == true;
      final url = resp is Map ? resp['url']?.toString() : null;
      final msg = resp is Map
          ? pickString(asMap(resp), ['message'], defaultMsg)
          : defaultMsg;

      if (!mounted) return;

      if (isSuccess && url != null && url.startsWith('http')) {
        await openExternal(context, url);
      } else {
        _showPrintInfoDialog(msg, data);
      }
    } catch (e) {
      if (mounted) appToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  void _showPrintInfoDialog(
    String message,
    Map<String, dynamic>? data,
  ) {
    final preview = asMap(data?['preview']);
    final rentangMulai = pickString(preview, ['rentang_mulai'], '');
    final rentangSelesai = pickString(preview, ['rentang_selesai'], '');
    final statusPrintLabel = pickString(
      preview,
      ['status_print_label', 'status_print_desc'],
      'Pencetakan Ditutup',
    );
    final statusPrintDesc = pickString(preview, ['status_print_desc'], '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.print_disabled_rounded,
                color: AppColors.upiYellowDeep,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Status Cetak Kartu',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(fontSize: 13.5, height: 1.45),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ctx.softFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ctx.border),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 15, color: AppColors.upiYellowDeep),
                      const SizedBox(width: 6),
                      Text(
                        'Status: $statusPrintLabel',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (statusPrintDesc.isNotEmpty &&
                          statusPrintDesc != statusPrintLabel) ...[
                        const SizedBox(width: 4),
                        Text(
                          '($statusPrintDesc)',
                          style: TextStyle(fontSize: 11, color: ctx.textMuted),
                        ),
                      ],
                    ],
                  ),
                  if (rentangMulai.isNotEmpty || rentangSelesai.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.calendar_month_rounded,
                            size: 15, color: AppColors.upiYellowDeep),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Jadwal: $rentangMulai ${rentangSelesai.isNotEmpty ? "s.d. $rentangSelesai" : ""}',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: ctx.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.upiYellowDeep,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  void _onSelectPeriode(String? newPeriode) {
    if (newPeriode == null || newPeriode == _selectedPeriode) return;
    setState(() {
      _selectedPeriode = newPeriode;
    });
    context.read<PeriodeProvider>().set(newPeriode);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = context.isDark;
    final bg = isDark ? const Color(0xFF000000) : const Color(0xFFF9FAFB);

    final preview = asMap(_cachedData?['preview']);
    final statusPrintLabel =
        pickString(preview, ['status_print_label'], 'Pencetakan Ditutup');

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          // ──── HEADER KUNING DENGAN LEKUKAN BERSAMBUNG & FLOATING SEGMENTED PILL ────
          Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              _buildCurvedYellowHeader(
                nama: auth.nama,
                nim: auth.nim,
                statusPrintLabel: statusPrintLabel,
              ),
              Positioned(
                bottom: -18,
                left: 0,
                right: 0,
                child: _buildFloatingSegmentedPill(context, isDark),
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
                    child: LoadingView(label: 'Memuat jadwal kartu ujian...'),
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
                  return const EmptyView(message: 'Data kartu ujian tidak ditemukan');
                }
                return RefreshIndicator(
                  color: AppColors.upiYellowDeep,
                  backgroundColor:
                      isDark ? const Color(0xFF1E1E22) : Colors.white,
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

  // ────────────────────────────────────────────────── HEADER KUNING DENGAN LEKUKAN BERSAMBUNG
  Widget _buildCurvedYellowHeader({
    required String nama,
    required String nim,
    required String statusPrintLabel,
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
                // Top Row: Back + Title + Action buttons (Cetak & Refresh)
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
                          'Kartu Ujian',
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
                        IconButton(
                          onPressed: () => _handleCetak(_cachedData),
                          icon: _isPrinting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.print_rounded,
                                  color: Colors.white, size: 22),
                          tooltip: 'Cetak Kartu Ujian',
                          splashRadius: 20,
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            _reload();
                          },
                          icon: const Icon(Icons.refresh_rounded,
                              color: Colors.white, size: 22),
                          tooltip: 'Muat Ulang',
                          splashRadius: 20,
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Student Identity Row
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(14),
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
                            fontSize: 20,
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
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
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
                                  fontSize: 12.5,
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
                                child: Text(
                                  _jenis.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                              if (statusPrintLabel.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    statusPrintLabel,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
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

  // ────────────────────────────────────────────────── FLOATING SEGMENTED PILL (UTS / UAS / SISKOM)
  Widget _buildFloatingSegmentedPill(BuildContext context, bool isDark) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E22) : Colors.white,
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _segmentButton('UTS', 'uts', Icons.edit_note_rounded, isDark),
            _segmentButton('UAS', 'uas', Icons.fact_check_rounded, isDark),
            _segmentButton('SISKOM', 'siskom', Icons.tune_rounded, isDark),
          ],
        ),
      ),
    );
  }

  Widget _segmentButton(String label, String value, IconData icon, bool isDark) {
    final isSelected = _jenis == value;

    return IosBounceTap(
      onTap: () {
        if (_jenis == value) return;
        HapticFeedback.selectionClick();
        setState(() {
          _jenis = value;
          _cachedData = null; // refresh clean
        });
        _reload();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.upiYellowDeep
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.upiYellowDeep.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? Colors.white
                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
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

  // ────────────────────────────────────────────────── BODY
  Widget _buildBody(BuildContext context, Map<String, dynamic> data) {
    final rawList = <Map<String, dynamic>>[];
    if (data['mata_kuliah'] is List) {
      for (final item in (data['mata_kuliah'] as List)) {
        if (item is Map) rawList.add(asMap(item));
      }
    }

    // Hitung metrik eligible
    final eligibleCount = rawList.where((it) {
      final sk = pickString(it, ['status_kind'], '');
      final st = pickString(it, ['status'], '').toLowerCase();
      return sk == 'eligible' || st.contains('dapat');
    }).length;
    final ineligibleCount = rawList.length - eligibleCount;

    // Filter pencarian dan status
    final q = _searchQuery.toLowerCase().trim();
    final filteredList = rawList.where((it) {
      // Status filter
      if (_filterStatus == 'eligible') {
        final sk = pickString(it, ['status_kind'], '');
        final st = pickString(it, ['status'], '').toLowerCase();
        if (!(sk == 'eligible' || st.contains('dapat'))) return false;
      } else if (_filterStatus == 'ineligible') {
        final sk = pickString(it, ['status_kind'], '');
        final st = pickString(it, ['status'], '').toLowerCase();
        if (sk == 'eligible' || st.contains('dapat')) return false;
      }

      // Search query
      if (q.isEmpty) return true;
      final nama = pickString(it, ['nama', 'nama_mk']).toLowerCase();
      final kode = pickString(it, ['kode', 'kode_mk']).toLowerCase();
      final kelas = pickString(it, ['kelas']).toLowerCase();
      final dosen = pickString(it, ['dosen']).toLowerCase();
      return nama.contains(q) ||
          kode.contains(q) ||
          kelas.contains(q) ||
          dosen.contains(q);
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 104),
      children: [
        // Opsi Periode jika tersedia
        if (_periodeOpts.isNotEmpty) ...[
          _buildPeriodePill(context),
          const SizedBox(height: 12),
        ],

        // Hero Card: Mahasiswa, Jadwal Ujian, Status Cetak
        _buildHeroCard(context, data),
        const SizedBox(height: 14),

        // Metrik Ringkas
        _buildMetricsGrid(context, data, rawList.length, eligibleCount, ineligibleCount),
        const SizedBox(height: 16),

        // Search Bar & Filter Chips
        _buildSearchAndFilters(
          context,
          totalCount: rawList.length,
          eligibleCount: eligibleCount,
          ineligibleCount: ineligibleCount,
        ),
        const SizedBox(height: 14),

        // Daftar Mata Kuliah
        if (filteredList.isEmpty)
          _buildNeuCard(
            context: context,
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            child: Column(
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 48,
                  color: context.textMuted.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 12),
                Text(
                  rawList.isEmpty
                      ? 'Belum ada jadwal kartu ujian ${_jenis.toUpperCase()} pada periode ini.'
                      : 'Tidak ada mata kuliah yang cocok dengan kata kunci pencarian.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.textMuted,
                  ),
                ),
              ],
            ),
          )
        else
          for (final item in filteredList) ...[
            _UjianCard(
              item: item,
              neuBuilder: _buildNeuCard,
            ),
            const SizedBox(height: 12),
          ],

        const SizedBox(height: 20),
      ],
    );
  }

  // ────────────────────────────────────────────────── PERIODE PILL
  Widget _buildPeriodePill(BuildContext context) {
    final activeValue = _periodeOpts.any((o) => o.value == _selectedPeriode)
        ? _selectedPeriode
        : (_periodeOpts.isNotEmpty ? _periodeOpts.first.value : _selectedPeriode);

    return _buildNeuCard(
      context: context,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: PillDropdown(
        value: activeValue,
        hint: 'Pilih Periode',
        items: [
          for (final o in _periodeOpts)
            DropdownMenuItem<String>(
              value: o.value,
              child: Text(
                o.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: _onSelectPeriode,
      ),
    );
  }

  // ────────────────────────────────────────────────── HERO CARD
  Widget _buildHeroCard(BuildContext context, Map<String, dynamic> data) {
    final mhs = asMap(data['mahasiswa']);
    final nama = pickString(mhs, ['nama'], 'Mahasiswa');
    final nim = pickString(mhs, ['nim'], '-');
    final prodi = pickString(mhs, ['prodi'], '-');
    final inisial =
        pickString(mhs, ['inisial'], nama.isNotEmpty ? nama[0] : 'M');

    final preview = asMap(data['preview']);
    final jenisUjian = pickString(
      preview,
      ['jenis_ujian'],
      'Ujian Semester (${_jenis.toUpperCase()})',
    );
    final periode =
        pickString(preview, ['periode'], pickString(data, ['periode'], ''));
    final periodeTahun = pickString(preview, ['periode_tahun'], '');
    final rentangMulai = pickString(preview, ['rentang_mulai'], '');
    final rentangSelesai = pickString(preview, ['rentang_selesai'], '');
    final statusPrint = pickString(preview, ['status_print'], 'closed');
    final statusPrintLabel =
        pickString(preview, ['status_print_label'], 'Pencetakan Ditutup');
    final statusPrintDesc =
        pickString(preview, ['status_print_desc'], 'BELUM AKTIF');

    final pb = asMap(data['print_button']);
    final isPrintEnabled = pb['enabled'] == true;
    final printLabel =
        pickString(pb, ['label'], 'Cetak Kartu ${_jenis.toUpperCase()}');
    final printMsg = pickString(
      pb,
      ['message'],
      'Pencetakan kartu ${_jenis.toUpperCase()} pada periode ini belum dibuka.',
    );

    final isOpen = statusPrint.toLowerCase() == 'open';
    final Color statusBadgeColor = isOpen ? AppColors.green : AppColors.amber;

    return _buildNeuCard(
      context: context,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Identitas Mahasiswa
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.amber, AppColors.upiYellowDeep],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.upiYellowDeep.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  inisial.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 19,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nama,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          nim,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.upiYellowDeep,
                          ),
                        ),
                        if (prodi.isNotEmpty) ...[
                          Text(
                            ' • ',
                            style: TextStyle(
                                color: context.textMuted, fontSize: 12),
                          ),
                          Expanded(
                            child: Text(
                              prodi,
                              style: TextStyle(
                                fontSize: 12,
                                color: context.textMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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

          const SizedBox(height: 14),
          Divider(height: 1, color: context.border),
          const SizedBox(height: 12),

          // Jadwal & Status Pelaksanaan Ujian
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      jenisUjian,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary,
                        height: 1.25,
                      ),
                    ),
                    if (periode.isNotEmpty || periodeTahun.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        [periode, periodeTahun]
                            .where((s) => s.isNotEmpty)
                            .join(' • '),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: context.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Status Cetak Badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: statusBadgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: statusBadgeColor.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isOpen
                              ? Icons.check_circle_rounded
                              : Icons.lock_clock_rounded,
                          size: 13,
                          color: statusBadgeColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          statusPrintLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: statusBadgeColor,
                          ),
                        ),
                      ],
                    ),
                    if (statusPrintDesc.isNotEmpty &&
                        statusPrintDesc != statusPrintLabel) ...[
                      const SizedBox(height: 1),
                      Text(
                        statusPrintDesc,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: statusBadgeColor.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          // Tanggal Pelaksanaan Ujian
          if (rentangMulai.isNotEmpty || rentangSelesai.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6.5),
              decoration: BoxDecoration(
                color: context.softFill,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_month_rounded,
                    size: 14,
                    color: AppColors.upiYellowDeep,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Jadwal Ujian: $rentangMulai ${rentangSelesai.isNotEmpty ? "s.d. $rentangSelesai" : ""}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Action Button Cetak
          SizedBox(
            width: double.infinity,
            child: isPrintEnabled
                ? IosBounceTap(
                    onTap: _isPrinting ? null : () => _handleCetak(data),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE5A620), Color(0xFFB87500)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.upiYellowDeep.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isPrinting) ...[
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Memproses Cetak...',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ] else ...[
                            const Icon(Icons.print_rounded,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              printLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                : OutlinedButton(
                    onPressed: () => _handleCetak(data),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      side: BorderSide(color: context.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 16, color: AppColors.amber),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            printMsg,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: context.textMuted,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right_rounded,
                            size: 18, color: context.textMuted),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────── METRICS GRID
  Widget _buildMetricsGrid(
    BuildContext context,
    Map<String, dynamic> data,
    int calculatedTotalMk,
    int calculatedEligible,
    int calculatedIneligible,
  ) {
    final metrics = asMap(data['metrics']);
    final totalSks = pickString(metrics, ['total_sks'], '-');
    final totalSksDesc = pickString(metrics, ['total_sks_desc'], 'Total SKS');
    final totalMk = pickString(metrics, ['mata_kuliah'], calculatedTotalMk.toString());
    final totalMkDesc =
        pickString(metrics, ['mata_kuliah_desc'], 'Mata Kuliah');
    final dapat = pickString(metrics, ['dapat_mengikuti'], calculatedEligible.toString());
    final dapatDesc =
        pickString(metrics, ['dapat_mengikuti_desc'], 'Dapat Mengikuti');
    final tidak = pickString(metrics, ['tidak_mengikuti'], calculatedIneligible.toString());
    final tidakDesc =
        pickString(metrics, ['tidak_mengikuti_desc'], 'Terkendala');

    final hasTerkendala = calculatedIneligible > 0 ||
        (tidak.isNotEmpty && tidak != 'null' && tidak != '0');

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _statItem(
                context,
                label: 'Total SKS',
                value: totalSks,
                sublabel: totalSksDesc,
                icon: Icons.credit_card_rounded,
                color: AppColors.amber,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _statItem(
                context,
                label: 'Mata Kuliah',
                value: totalMk,
                sublabel: totalMkDesc,
                icon: Icons.menu_book_rounded,
                color: AppColors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _statItem(
                context,
                label: 'Dapat Ujian',
                value: dapat,
                sublabel: dapatDesc,
                icon: Icons.verified_rounded,
                color: AppColors.green,
              ),
            ),
            if (hasTerkendala) ...[
              const SizedBox(width: 8),
              Expanded(
                child: _statItem(
                  context,
                  label: 'Terkendala',
                  value: tidak,
                  sublabel: tidakDesc,
                  icon: Icons.warning_rounded,
                  color: AppColors.red,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _statItem(
    BuildContext context, {
    required String label,
    required String value,
    required String sublabel,
    required IconData icon,
    required Color color,
  }) {
    return _buildNeuCard(
      context: context,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: context.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (sublabel.isNotEmpty && sublabel != label) ...[
            const SizedBox(height: 2),
            Text(
              sublabel,
              style: TextStyle(
                fontSize: 9.5,
                color: context.textMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────── SEARCH & FILTERS
  Widget _buildSearchAndFilters(
    BuildContext context, {
    required int totalCount,
    required int eligibleCount,
    required int ineligibleCount,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Input Field
        _buildNeuCard(
          context: context,
          padding: EdgeInsets.zero,
          child: TextField(
            controller: _searchCtrl,
            onChanged: (val) => setState(() => _searchQuery = val),
            style: TextStyle(fontSize: 13, color: context.textPrimary),
            decoration: InputDecoration(
              hintText: 'Cari mata kuliah, kode, kelas, atau dosen...',
              hintStyle: TextStyle(fontSize: 12.5, color: context.textMuted),
              prefixIcon: Icon(Icons.search_rounded,
                  size: 20, color: context.textMuted),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: InputBorder.none,
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _filterChip(
                label: 'Semua ($totalCount)',
                selected: _filterStatus == 'all',
                onSelected: () => setState(() => _filterStatus = 'all'),
              ),
              const SizedBox(width: 8),
              _filterChip(
                label: 'Dapat Mengikuti ($eligibleCount)',
                selected: _filterStatus == 'eligible',
                activeColor: AppColors.green,
                onSelected: () => setState(() => _filterStatus = 'eligible'),
              ),
              if (ineligibleCount > 0) ...[
                const SizedBox(width: 8),
                _filterChip(
                  label: 'Terkendala ($ineligibleCount)',
                  selected: _filterStatus == 'ineligible',
                  activeColor: AppColors.red,
                  onSelected: () =>
                      setState(() => _filterStatus = 'ineligible'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
    Color activeColor = AppColors.upiYellowDeep,
  }) {
    return IosBounceTap(
      onTap: onSelected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? activeColor.withValues(alpha: 0.14)
              : (context.isDark ? const Color(0xFF1C1C1E) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? activeColor.withValues(alpha: 0.6)
                : context.border,
            width: selected ? 1.4 : 1,
          ),
          boxShadow: [
            if (!selected)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? activeColor : context.textPrimary,
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────── KARTU MATA KULIAH UJIAN (NEUMORPHIC)
class _UjianCard extends StatelessWidget {
  const _UjianCard({
    required this.item,
    required this.neuBuilder,
  });

  final Map<String, dynamic> item;
  final Widget Function({
    required BuildContext context,
    required Widget child,
    EdgeInsetsGeometry padding,
    VoidCallback? onTap,
  }) neuBuilder;

  @override
  Widget build(BuildContext context) {
    final no = pickString(item, ['no'], '');
    final nama = pickString(
      item,
      ['nama', 'nama_mk', 'nm_mk', 'mata_kuliah'],
      'Mata Kuliah',
    );
    final kode = pickString(item, ['kode', 'kode_mk', 'kd_mk'], '');
    final kelas = pickString(item, ['kelas', 'nama_kelas'], '');
    final sks = pickString(item, ['sks'], '');
    final reguler = pickString(item, ['reguler', 'jenis'], '');
    final dosen = pickString(item, ['dosen', 'nama_dosen', 'pengajar'], '');
    final status = pickString(item, ['status'], 'Dapat Mengikuti');
    final statusKind = pickString(item, ['status_kind'], 'eligible');

    // Jadwal ujian opsional jika ada
    final tanggal = pickString(item, ['tanggal', 'tgl_ujian', 'hari'], '');
    final jam = pickString(item, ['jam', 'jam_ujian', 'waktu'], '');
    final ruang = pickString(item, ['ruang', 'ruangan', 'lokasi'], '');
    final kursi = pickString(item, ['kursi', 'no_kursi', 'nomor_kursi'], '');

    final isEligible = statusKind == 'eligible' ||
        status.toLowerCase().contains('dapat') ||
        status.toLowerCase().contains('memenuhi');
    final Color badgeColor = isEligible ? AppColors.green : AppColors.amber;

    return neuBuilder(
      context: context,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Baris Header Atas: Nomor & Kode MK di kiri, Status Badge di kanan
          Row(
            children: [
              if (no.isNotEmpty) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: context.softFill,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: context.border),
                  ),
                  child: Text(
                    'No. $no',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (kode.isNotEmpty)
                Expanded(
                  child: Text(
                    kode,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.upiYellowDeep,
                    ),
                  ),
                )
              else
                const Spacer(),
              const SizedBox(width: 8),
              // Status Badge
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: badgeColor.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isEligible
                            ? Icons.check_circle_rounded
                            : Icons.warning_amber_rounded,
                        size: 12,
                        color: badgeColor,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Judul Mata Kuliah
          Text(
            nama,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: context.textPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),

          // Detail SKS, Kelas, Reguler
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (sks.isNotEmpty)
                _metaPill(context, '$sks SKS'),
              if (kelas.isNotEmpty)
                _metaPill(context, 'Kelas $kelas'),
              if (reguler.isNotEmpty)
                _metaPill(context, reguler),
            ],
          ),

          // Jadwal ujian rincian jika ada
          if (tanggal.isNotEmpty ||
              jam.isNotEmpty ||
              ruang.isNotEmpty ||
              kursi.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (tanggal.isNotEmpty)
                  _infoChip(context, Icons.calendar_today_rounded, tanggal),
                if (jam.isNotEmpty)
                  _infoChip(context, Icons.schedule_rounded, jam),
                if (ruang.isNotEmpty)
                  _infoChip(context, Icons.place_rounded, 'R. $ruang'),
                if (kursi.isNotEmpty)
                  _infoChip(context, Icons.event_seat_rounded, 'Kursi $kursi'),
              ],
            ),
          ],

          const SizedBox(height: 10),
          Divider(height: 1, color: context.border),
          const SizedBox(height: 8),

          // Dosen Pengampu Row
          Row(
            children: [
              Icon(Icons.person_outline_rounded,
                  size: 13, color: context.textMuted),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  dosen.isNotEmpty ? dosen : 'Dosen belum ditentukan',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: context.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaPill(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: context.softFill,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: context.border),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: context.textMuted,
        ),
      ),
    );
  }

  Widget _infoChip(BuildContext context, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: context.softFill,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: context.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.upiYellowDeep),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
