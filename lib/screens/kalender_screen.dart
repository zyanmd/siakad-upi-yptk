import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../services/akademik_service.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../utils/kalender_pdf.dart';
import '../utils/smart.dart';
import '../widgets/common.dart';
import '../widgets/periode_dropdown.dart';
import 'kalender_cetak_screen.dart';

// ── UPI YPTK Academic Gold Gradient ──
const _yellowHeaderGradient = [
  Color(0xFFE5A620), // Bright Academic Gold
  Color(0xFFD48B08), // UPI Yellow
  Color(0xFFB87500), // Deep Academic Gold
];

/// Halaman Kalender Akademik Resmi Universitas:
/// Menampilkan daftar agenda penting perkuliahan lintas semester (Ganjil/Genap),
/// filter tahun akademik, metrik resmi, pencarian agenda, dan fitur cetak/ekspor PDF
/// berdesain Seamless Wave Header & Neumorphic UI.
class KalenderScreen extends StatefulWidget {
  const KalenderScreen({super.key});

  @override
  State<KalenderScreen> createState() => _KalenderScreenState();
}

class _KalenderScreenState extends State<KalenderScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  String _tahun = '2026/2027';
  String _searchQuery = '';
  String _selectedSemester = 'all'; // 'all', 'ganjil', 'genap'
  Map<String, dynamic>? _cachedData;
  Future<Map<String, dynamic>>? _future;
  bool _isDirectPrinting = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.trim();
      if (q != _searchQuery) {
        setState(() => _searchQuery = q);
      }
    });
    _reload();
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _load() async {
    final api = context.read<ApiClient>();
    final srv = AkademikService(api);

    Map<String, dynamic> result = {};

    // 1. Panggil GET /api/akademik/kalender
    try {
      final resp = await srv.kalender(_tahun);
      final rMap = asMap(resp);
      final data = asMap(rMap['data'] ?? rMap);
      if (data.isNotEmpty) {
        result = Map<String, dynamic>.from(data);
      }
    } catch (_) {}

    // 2. Jika kosong, panggil /api/akademik/kalender/data
    if (result.isEmpty || result['detail_aktif'] == null) {
      try {
        final dataResp = await srv.kalenderData(_tahun);
        final dMap = asMap(dataResp);
        final dData = asMap(dMap['data'] ?? dMap);
        if (dData.isNotEmpty) {
          result = Map<String, dynamic>.from(dData);
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _cachedData = result;
      });
    }

    return result;
  }

  void _bukaLembarCetak(Map<String, dynamic> data) {
    final detail = asMap(data['detail_aktif']);
    final token = pickString(detail, ['token'], '');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => KalenderCetakScreen(
          token: token,
          tahun: _tahun,
          initialData: detail.isNotEmpty ? detail : data,
        ),
      ),
    );
  }

  Future<void> _cetakPdfInstan(Map<String, dynamic> data) async {
    if (_isDirectPrinting) return;
    setState(() => _isDirectPrinting = true);
    try {
      final detail = asMap(data['detail_aktif']);
      final source = detail.isNotEmpty ? detail : data;
      final tahunSlug = _tahun.replaceAll('/', '_');

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async {
          return await KalenderPdfHelper.buildPdf(format, source);
        },
        name: 'Kalender_Akademik_$tahunSlug.pdf',
      );
    } catch (e) {
      if (mounted) {
        appToast(context, 'Gagal mencetak dokumen: $e', error: true);
      }
    } finally {
      if (mounted) setState(() => _isDirectPrinting = false);
    }
  }

  Future<void> _bukaWebSiakad(Map<String, dynamic> data) async {
    final detail = asMap(data['detail_aktif']);
    final url = pickString(detail, ['print_url', 'url'], pickString(data, ['canonical_url'], ''));
    if (url.isNotEmpty && url.startsWith('http')) {
      await openExternal(context, url);
    } else {
      if (mounted) {
        appToast(context, 'Tautan web kalender tidak tersedia.', error: true);
      }
    }
  }

  void _showActionSheet(Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.event_note_rounded,
                        color: AppColors.upiYellowDeep, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pilihan Kalender Akademik',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Tahun Akademik $_tahun',
                          style: const TextStyle(fontSize: 12, color: AppColors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.bolt_rounded, color: AppColors.green),
                ),
                title: const Text('Cetak / Simpan PDF (Instan)',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                subtitle: const Text(
                    'Render cepat dokumen PDF vektor resmi tanpa menunggu lama.',
                    style: TextStyle(fontSize: 11.5)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(ctx);
                  _cetakPdfInstan(data);
                },
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.upiYellowDeep.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.description_rounded,
                      color: AppColors.upiYellowDeep),
                ),
                title: const Text('Pratinjau Lembar Cetak Kalender',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                subtitle: const Text(
                    'Tampilan dokumen lembar cetak kertas & pratinjau PDF interaktif.',
                    style: TextStyle(fontSize: 11.5)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(ctx);
                  _bukaLembarCetak(data);
                },
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.open_in_browser_rounded,
                      color: AppColors.blue),
                ),
                title: const Text('Buka di Browser SIAKAD',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                subtitle: const Text('Buka halaman kalender akademik bawaan web kampus.',
                    style: TextStyle(fontSize: 11.5)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(ctx);
                  _bukaWebSiakad(data);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  (IconData, Color) _getCategoryIconAndColor(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('wisuda')) {
      return (Icons.workspace_premium_rounded, Colors.purple);
    } else if (lower.contains('uts') || lower.contains('uas') || lower.contains('ujian')) {
      return (Icons.assignment_turned_in_rounded, AppColors.red);
    } else if (lower.contains('libur') || lower.contains('lebaran')) {
      return (Icons.beach_access_rounded, Colors.teal);
    } else if (lower.contains('pembayaran') || lower.contains('uang kuliah')) {
      return (Icons.payments_rounded, AppColors.orange);
    } else if (lower.contains('awal kuliah') || lower.contains('kuliah')) {
      return (Icons.school_rounded, AppColors.blue);
    } else if (lower.contains('pa') || lower.contains('dosen')) {
      return (Icons.groups_rounded, AppColors.indigo700);
    } else if (lower.contains('skripsi') || lower.contains('nilai')) {
      return (Icons.menu_book_rounded, AppColors.amber);
    }
    return (Icons.event_available_rounded, AppColors.upiYellowDeep);
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
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

    // Dapatkan opsi tahun dari cached data jika ada
    final filterObj = asMap(_cachedData?['filter']);
    final rawTahunList = filterObj['tahun_tersedia'];
    final List<String> tahunOptions = [];
    if (rawTahunList is List && rawTahunList.isNotEmpty) {
      for (final t in rawTahunList) {
        if (t is Map) {
          final val = pickString(asMap(t), ['value', 'label'], '');
          if (val.isNotEmpty && !tahunOptions.contains(val)) {
            tahunOptions.add(val);
          }
        }
      }
    }
    if (tahunOptions.isEmpty) {
      tahunOptions.addAll(['2026/2027', '2025/2026', '2024/2025']);
    }

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          // ──── HEADER KUNING DENGAN LEKUKAN BERSAMBUNG & FLOATING TAHUN PILL ────
          Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              _buildCurvedYellowHeader(),
              Positioned(
                bottom: -18,
                left: 0,
                right: 0,
                child: _buildFloatingTahunPill(context, isDark, tahunOptions),
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
                    child: LoadingView(label: 'Memuat kalender akademik...'),
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
                if (_cachedData == null || _cachedData!.isEmpty) {
                  return const EmptyView(message: 'Data kalender akademik tidak ditemukan');
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
  Widget _buildCurvedYellowHeader() {
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
                          'Kalender Akademik',
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
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            _showActionSheet(_cachedData ?? {});
                          },
                          icon: const Icon(Icons.print_rounded,
                              color: Colors.white, size: 22),
                          tooltip: 'Pilihan Cetak',
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

                // Info Baris Kalender
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
                      child: const Center(
                        child: Icon(Icons.calendar_month_rounded,
                            color: Colors.white, size: 24),
                      ),
                    ),
                    const SizedBox(width: 14),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'UPI YPTK Padang',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
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
                              const Text(
                                'Agenda Resmi Kuliah & Ujian',
                                style: TextStyle(
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
                                  color: Colors.white.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'TA $_tahun',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
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

  // ────────────────────────────────────────────────── FLOATING TAHUN PILL
  Widget _buildFloatingTahunPill(
      BuildContext context, bool isDark, List<String> tahunOptions) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
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
        child: PillDropdown(
          value: tahunOptions.contains(_tahun) ? _tahun : tahunOptions.first,
          hint: 'Pilih Tahun Akademik',
          items: [
            for (final t in tahunOptions)
              DropdownMenuItem<String>(
                value: t,
                child: Text(
                  'Tahun Akademik $t',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (val) {
            if (val != null && val != _tahun) {
              HapticFeedback.selectionClick();
              setState(() {
                _tahun = val;
                _cachedData = null;
              });
              _reload();
            }
          },
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────── BODY
  Widget _buildBody(BuildContext context, Map<String, dynamic> data) {
    final detail = asMap(data['detail_aktif']);
    final metrics = asMap(data['metrics']);
    final catatan = pickString(detail, ['catatan'], '');
    final diperbarui = pickString(detail, ['diperbarui'], '');
    final rawKegiatan = detail['kegiatan'];
    final List<Map<String, dynamic>> allKegiatan = [];
    if (rawKegiatan is List) {
      for (final k in rawKegiatan) {
        if (k is Map) allKegiatan.add(asMap(k));
      }
    }

    // Hitung pembagian semester
    final List<Map<String, dynamic>> ganjilList = [];
    final List<Map<String, dynamic>> genapList = [];
    for (final item in allKegiatan) {
      final grup = pickString(item, ['grup'], '').toLowerCase();
      if (grup.contains('genap')) {
        genapList.add(item);
      } else {
        ganjilList.add(item);
      }
    }

    // Terapkan filter semester
    List<Map<String, dynamic>> filtered = allKegiatan;
    if (_selectedSemester == 'ganjil') {
      filtered = ganjilList;
    } else if (_selectedSemester == 'genap') {
      filtered = genapList;
    }

    // Terapkan pencarian lokal jika query diisi
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((item) {
        final keg = pickString(item, ['kegiatan'], '').toLowerCase();
        final jad = pickString(item, ['jadwal'], '').toLowerCase();
        return keg.contains(q) || jad.contains(q);
      }).toList();
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 104),
      children: [
        // 1. Hero Card: Judul Kalender & Tombol Cetak
        _buildHeroCard(context, detail),
        const SizedBox(height: 14),

        // 2. Kotak Catatan Resmi (jika ada)
        if (catatan.isNotEmpty) ...[
          _buildNoticeBanner(context, catatan, diperbarui),
          const SizedBox(height: 14),
        ],

        // 3. Kartu Metrik Ringkasan
        if (metrics.isNotEmpty) ...[
          _buildMetricsGrid(context, metrics),
          const SizedBox(height: 16),
        ],

        // 4. Search Bar & Filter Semester
        _buildSearchAndFilters(
          context,
          ganjilCount: ganjilList.length,
          genapCount: genapList.length,
          totalCount: allKegiatan.length,
        ),
        const SizedBox(height: 14),

        // 5. Daftar Agenda Kegiatan
        if (filtered.isEmpty) ...[
          _buildNeuCard(
            context: context,
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            child: Column(
              children: [
                Icon(
                  Icons.event_busy_rounded,
                  size: 48,
                  color: context.textMuted.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 12),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'Tidak ditemukan agenda yang sesuai dengan "$_searchQuery".'
                      : 'Belum ada agenda pada semester yang dipilih.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          _buildAgendaGrouped(context, filtered),
        ],

        const SizedBox(height: 20),
      ],
    );
  }

  // ────────────────────────────────────────────────── HERO CARD
  Widget _buildHeroCard(BuildContext context, Map<String, dynamic> detail) {
    final judul = pickString(
      detail,
      ['judul'],
      'Kalender Akademik Universitas TA $_tahun',
    );

    return _buildNeuCard(
      context: context,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.amber, AppColors.upiYellowDeep],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.upiYellowDeep.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.event_available_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'KALENDER AKADEMIK RESMI',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: AppColors.upiYellowDeep,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      judul,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          Divider(height: 1, color: context.border),
          const SizedBox(height: 14),

          // Tombol Cetak Cepat
          Row(
            children: [
              Expanded(
                child: IosBounceTap(
                  onTap: () => _cetakPdfInstan(_cachedData ?? {}),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: _yellowHeaderGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.upiYellowDeep.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bolt_rounded, size: 18, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          'Cetak / Simpan PDF (Instan)',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IosBounceTap(
                onTap: () => _showActionSheet(_cachedData ?? {}),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.border),
                  ),
                  child: Icon(Icons.more_horiz_rounded,
                      size: 20, color: context.textPrimary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────── NOTICE BANNER
  Widget _buildNoticeBanner(
    BuildContext context,
    String catatan,
    String diperbarui,
  ) {
    return _buildNeuCard(
      context: context,
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.info_outline_rounded,
                color: AppColors.upiYellowDeep, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  catatan,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                    height: 1.35,
                  ),
                ),
                if (diperbarui.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    diperbarui,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: context.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────── METRICS GRID
  Widget _buildMetricsGrid(BuildContext context, Map<String, dynamic> metrics) {
    final totalKalender = pickString(metrics, ['total_kalender'], '1 Dokumen');
    final totalKalenderDesc = pickString(metrics, ['total_kalender_desc'], 'Informasi');
    final tahunAkd = pickString(metrics, ['tahun_akademik'], '1 Periode');
    final tahunAkdDesc = pickString(metrics, ['tahun_akademik_desc'], 'Dapat dipilih');
    final pembaruan = pickString(metrics, ['pembaruan_terakhir'], '-');
    final pembaruanDesc = pickString(metrics, ['pembaruan_terakhir_desc'], 'Publikasi');
    final status = pickString(metrics, ['status_informasi'], 'Resmi');
    final statusDesc = pickString(metrics, ['status_informasi_desc'], 'Sistem');

    return Row(
      children: [
        Expanded(
          child: _buildMetricItem(
            context,
            'Dokumen',
            totalKalender,
            totalKalenderDesc,
            Icons.description_rounded,
            AppColors.blue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricItem(
            context,
            'Periode',
            tahunAkd,
            tahunAkdDesc,
            Icons.date_range_rounded,
            AppColors.upiYellowDeep,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricItem(
            context,
            'Pembaruan',
            pembaruan,
            pembaruanDesc,
            Icons.update_rounded,
            AppColors.green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricItem(
            context,
            'Status',
            status,
            statusDesc,
            Icons.verified_rounded,
            AppColors.indigo700,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricItem(
    BuildContext context,
    String label,
    String value,
    String desc,
    IconData icon,
    Color color,
  ) {
    return _buildNeuCard(
      context: context,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontSize: 9.5,
              color: context.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────── SEARCH & FILTERS
  Widget _buildSearchAndFilters(
    BuildContext context, {
    required int ganjilCount,
    required int genapCount,
    required int totalCount,
  }) {
    return Column(
      children: [
        // Search bar
        _buildNeuCard(
          context: context,
          padding: EdgeInsets.zero,
          child: TextField(
            controller: _searchCtrl,
            style: TextStyle(fontSize: 13, color: context.textPrimary),
            decoration: InputDecoration(
              hintText: 'Cari agenda, jadwal, UTS, UAS, Wisuda...',
              hintStyle: TextStyle(fontSize: 12.5, color: context.textMuted),
              prefixIcon: Icon(Icons.search_rounded,
                  size: 20, color: context.textMuted),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () => _searchCtrl.clear(),
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

        // Filter Semester Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(context, 'all', 'Semua Agenda ($totalCount)'),
              const SizedBox(width: 8),
              _buildFilterChip(context, 'ganjil', 'Semester Ganjil ($ganjilCount)'),
              const SizedBox(width: 8),
              _buildFilterChip(context, 'genap', 'Semester Genap ($genapCount)'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(BuildContext context, String key, String label) {
    final isSelected = _selectedSemester == key;
    return IosBounceTap(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedSemester = key);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.upiYellowDeep.withValues(alpha: 0.14)
              : (context.isDark ? const Color(0xFF1C1C1E) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.upiYellowDeep.withValues(alpha: 0.6)
                : context.border,
            width: isSelected ? 1.4 : 1.0,
          ),
          boxShadow: [
            if (!isSelected)
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
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? AppColors.upiYellowDeep : context.textPrimary,
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────── AGENDA GROUPED
  Widget _buildAgendaGrouped(BuildContext context, List<Map<String, dynamic>> items) {
    // Kelompokkan kegiatan berdasarkan grup/semester
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final it in items) {
      final rawGrup = pickString(it, ['grup'], '').trim();
      final grupKey = rawGrup.isEmpty
          ? 'Semester Ganjil'
          : rawGrup.replaceAll('Kalender Akademik UPI-YPTK | ', '');
      grouped.putIfAbsent(grupKey, () => []).add(it);
    }

    return Column(
      children: [
        for (final entry in grouped.entries) ...[
          _buildGroupCard(context, entry.key, entry.value),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildGroupCard(BuildContext context, String groupTitle, List<Map<String, dynamic>> list) {
    return _buildNeuCard(
      context: context,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Judul Semester (gradient emas premium)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: _yellowHeaderGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(Icons.event_note_rounded,
                          color: Colors.white, size: 17),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      groupTitle.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '${list.length} Kegiatan',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // List Items
          for (int i = 0; i < list.length; i++) ...[
            if (i > 0) Divider(height: 1, color: context.border),
            _buildAgendaTile(context, list[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildAgendaTile(BuildContext context, Map<String, dynamic> item) {
    final no = pickString(item, ['no'], '').trim();
    final kegiatan = pickString(item, ['kegiatan'], 'Kegiatan');
    final jadwal = pickString(item, ['jadwal'], '-');

    final isSubItem = no.isEmpty;
    final (iconData, categoryColor) = _getCategoryIconAndColor(kegiatan);

    return IosBounceTap(
      onTap: () {
        Clipboard.setData(ClipboardData(text: '$kegiatan: $jadwal'));
        appToast(context, 'Agenda disalin ke clipboard.');
      },
      child: Container(
        margin: EdgeInsets.only(
          left: isSubItem ? 26 : 10,
          right: 10,
          top: isSubItem ? 3 : 7,
          bottom: isSubItem ? 3 : 7,
        ),
        decoration: BoxDecoration(
          color: context.isDark
              ? const Color(0xFF232327)
              : (isSubItem ? Colors.transparent : const Color(0xFFFDFDFE)),
          borderRadius: BorderRadius.circular(12),
          border: isSubItem
              ? null
              : Border.all(color: context.border, width: 0.8),
          boxShadow: isSubItem
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: context.isDark ? 0.0 : 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: 12,
            right: 12,
            top: isSubItem ? 9 : 11,
            bottom: isSubItem ? 9 : 11,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Accent bar kiri untuk item utama
              if (!isSubItem)
                Container(
                  width: 4,
                  height: 44,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        categoryColor,
                        categoryColor.withValues(alpha: 0.4),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              // Icon kategori atau bullet subitem
              if (!isSubItem) ...[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        categoryColor.withValues(alpha: 0.18),
                        categoryColor.withValues(alpha: 0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: categoryColor.withValues(alpha: 0.25),
                      width: 0.8,
                    ),
                  ),
                  child: Icon(iconData, color: categoryColor, size: 18),
                ),
                const SizedBox(width: 11),
              ] else ...[
                Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.only(top: 6, right: 11),
                  decoration: BoxDecoration(
                    color: context.textMuted.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                ),
              ],

            // Detail Kegiatan & Jadwal
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (no.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(right: 6, top: 1),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: categoryColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            no,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: categoryColor,
                            ),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          kegiatan,
                          style: TextStyle(
                            fontSize: isSubItem ? 11.5 : 12.5,
                            fontWeight: isSubItem ? FontWeight.w500 : FontWeight.w700,
                            color: context.textPrimary,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Jadwal Chip
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: context.isDark
                              ? const Color(0xFF2C2C2E)
                              : AppColors.upiYellowLight.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.schedule_rounded,
                                size: 12, color: AppColors.upiYellowDeep),
                            const SizedBox(width: 5),
                            Text(
                              jadwal,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: context.isDark
                                    ? AppColors.upiYellowBright
                                    : AppColors.upiYellowDeep,
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
      ),
    ),
    );
  }
}
