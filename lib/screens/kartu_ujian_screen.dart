import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../state/periode_provider.dart';
import '../theme/app_theme.dart';
import '../utils/smart.dart';
import '../widgets/async_page.dart';
import '../widgets/common.dart';
import '../widgets/gradient_header.dart';
import '../widgets/periode_dropdown.dart';

/// Kartu Ujian (UTS, UAS, SISKOM) dengan identitas mahasiswa, status cetak,
/// metrik ringkas, pencarian real-time, dan daftar mata kuliah terverifikasi.
class KartuUjianScreen extends StatefulWidget {
  const KartuUjianScreen({super.key});

  @override
  State<KartuUjianScreen> createState() => _KartuUjianScreenState();
}

class _KartuUjianScreenState extends State<KartuUjianScreen> {
  final _pageKey = GlobalKey<AsyncPageState<Map<String, dynamic>>>();
  final TextEditingController _searchCtrl = TextEditingController();
  PeriodeProvider? _pp;
  String _jenis = 'uts'; // uts, uas, siskom
  String? _selectedPeriode;
  List<PeriodeOption> _periodeOpts = [];
  String _searchQuery = '';
  String _filterStatus = 'all'; // all, eligible, ineligible
  bool _isPrinting = false;

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
      _pp!.ensureLoaded().then((_) {
        if (mounted) {
          if (_periodeOpts.isEmpty && _pp!.items.isNotEmpty) {
            _periodeOpts = List.from(_pp!.items);
          }
          _pageKey.currentState?.reload();
        }
      });
    });
  }

  void _onPeriode() {
    if (mounted && _pp != null && _pp!.value != _selectedPeriode) {
      setState(() {
        _selectedPeriode = _pp!.value;
      });
      _pageKey.currentState?.reload();
    }
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

    final resp = await api.get('/api/akademik/kartu-ujian',
        query: {'jenis': _jenis, 'periode': p});
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });

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
      _showPrintInfoDialog(context, defaultMsg, data);
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

      if (isSuccess && url != null && url.startsWith('http')) {
        if (mounted) await openExternal(context, url);
      } else {
        if (mounted) {
          _showPrintInfoDialog(context, msg, data);
        }
      }
    } catch (e) {
      if (mounted) appToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  void _showPrintInfoDialog(
    BuildContext context,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            const SizedBox(height: 12),
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
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AsyncPage<Map<String, dynamic>>(
      key: _pageKey,
      title: 'Kartu Ujian',
      subtitle: 'Kartu rencana dan syarat ujian mahasiswa',
      load: _load,
      headerActions: [
        HeaderActionButton(
          icon: Icons.refresh_rounded,
          tooltip: 'Muat Ulang',
          onPressed: () => _pageKey.currentState?.reload(),
        ),
      ],
      headerExtras: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Segmented Tabs: UTS, UAS, SISKOM
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'uts',
                  label: Text('UTS'),
                  icon: Icon(Icons.edit_note_rounded, size: 16),
                ),
                ButtonSegment(
                  value: 'uas',
                  label: Text('UAS'),
                  icon: Icon(Icons.fact_check_rounded, size: 16),
                ),
                ButtonSegment(
                  value: 'siskom',
                  label: Text('SISKOM'),
                  icon: Icon(Icons.tune_rounded, size: 16),
                ),
              ],
              selected: {_jenis},
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: AppColors.amber,
                selectedForegroundColor: AppColors.indigo950,
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                textStyle:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                padding:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              ),
              onSelectionChanged: (s) {
                setState(() => _jenis = s.first);
                _pageKey.currentState?.reload();
              },
            ),
          ),
          const SizedBox(height: 10),
          // Periode Selector Pill
          PillDropdown(
            value: _periodeOpts.any((o) => o.value == _selectedPeriode)
                ? _selectedPeriode
                : (_periodeOpts.isNotEmpty ? _periodeOpts.first.value : null),
            items: _periodeOpts.isNotEmpty
                ? _periodeOpts
                    .map((o) => DropdownMenuItem(
                          value: o.value,
                          child: Text(o.label,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ))
                    .toList()
                : [
                    DropdownMenuItem(
                      value: _selectedPeriode ?? fallbackPeriode(),
                      child: Text(
                          'Periode ${_selectedPeriode ?? fallbackPeriode()}'),
                    )
                  ],
            onChanged: (v) {
              if (v != null && v != _selectedPeriode) {
                setState(() => _selectedPeriode = v);
                _pageKey.currentState?.reload();
              }
            },
          ),
        ],
      ),
      builder: (context, data) {
        // Ekstrak daftar mata kuliah ujian
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

        return RefreshIndicator(
          onRefresh: () async => _pageKey.currentState?.reload(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Hero Card: Mahasiswa, Preview, Status Cetak
              _buildHeroCard(context, data),
              const SizedBox(height: 14),

              // Metrik Ringkas
              _buildMetricsGrid(context, data),
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
                SurfaceCard(
                  padding:
                      const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
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
                  _UjianCard(item: item),
                  const SizedBox(height: 10),
                ],

              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }

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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
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
          const Divider(height: 1),
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
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (periode.isNotEmpty || periodeTahun.isNotEmpty)
                      Text(
                        [periode, periodeTahun]
                            .where((s) => s.isNotEmpty)
                            .join(' • '),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: context.textMuted,
                        ),
                      ),
                    if (rentangMulai.isNotEmpty ||
                        rentangSelesai.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.date_range_rounded,
                            size: 13,
                            color: AppColors.upiYellowDeep,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '$rentangMulai ${rentangSelesai.isNotEmpty ? "s.d. $rentangSelesai" : ""}',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: context.textMuted,
                              ),
                            ),
                          ),
                        ],
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
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isOpen
                              ? Icons.check_circle_rounded
                              : Icons.lock_clock_rounded,
                          size: 12.5,
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
                          color: statusBadgeColor.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Action Button Cetak
          SizedBox(
            width: double.infinity,
            child: isPrintEnabled
                ? FilledButton.icon(
                    onPressed: _isPrinting ? null : () => _handleCetak(data),
                    icon: _isPrinting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.print_rounded, size: 18),
                    label: Text(
                      _isPrinting ? 'Memproses Cetak...' : printLabel,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.upiYellowDeep,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
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

  Widget _buildMetricsGrid(BuildContext context, Map<String, dynamic> data) {
    final metrics = asMap(data['metrics']);
    final totalSks = pickString(metrics, ['total_sks'], '-');
    final totalSksDesc = pickString(metrics, ['total_sks_desc'], 'Total SKS');
    final totalMk = pickString(metrics, ['mata_kuliah'], '-');
    final totalMkDesc =
        pickString(metrics, ['mata_kuliah_desc'], 'Mata Kuliah');
    final dapat = pickString(metrics, ['dapat_mengikuti'], '-');
    final dapatDesc =
        pickString(metrics, ['dapat_mengikuti_desc'], 'Dapat Mengikuti');
    final tidak = pickString(metrics, ['tidak_mengikuti'], '');
    final tidakDesc =
        pickString(metrics, ['tidak_mengikuti_desc'], 'Tidak Mengikuti');

    return Row(
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
        const SizedBox(width: 8),
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
        if (tidak.isNotEmpty && tidak != 'null') ...[
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
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
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: context.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
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
        Container(
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.border),
          ),
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
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
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
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? activeColor.withValues(alpha: 0.14)
              : context.softFill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? activeColor.withValues(alpha: 0.5)
                : context.border,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? activeColor : context.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _UjianCard extends StatelessWidget {
  const _UjianCard({required this.item});
  final Map<String, dynamic> item;

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

    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: No badge, Title, Status badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (no.isNotEmpty) ...[
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: context.softFill,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.border),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    no,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nama,
                      style: TextStyle(
                        fontSize: 13.5,
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
                          Text(
                            kode,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.upiYellowDeep,
                            ),
                          ),
                        if (sks.isNotEmpty)
                          Text(
                            '• $sks SKS',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: context.textMuted,
                            ),
                          ),
                        if (kelas.isNotEmpty)
                          Text(
                            '• Kelas $kelas',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: context.textMuted,
                            ),
                          ),
                        if (reguler.isNotEmpty)
                          Text(
                            '• $reguler',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: context.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.25)),
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
                    Text(
                      status,
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
          const Divider(height: 1),
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
