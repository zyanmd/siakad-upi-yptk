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
import '../widgets/smart_json.dart';
import 'krs_cetak_screen.dart';
import 'krs_pick_sheet.dart';
import 'kurikulum_screen.dart';

const _yellowHeaderGradient = [
  Color(0xFFE5A620), // Bright Academic Gold
  Color(0xFFD48B08), // UPI Yellow
  Color(0xFFB87500), // Deep Academic Gold
];

/// Kartu Rencana Studi: daftar MK diambil, ambil MK baru, hapus, cetak
/// dengan header lengkung emas UPI YPTK dan Neumorphic UI.
class KrsScreen extends StatefulWidget {
  const KrsScreen({super.key});

  @override
  State<KrsScreen> createState() => _KrsScreenState();
}

class _KrsScreenState extends State<KrsScreen> {
  late Future<Map<String, dynamic>> _future;
  Map<String, dynamic>? _cachedData;
  PeriodeProvider? _pp;

  @override
  void initState() {
    super.initState();
    _future = _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pp = context.read<PeriodeProvider>();
      _pp = pp;
      pp.addListener(_onPeriode);
      pp.ensureLoaded().then((_) {
        if (mounted) _reload();
      });
    });
  }

  void _onPeriode() {
    if (mounted) _reload();
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
    final p =
        context.read<PeriodeProvider>().value ?? fallbackPeriode();
    final results = await Future.wait<dynamic>([
      api.get('/api/akademik/krs', query: {'periode': p}),
      api.get('/api/akademik/krs/status'),
    ]);
    return {
      'krs': results[0],
      'status': results[1],
      'periode': p,
    };
  }

  // ------------------------------------------------------------ aksi

  void _cetak() {
    final p = context.read<PeriodeProvider>().value ?? fallbackPeriode();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => KrsCetakScreen(periode: p),
      ),
    );
  }

  Future<void> _openKurikulum() async {
    final p = context.read<PeriodeProvider>().value ?? fallbackPeriode();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => KurikulumScreen(periode: p),
    ));
  }

  Future<void> _hapusItem(Map<String, dynamic> item) async {
    final token = pickString(item, ['delete_token', 'token'], '');
    if (token.isEmpty) {
      appToast(context, 'Token hapus tidak tersedia pada item ini.',
          error: true);
      return;
    }
    final nama = pickString(item,
        ['nama_mk', 'nm_mk', 'mata_kuliah', 'nama'], 'mata kuliah ini');
    final ok = await confirmDialog(
      context,
      'Hapus Mata Kuliah',
      'Yakin ingin menghapus "$nama" dari KRS?',
    );
    if (!ok || !mounted) return;
    try {
      final api = context.read<ApiClient>();
      final resp = await api.delete('/api/akademik/krs/$token');
      final msg = resp is Map
          ? pickString(asMap(resp), ['message'], 'Mata kuliah dihapus.')
          : 'Mata kuliah dihapus.';
      if (!mounted) return;
      appToast(context, msg);
      _reload();
    } catch (e) {
      if (mounted) appToast(context, errorText(e), error: true);
    }
  }

  Future<void> _bukaAmbilMk() async {
    final pp = context.read<PeriodeProvider>();
    final periode = pp.value ?? fallbackPeriode();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => KrsPickSheet(
        periode: periode,
        onAdded: () => _reload(),
      ),
    );
  }

  // ------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = context.isDark;
    final bg = isDark ? const Color(0xFF000000) : const Color(0xFFF9FAFB);

    final krsResp = asMap(_cachedData?['krs']);
    final statusResp = asMap(_cachedData?['status']);
    final krsData = asMap(krsResp['data'] ?? krsResp);
    final statusData = asMap(statusResp['data'] ?? statusResp);

    final totalSks = pickString(krsData, ['total_sks', 'jumlah_sks', 'sks_total'],
        pickString(krsResp, ['total_sks', 'jumlah_sks', 'sks_total'], ''));
    final statusKrs = pickString(krsData, ['status_krs', 'status'],
        pickString(statusData, ['status_krs', 'status'], ''));

    return Scaffold(
      backgroundColor: bg,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.upiYellowDeep,
        foregroundColor: Colors.white,
        elevation: 4,
        onPressed: _bukaAmbilMk,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text('Ambil MK',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
      ),
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
                statusKrs: statusKrs,
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
                    child: LoadingView(label: 'Memuat Kartu Rencana Studi...'),
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
                  return const EmptyView(message: 'Data KRS tidak ditemukan');
                }
                return RefreshIndicator(
                  color: AppColors.upiYellowDeep,
                  backgroundColor:
                      isDark ? const Color(0xFF1E1E22) : Colors.white,
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
    required String statusKrs,
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
                // Baris Atas: Tombol Back + Judul Halaman + Tombol Aksi
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
                          'Kartu Rencana Studi',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ],
                    ),
                    // Action Buttons (Cetak, Kurikulum, Refresh)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IosBounceTap(
                          onTap: _cetak,
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
                        IosBounceTap(
                          onTap: _openKurikulum,
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
                            child: const Icon(Icons.menu_book_rounded,
                                size: 19, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 7),
                        IosBounceTap(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _reload();
                            appToast(context, 'Memuat ulang data KRS...');
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

                // Baris Profil: Lingkaran Inisial (54x54) + Nama & NIM
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
                              if (totalSks.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '$totalSks SKS',
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
        child: const PeriodeSelector(),
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

  Widget _body(BuildContext context, Map<String, dynamic> data) {
    final krsResp = asMap(data['krs']);
    final statusResp = asMap(data['status']);
    final krsData = asMap(krsResp['data'] ?? krsResp);
    final statusData = asMap(statusResp['data'] ?? statusResp);

    List<Map<String, dynamic>> items = [];
    if (krsData['mata_kuliah'] is List) {
      items = (krsData['mata_kuliah'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } else {
      items = findMapList(krsData);
    }

    final totalSks = pickString(krsData, ['total_sks', 'jumlah_sks', 'sks_total'],
        pickString(krsResp, ['total_sks', 'jumlah_sks', 'sks_total'], ''));
    final maksSks = pickString(krsData, ['maks_sks', 'max_sks', 'maksimal_sks'],
        pickString(statusData, ['maks_sks', 'max_sks', 'maksimal_sks'], ''));
    final statusKrs = pickString(krsData, ['status_krs', 'status'],
        pickString(statusData, ['status_krs', 'status'], ''));
    final tglMulai = pickString(krsData, ['tanggal_mulai', 'tgl_mulai'],
        pickString(statusData, ['tanggal_mulai', 'tgl_mulai'], ''));
    final tglSelesai = pickString(krsData, ['tanggal_selesai', 'tgl_selesai'],
        pickString(statusData, ['tanggal_selesai', 'tgl_selesai'], ''));
    final bisaUbah = krsData['bisa_ubah'] == true || statusData['bisa_ubah'] == true;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      children: [
        _statusCard(
          context,
          statusData: statusData,
          totalSks: totalSks,
          maksSks: maksSks,
          statusKrs: statusKrs,
          tglMulai: tglMulai,
          tglSelesai: tglSelesai,
          bisaUbah: bisaUbah,
        ),
        const SizedBox(height: 16),
        SectionTitle(
          'Mata Kuliah Diambil (${items.length})',
          trailing: (items.isNotEmpty && totalSks.isNotEmpty)
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.upiYellowDeep.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '$totalSks SKS',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.upiYellowDeep,
                    ),
                  ),
                )
              : null,
        ),
        const SizedBox(height: 10),
        if (items.isEmpty) ...[
          const SizedBox(height: 24),
          const EmptyView(
            icon: Icons.assignment_outlined,
            message: 'Belum ada mata kuliah di KRS periode ini.\n'
                'Tekan tombol "Ambil MK" untuk menambah.',
          ),
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton.icon(
              onPressed: _bukaAmbilMk,
              icon: const Icon(Icons.add_rounded, color: AppColors.upiYellowDeep),
              label: const Text(
                'Pilih & Tambah Mata Kuliah',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.upiYellowDeep,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.upiYellowDeep, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ),
        ] else ...[
          for (final item in items) ...[
            _KrsItemCard(
              item: item,
              bisaUbah: bisaUbah,
              onDelete: () => _hapusItem(item),
              onTap: () => _openDetailItem(item, data['periode'].toString()),
            ),
            const SizedBox(height: 10),
          ],
        ],
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _statusCard(
    BuildContext context, {
    required Map<String, dynamic> statusData,
    required String totalSks,
    required String maksSks,
    required String statusKrs,
    required String tglMulai,
    required String tglSelesai,
    required bool bisaUbah,
  }) {
    final double? totalVal = double.tryParse(totalSks);
    final double? maksVal = double.tryParse(maksSks);
    final double progress = (totalVal != null && maksVal != null && maksVal > 0)
        ? (totalVal / maksVal).clamp(0.0, 1.0)
        : 0.0;

    final isOpen = statusKrs.toLowerCase() == 'open' || bisaUbah;

    return _buildNeuCard(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE5A620), Color(0xFFB87500)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.upiYellowDeep.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.fact_check_rounded,
                    size: 22, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Status Rencana Studi (KRS)',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isOpen ? 'Periode KRS Aktif' : 'Periode KRS Ditutup',
                      style: TextStyle(
                        fontSize: 12,
                        color: isOpen ? AppColors.green : context.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isOpen
                      ? AppColors.green.withValues(alpha: 0.12)
                      : Colors.grey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isOpen
                        ? AppColors.green.withValues(alpha: 0.3)
                        : Colors.grey.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: isOpen ? AppColors.green : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isOpen ? 'OPEN' : 'CLOSED',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isOpen ? AppColors.green : context.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Tanggal KRS jika ada
          if (tglMulai.isNotEmpty || tglSelesai.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: context.softFill,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded,
                      size: 13, color: AppColors.upiYellowDeep),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Masa KRS: ${tglMulai.isNotEmpty ? tglMulai : '-'} s/d ${tglSelesai.isNotEmpty ? tglSelesai : '-'}',
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

          // Baris progress SKS
          if (totalVal != null || maksVal != null) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Beban SKS Diambil',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: context.textMuted,
                  ),
                ),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: context.textPrimary,
                    ),
                    children: [
                      TextSpan(
                        text: totalSks.isNotEmpty ? totalSks : '0',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.upiYellowDeep,
                          fontSize: 14,
                        ),
                      ),
                      if (maksSks.isNotEmpty) ...[
                        TextSpan(
                          text: ' / $maksSks SKS',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: context.textMuted,
                          ),
                        ),
                      ] else ...[
                        const TextSpan(
                          text: ' SKS',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (maksVal != null && maksVal > 0) ...[
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 7,
                  backgroundColor: context.border,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress >= 1.0 ? AppColors.red : AppColors.upiYellowBright,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(progress * 100).toInt()}% terpakai',
                    style: TextStyle(fontSize: 11, color: context.textMuted),
                  ),
                  if (totalVal != null && maksVal - totalVal >= 0)
                    Text(
                      'Sisa ${(maksVal - totalVal).toInt()} SKS',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.green,
                      ),
                    ),
                ],
              ),
            ],
          ],

          // Informasi tambahan jika ada
          if (statusData.isNotEmpty) ...[
            const SizedBox(height: 8),
            SmartJson(
              data: statusData,
              excludeKeys: const [
                'status',
                'status_krs',
                'sts',
                'kondisi',
                'bisa_ubah',
                'tanggal_mulai',
                'tgl_mulai',
                'tanggal_selesai',
                'tgl_selesai',
                'total_sks',
                'maks_sks',
                'max_sks',
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _openDetailItem(Map<String, dynamic> item, String periode) {
    final token = detailTokenOf(item);
    if (token == null || token.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SmartDetailPage(
        title: 'Jadwal Mata Kuliah',
        initialData: item,
        load: () => context.read<ApiClient>().get(
              '/api/akademik/krs/jadwal/$token',
              query: {'periode': periode},
            ),
      ),
    ));
  }
}

// ==================================================================== item

class _KrsItemCard extends StatelessWidget {
  const _KrsItemCard({
    required this.item,
    required this.onDelete,
    this.bisaUbah = true,
    this.onTap,
  });

  final Map<String, dynamic> item;
  final VoidCallback onDelete;
  final bool bisaUbah;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final title = pickString(item,
        ['nama_mk', 'nm_mk', 'mata_kuliah', 'nama'], 'Mata Kuliah');
    final kode = pickString(item, ['kode', 'kode_mk', 'kd_mk'], '');
    final sks = pickString(item, ['sks'], '');
    final kelas = pickString(item, ['kelas', 'nama_kelas'], '');
    final dosen = pickString(item, ['dosen', 'nama_dosen', 'pengajar'], '');
    final ruang = pickString(item, ['ruang', 'kd_ruang', 'nama_ruang'], '');
    final hari = pickString(item, ['hari', 'hari_kuliah'], '');
    final jam = pickString(item, ['jam', 'jam_kuliah', 'waktu'], '');
    final statusMk = pickString(item, ['status', 'status_mk', 'keterangan'], '');
    final deleteToken = pickString(item, ['delete_token', 'token'], '');
    final detailToken = detailTokenOf(item);

    final hasDelete = deleteToken.isNotEmpty && bisaUbah;
    final hasSchedule = hari.isNotEmpty || jam.isNotEmpty;
    final isDark = context.isDark;

    return IosBounceTap(
      onTap: detailToken != null ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(15),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // SKS Badge UPI Gold
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE5A620), Color(0xFFB87500)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.upiYellowDeep.withValues(alpha: 0.28),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    '${sks.isEmpty ? '-' : sks}\nSKS',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.1,
                    ),
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
                      Row(
                        children: [
                          if (kode.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: AppColors.upiYellowDeep
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                kode,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.upiYellowDeep,
                                ),
                              ),
                            ),
                          if (kode.isNotEmpty && statusMk.isNotEmpty)
                            const SizedBox(width: 6),
                          if (statusMk.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: (statusMk.toLowerCase().contains('batal')
                                        ? AppColors.red
                                        : AppColors.green)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                statusMk,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: statusMk.toLowerCase().contains('batal')
                                      ? AppColors.red
                                      : AppColors.green,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (hasDelete)
                  IosBounceTap(
                    onTap: onDelete,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.red.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        size: 19,
                        color: AppColors.red,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Chips info: Kelas, Jadwal, Ruang, Dosen
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (kelas.isNotEmpty)
                  _mini(context, Icons.groups_rounded, 'Kls: $kelas'),
                if (hasSchedule)
                  _mini(
                    context,
                    Icons.schedule_rounded,
                    hari.isNotEmpty && jam.isNotEmpty ? '$hari, $jam' : '$hari$jam',
                  ),
                if (ruang.isNotEmpty)
                  _mini(context, Icons.meeting_room_outlined, 'R: $ruang'),
                if (dosen.isNotEmpty)
                  _mini(context, Icons.person_outline_rounded, dosen),
              ],
            ),

            if (detailToken != null) ...[
              const SizedBox(height: 10),
              const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Lihat Detail Jadwal',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.upiYellowDeep,
                    ),
                  ),
                  SizedBox(width: 3),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: AppColors.upiYellowDeep,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _mini(BuildContext context, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
      decoration: BoxDecoration(
        color: context.softFill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.5, color: AppColors.upiYellowDeep),
          const SizedBox(width: 4.5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

