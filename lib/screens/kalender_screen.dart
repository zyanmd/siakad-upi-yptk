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
import '../widgets/async_page.dart';
import '../widgets/common.dart';
import '../widgets/gradient_header.dart';
import 'kalender_cetak_screen.dart';

/// Halaman Kalender Akademik Resmi Universitas:
/// Menampilkan daftar agenda penting perkuliahan lintas semester (Ganjil/Genap),
/// filter tahun akademik, metrik resmi, pencarian agenda, dan fitur cetak/ekspor PDF.
class KalenderScreen extends StatefulWidget {
  const KalenderScreen({super.key});

  @override
  State<KalenderScreen> createState() => _KalenderScreenState();
}

class _KalenderScreenState extends State<KalenderScreen> {
  final _pageKey = GlobalKey<AsyncPageState<Map<String, dynamic>>>();
  final TextEditingController _searchCtrl = TextEditingController();

  String _tahun = '2026/2027';
  String _searchQuery = '';
  String _selectedSemester = 'all'; // 'all', 'ganjil', 'genap'
  Map<String, dynamic>? _lastLoadedData;
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

    _lastLoadedData = result;
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.event_note_rounded,
                        color: Colors.teal, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pilihan Kalender Akademik',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
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
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.bolt_rounded, color: AppColors.green),
                ),
                title: const Text('Cetak / Simpan PDF (Instan)',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
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
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.description_rounded,
                      color: AppColors.upiYellowDeep),
                ),
                title: const Text('Pratinjau Lembar Cetak Kalender',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
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
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.open_in_browser_rounded,
                      color: AppColors.blue),
                ),
                title: const Text('Buka di Browser SIAKAD',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
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

  @override
  Widget build(BuildContext context) {
    return AsyncPage<Map<String, dynamic>>(
      key: _pageKey,
      title: 'Kalender Akademik',
      subtitle: 'Tahun Akademik $_tahun',
      load: _load,
      headerActions: [
        HeaderActionButton(
          icon: Icons.print_rounded,
          tooltip: 'Pilihan Cetak',
          onPressed: () {
            _showActionSheet(_lastLoadedData ?? {});
          },
        ),
        HeaderActionButton(
          icon: Icons.refresh_rounded,
          tooltip: 'Muat Ulang',
          onPressed: () => _pageKey.currentState?.reload(),
        ),
      ],
      builder: (context, data) {
        final detail = asMap(data['detail_aktif']);
        final filterObj = asMap(data['filter']);
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          children: [
            // 1. Hero Card: Judul Kalender & Dropdown Tahun
            _buildHeroCard(context, detail, tahunOptions),
            const SizedBox(height: 12),

            // 2. Kotak Catatan Resmi (jika ada)
            if (catatan.isNotEmpty) ...[
              _buildNoticeBanner(context, catatan, diperbarui),
              const SizedBox(height: 12),
            ],

            // 3. Kartu Metrik Ringkasan
            if (metrics.isNotEmpty) ...[
              _buildMetricsGrid(context, metrics),
              const SizedBox(height: 14),
            ],

            // 4. Search Bar & Filter Semester
            _buildSearchAndFilters(ganjilList.length, genapList.length, allKegiatan.length),
            const SizedBox(height: 14),

            // 5. Daftar Agenda Kegiatan
            if (filtered.isEmpty) ...[
              const SizedBox(height: 40),
              Center(
                child: EmptyView(
                  icon: Icons.event_busy_rounded,
                  message: _searchQuery.isNotEmpty
                      ? 'Tidak ditemukan agenda yang sesuai dengan "$_searchQuery".'
                      : 'Belum ada agenda pada semester yang dipilih.',
                ),
              ),
              const SizedBox(height: 40),
            ] else ...[
              _buildAgendaGrouped(filtered),
            ],

            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildHeroCard(
    BuildContext context,
    Map<String, dynamic> detail,
    List<String> tahunOptions,
  ) {
    final judul = pickString(
      detail,
      ['judul'],
      'Kalender Akademik Universitas TA $_tahun',
    );

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.upiYellowDeep,
            AppColors.upiYellowDeep.withValues(alpha: 0.88),
            AppColors.indigo900,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.upiYellowDeep.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.calendar_month_rounded,
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
                        letterSpacing: 0.8,
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      judul,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Baris Dropdown Tahun & Tombol Cetak Cepat
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: tahunOptions.contains(_tahun) ? _tahun : tahunOptions.first,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down_rounded,
                          color: AppColors.upiYellowDeep),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1D2430),
                      ),
                      items: [
                        for (final t in tahunOptions)
                          DropdownMenuItem<String>(
                            value: t,
                            child: Text('Tahun Akademik $t'),
                          ),
                      ],
                      onChanged: (val) {
                        if (val != null && val != _tahun) {
                          setState(() => _tahun = val);
                          _pageKey.currentState?.reload();
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: () => _bukaLembarCetak(_lastLoadedData ?? {}),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.upiYellowDeep,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.print_rounded, size: 16),
                label: const Text(
                  'Cetak',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeBanner(
    BuildContext context,
    String catatan,
    String diperbarui,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              color: AppColors.upiYellowDark, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  catatan,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF92400E),
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
                      color: AppColors.upiYellowDark.withValues(alpha: 0.85),
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

  Widget _buildMetricsGrid(BuildContext context, Map<String, dynamic> metrics) {
    final totalKalender = pickString(metrics, ['total_kalender'], '1 Dokumen');
    final totalKalenderDesc = pickString(metrics, ['total_kalender_desc'], 'Informasi tersedia');
    final tahunAkd = pickString(metrics, ['tahun_akademik'], '1 Periode');
    final tahunAkdDesc = pickString(metrics, ['tahun_akademik_desc'], 'Dapat dipilih');
    final pembaruan = pickString(metrics, ['pembaruan_terakhir'], '-');
    final pembaruanDesc = pickString(metrics, ['pembaruan_terakhir_desc'], 'Publikasi terbaru');
    final status = pickString(metrics, ['status_informasi'], 'Resmi');
    final statusDesc = pickString(metrics, ['status_informasi_desc'], 'Sistem akademik');

    return Row(
      children: [
        Expanded(
          child: _buildMetricItem(
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
    String label,
    String value,
    String desc,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1D2430),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 9.5,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(int ganjilCount, int genapCount, int totalCount) {
    return Column(
      children: [
        // Search bar
        TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Cari agenda, jadwal, UTS, UAS, Wisuda...',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () => _searchCtrl.clear(),
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Filter Semester Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('all', 'Semua Agenda ($totalCount)'),
              const SizedBox(width: 8),
              _buildFilterChip('ganjil', 'Semester Ganjil ($ganjilCount)'),
              const SizedBox(width: 8),
              _buildFilterChip('genap', 'Semester Genap ($genapCount)'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedSemester == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedSemester = key),
      selectedColor: AppColors.upiYellowDeep.withValues(alpha: 0.18),
      labelStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? AppColors.upiYellowDeep : const Color(0xFF475569),
      ),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? AppColors.upiYellowDeep : const Color(0xFFE2E8F0),
        ),
      ),
      showCheckmark: false,
    );
  }

  Widget _buildAgendaGrouped(List<Map<String, dynamic>> items) {
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
          _buildGroupCard(entry.key, entry.value),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildGroupCard(String groupTitle, List<Map<String, dynamic>> list) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Judul Semester
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.event_note_rounded,
                        color: Color(0xFF263B62), size: 17),
                    const SizedBox(width: 8),
                    Text(
                      groupTitle.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF263B62),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF263B62).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${list.length} Kegiatan',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF263B62),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // List Items
          for (int i = 0; i < list.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: Color(0xFFF1F5F9)),
            _buildAgendaTile(list[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildAgendaTile(Map<String, dynamic> item) {
    final no = pickString(item, ['no'], '').trim();
    final kegiatan = pickString(item, ['kegiatan'], 'Kegiatan');
    final jadwal = pickString(item, ['jadwal'], '-');

    final isSubItem = no.isEmpty;
    final (iconData, categoryColor) = _getCategoryIconAndColor(kegiatan);

    return InkWell(
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: '$kegiatan: $jadwal'));
        appToast(context, 'Agenda disalin ke clipboard.');
      },
      child: Padding(
        padding: EdgeInsets.only(
          left: isSubItem ? 38 : 14,
          right: 14,
          top: isSubItem ? 8 : 12,
          bottom: isSubItem ? 8 : 12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon kategori atau bullet subitem
            if (!isSubItem) ...[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(iconData, color: categoryColor, size: 18),
              ),
              const SizedBox(width: 12),
            ] else ...[
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(top: 6, right: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFF94A3B8),
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
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            no,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          kegiatan,
                          style: TextStyle(
                            fontSize: isSubItem ? 11.5 : 12.5,
                            fontWeight: isSubItem ? FontWeight.w500 : FontWeight.w700,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),

                  // Jadwal Chip
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.schedule_rounded,
                                size: 12, color: AppColors.upiYellowDeep),
                            const SizedBox(width: 5),
                            Text(
                              jadwal,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155),
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
    );
  }
}
