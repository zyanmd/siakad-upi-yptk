import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../utils/smart.dart';
import '../utils/transkrip_pdf.dart';
import '../widgets/async_page.dart';
import '../widgets/common.dart';
import '../widgets/gradient_header.dart';
import 'transkrip_cetak_screen.dart';

/// Halaman Transkrip Nilai Akademik Lengkap:
/// Menampilkan rekapitulasi nilai seluruh semester perkuliahan, IPK kumulatif,
/// tren IPS antar semester, distribusi perolehan grade, pencarian & filter,
/// serta fungsi pratinjau lembar cetak resmi A4 dan ekspor PDF.
class TranskripScreen extends StatefulWidget {
  const TranskripScreen({super.key});

  @override
  State<TranskripScreen> createState() => _TranskripScreenState();
}

class _TranskripScreenState extends State<TranskripScreen> {
  final _pageKey = GlobalKey<AsyncPageState<Map<String, dynamic>>>();
  final TextEditingController _searchCtrl = TextEditingController();

  String _searchQuery = '';
  String _selectedSemesterFilter = 'all';
  String _selectedGradeFilter = 'all';
  Map<String, dynamic>? _lastLoadedData;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _load() async {
    final api = context.read<ApiClient>();

    Map<String, dynamic> merged = {};

    // 1. Ambil dari /api/akademik/transkrip/cetak (sumber paling terstruktur & resmi)
    try {
      final cetakResp = await api.get('/api/akademik/transkrip/cetak');
      final cMap = asMap(cetakResp is Map ? (cetakResp['data'] ?? cetakResp) : cetakResp);
      if (cMap.isNotEmpty && cMap['periode'] != null) {
        merged = Map<String, dynamic>.from(cMap);
      }
    } catch (_) {}

    // 2. Ambil dari /api/akademik/transkrip/data untuk melengkapi atau fallback
    try {
      final dataResp = await api.get('/api/akademik/transkrip/data');
      final dMap = asMap(dataResp is Map ? (dataResp['data'] ?? dataResp) : dataResp);
      final inner = asMap(dMap['data']);
      final sInner = asMap(inner['student']);
      final grouped = inner['grouped_periods'];
      final summaryInner = asMap(inner['summary']);

      if (merged.isEmpty && grouped is List && grouped.isNotEmpty) {
        final normalizedPeriods = <Map<String, dynamic>>[];
        int courseNo = 1;

        for (final gp in grouped) {
          if (gp is Map) {
            final gMap = asMap(gp);
            final courses = gMap['courses'];
            final mkList = <Map<String, dynamic>>[];

            if (courses is List) {
              for (final c in courses) {
                if (c is Map) {
                  final cm = asMap(c);
                  mkList.add({
                    'no': '${courseNo++}',
                    'kode': pickString(cm, ['kode_mk'], '-'),
                    'nama': pickString(cm, ['nama_mk'], 'Mata Kuliah'),
                    'nama_en': pickString(cm, ['nama_english'], ''),
                    'sks': pickString(cm, ['sks'], '0'),
                    'grade': pickString(cm, ['grade'], '-'),
                    'bobot': pickString(cm, ['bobot'], '-'),
                    'mutu': pickString(cm, ['mutu'], '-'),
                    'nilai_angka': pickString(cm, ['nilai_akhir'], '-'),
                    'status': cm['lulus'] == true ? 'Lulus' : 'Tidak Lulus',
                  });
                }
              }
            }

            normalizedPeriods.add({
              'periode': pickString(gMap, ['label', 'periode'], 'Periode'),
              'ips': pickString(gMap, ['ips'], '0,00'),
              'jumlah_mata_kuliah': '${mkList.length} Mata Kuliah',
              'total_sks': '${pickString(gMap, ['total_sks'], '0')} SKS',
              'subtotal': {
                'sks': pickString(gMap, ['total_sks'], '0'),
                'mutu': pickString(gMap, ['total_mutu'], '0'),
              },
              'mata_kuliah': mkList,
            });
          }
        }

        merged = {
          'judul': 'TRANSKRIP NILAI AKADEMIK',
          'subjudul': 'Daftar Hasil Studi Mahasiswa Lintas Periode',
          'mahasiswa': {
            'nama': pickString(sInner, ['nama'], ''),
            'nim': pickString(sInner, ['nim'], ''),
            'program_studi': pickString(sInner, ['program_studi'], ''),
            'fakultas': pickString(sInner, ['fakultas'], ''),
            'angkatan': pickString(sInner, ['angkatan'], ''),
            'program': pickString(sInner, ['program'], 'Reguler'),
            'kelas': pickString(sInner, ['kelas'], ''),
            'dosen_pa': pickString(sInner, ['dosen_pa'], ''),
          },
          'periode': normalizedPeriods,
          'summary': {
            'ipk': pickString(summaryInner, ['ipk'], '0,00'),
            'total_sks': '${pickString(summaryInner, ['total_sks', 'passed_sks'], '0')} SKS',
            'total_mata_kuliah': pickString(summaryInner, ['total_courses'], '0'),
            'mengulang': pickString(summaryInner, ['repeated_courses'], '0'),
          },
        };
      } else if (merged.isNotEmpty && sInner.isNotEmpty) {
        // Lengkapi info dosen PA dan kelas jika belum ada di cetak
        final mhs = asMap(merged['mahasiswa']);
        merged['mahasiswa'] = {
          ...mhs,
          if (sInner['dosen_pa'] != null) 'dosen_pa': sInner['dosen_pa'],
          if (sInner['kelas'] != null) 'kelas': sInner['kelas'],
        };
      }
    } catch (_) {}

    _lastLoadedData = merged;
    return merged;
  }

  void _bukaLembarCetak() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const TranskripCetakScreen(),
      ),
    );
  }

  Future<void> _bukaCetakUrl(Map<String, dynamic> data) async {
    try {
      final printUrl = pickString(data, ['url'], '');
      if (printUrl.isNotEmpty && printUrl.startsWith('http')) {
        await openExternal(context, printUrl);
        return;
      }

      final api = context.read<ApiClient>();
      final resp = await api.get('/api/akademik/transkrip/cetak-url');
      final url = deepFind(resp, ['cetak_url', 'url', 'link', 'file'])?.toString();
      if (url == null || !url.startsWith('http')) {
        _bukaLembarCetak();
        return;
      }
      if (mounted) await openExternal(context, url);
    } catch (e) {
      if (mounted) {
        _bukaLembarCetak();
      }
    }
  }

  Future<void> _cetakPdfLangsung(Map<String, dynamic> data) async {
    try {
      final nim = pickString(asMap(data['mahasiswa']), ['nim', 'nobp'], 'UPI');
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async {
          return await TranskripPdfHelper.buildPdf(format, data);
        },
        name: 'Transkrip_Nilai_$nim.pdf',
      );
    } catch (e) {
      if (mounted) {
        appToast(context, 'Gagal mencetak PDF: $e', error: true);
      }
    }
  }

  void _showCetakMenu(Map<String, dynamic> data) {
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
                      color: AppColors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.print_rounded,
                        color: AppColors.upiYellowDeep, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pilihan Cetak Transkrip',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Transkrip Nilai Akademik Kumulatif',
                          style: TextStyle(fontSize: 12, color: AppColors.grey),
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
                    'Render cepat dokumen PDF vektor resmi tanpa menunggu pratinjau lama.',
                    style: TextStyle(fontSize: 11.5)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(ctx);
                  _cetakPdfLangsung(data);
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
                title: const Text('Pratinjau Lembar Cetak Transkrip',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                subtitle: const Text(
                    'Lihat pratinjau kertas & PDF interaktif sebelum mencetak.',
                    style: TextStyle(fontSize: 11.5)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(ctx);
                  _bukaLembarCetak();
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
                title: const Text('Buka Lembar Web SIAKAD',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                subtitle: const Text('Buka halaman transkrip bawaan web kampus.',
                    style: TextStyle(fontSize: 11.5)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(ctx);
                  _bukaCetakUrl(data);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  (String, Color) _evaluasiIpk(double ipk) {
    if (ipk >= 3.51) {
      return ('Dengan Pujian (Cumlaude)', AppColors.green);
    } else if (ipk >= 3.00) {
      return ('Sangat Memuaskan', AppColors.blue);
    } else if (ipk >= 2.76) {
      return ('Memuaskan', AppColors.amber);
    } else if (ipk > 0) {
      return ('Cukup', AppColors.grey);
    }
    return ('Dalam Proses', AppColors.grey);
  }

  @override
  Widget build(BuildContext context) {
    return AsyncPage<Map<String, dynamic>>(
      key: _pageKey,
      title: 'Transkrip Nilai',
      subtitle: 'Rekapitulasi nilai akademik lintas semester',
      load: _load,
      headerActions: [
        HeaderActionButton(
          icon: Icons.print_rounded,
          tooltip: 'Cetak Transkrip',
          onPressed: () {
            _showCetakMenu(_lastLoadedData ?? {});
          },
        ),
        HeaderActionButton(
          icon: Icons.refresh_rounded,
          tooltip: 'Muat Ulang',
          onPressed: () => _pageKey.currentState?.reload(),
        ),
      ],
      builder: (context, data) => _buildBody(context, data),
    );
  }

  Widget _buildBody(BuildContext context, Map<String, dynamic> data) {
    if (data.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          EmptyView(
            icon: Icons.workspace_premium_outlined,
            message: 'Belum ada data transkrip nilai akademik.',
          ),
        ],
      );
    }

    // Ekstrak periode & semua mata kuliah
    final periodList = <Map<String, dynamic>>[];
    final allCourses = <Map<String, dynamic>>[];
    final periodsRaw = data['periode'];

    if (periodsRaw is List) {
      for (final p in periodsRaw) {
        if (p is Map) {
          final pMap = asMap(p);
          periodList.add(pMap);
          final mks = pMap['mata_kuliah'];
          if (mks is List) {
            for (final m in mks) {
              if (m is Map) {
                final cMap = Map<String, dynamic>.from(asMap(m));
                cMap['periode_nama'] = pickString(pMap, ['periode'], '');
                allCourses.add(cMap);
              }
            }
          }
        }
      }
    }

    // Hitung distribusi nilai kumulatif
    final gradeCounts = <String, int>{};
    for (final c in allCourses) {
      final g = pickString(c, ['grade', 'nilai', 'nilai_huruf'], '').toUpperCase().trim();
      final key = g.isEmpty
          ? '-'
          : (g.startsWith('A')
              ? 'A'
              : (g.startsWith('B')
                  ? 'B'
                  : (g.startsWith('C') ? 'C' : 'D/E')));
      gradeCounts[key] = (gradeCounts[key] ?? 0) + 1;
    }

    // Filter daftar
    final q = _searchQuery.toLowerCase().trim();
    final filteredPeriods = <Map<String, dynamic>>[];

    for (final p in periodList) {
      final pNama = pickString(p, ['periode'], '');
      if (_selectedSemesterFilter != 'all' && pNama != _selectedSemesterFilter) {
        continue;
      }

      final mks = p['mata_kuliah'];
      final matchingCourses = <Map<String, dynamic>>[];

      if (mks is List) {
        for (final m in mks) {
          if (m is Map) {
            final mm = asMap(m);
            // Filter grade
            final g = pickString(mm, ['grade', 'nilai', 'nilai_huruf'], '').toUpperCase();
            if (_selectedGradeFilter == 'A' && !g.startsWith('A')) continue;
            if (_selectedGradeFilter == 'B' && !g.startsWith('B')) continue;
            if (_selectedGradeFilter == 'C' && !g.startsWith('C')) continue;
            if (_selectedGradeFilter == 'D/E' && (g.startsWith('A') || g.startsWith('B') || g.startsWith('C'))) {
              continue;
            }

            // Filter search
            if (q.isNotEmpty) {
              final nama = pickString(mm, ['nama', 'nama_mk', 'mata_kuliah']).toLowerCase();
              final kode = pickString(mm, ['kode', 'kode_mk']).toLowerCase();
              if (!nama.contains(q) && !kode.contains(q) && !pNama.toLowerCase().contains(q)) {
                continue;
              }
            }

            matchingCourses.add(mm);
          }
        }
      }

      if (matchingCourses.isNotEmpty || q.isEmpty && _selectedGradeFilter == 'all') {
        final copyP = Map<String, dynamic>.from(p);
        copyP['mata_kuliah'] = matchingCourses;
        filteredPeriods.add(copyP);
      }
    }

    return RefreshIndicator(
      onRefresh: () async => _pageKey.currentState?.reload(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Hero Card: Identitas & Prestasi Kumulatif
          _buildHeroCard(context, data),
          const SizedBox(height: 14),

          // 2. Tren IP Semester (Progress Bar)
          if (periodList.isNotEmpty) ...[
            _buildTrendSection(context, periodList),
            const SizedBox(height: 14),
          ],

          // 3. Rekap Distribusi Nilai Kumulatif
          if (allCourses.isNotEmpty) ...[
            _buildGradeDistribution(context, gradeCounts, allCourses.length),
            const SizedBox(height: 16),
          ],

          // 4. Search & Filter Bar
          _buildSearchAndFilters(
            context,
            periodList: periodList,
            totalCount: allCourses.length,
            gradeCounts: gradeCounts,
          ),
          const SizedBox(height: 14),

          // 5. Daftar Mata Kuliah per Periode
          if (filteredPeriods.isEmpty ||
              filteredPeriods.every((p) => (p['mata_kuliah'] as List).isEmpty)) ...[
            SurfaceCard(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              child: Column(
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: 44,
                    color: context.textMuted.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    allCourses.isEmpty
                        ? 'Belum ada rincian mata kuliah pada transkrip.'
                        : 'Tidak ada mata kuliah yang cocok dengan filter pencarian.',
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
            for (final p in filteredPeriods) ...[
              _buildPeriodCard(context, p),
              const SizedBox(height: 14),
            ],
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context, Map<String, dynamic> data) {
    final mhs = asMap(data['mahasiswa']);
    final nama = pickString(mhs, ['nama'], 'Mahasiswa');
    final nim = pickString(mhs, ['nim', 'nobp'], '-');
    final prodi = pickString(mhs, ['program_studi', 'prodi'], '');
    final fakultas = pickString(mhs, ['fakultas'], '');
    final angkatan = pickString(mhs, ['angkatan'], '');
    final kelas = pickString(mhs, ['kelas', 'program_kelas'], '');
    final dosenPa = pickString(mhs, ['dosen_pa'], '');
    final inisial = nama.isNotEmpty ? nama[0] : 'M';

    final summary = asMap(data['summary']);
    final ipk = pickString(summary, ['ipk'], '-');
    final totalSks = pickString(summary, ['total_sks'], '-');
    final totalMk = pickString(summary, ['total_mata_kuliah'], '-');
    final mengulang = pickString(summary, ['mengulang'], '0');

    final double ipkVal = double.tryParse(ipk.replaceAll(',', '.')) ?? 0.0;
    final (String predikat, Color predikatColor) = _evaluasiIpk(ipkVal);

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
          // Baris Identitas Mahasiswa
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
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
                    fontSize: 22,
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
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        Text(
                          nim,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.upiYellowDeep,
                          ),
                        ),
                        if (prodi.isNotEmpty)
                          Text(
                            '• $prodi',
                            style: TextStyle(fontSize: 12, color: context.textMuted),
                          ),
                        if (angkatan.isNotEmpty)
                          Text(
                            '• Angkatan $angkatan',
                            style: TextStyle(fontSize: 12, color: context.textMuted),
                          ),
                        if (kelas.isNotEmpty)
                          Text(
                            '• Kelas $kelas',
                            style: TextStyle(fontSize: 12, color: context.textMuted),
                          ),
                        if (dosenPa.isNotEmpty)
                          Text(
                            '• PA: $dosenPa',
                            style: TextStyle(fontSize: 12, color: context.textMuted),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // Showcase IPK Kumulatif & Metrik Utama
          Row(
            children: [
              // Box IPK Utama
              Expanded(
                flex: 5,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: predikatColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: predikatColor.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'IPK Kumulatif',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: predikatColor,
                            ),
                          ),
                          Icon(Icons.workspace_premium_rounded,
                              size: 16, color: predikatColor),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ipk,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: predikatColor,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: predikatColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          predikat,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: predikatColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Rincian Metrik Lainnya
              Expanded(
                flex: 6,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricItem(
                            context,
                            icon: Icons.menu_book_rounded,
                            label: 'Total SKS',
                            value: totalSks,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMetricItem(
                            context,
                            icon: Icons.list_alt_rounded,
                            label: 'Mata Kuliah',
                            value: '$totalMk MK',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricItem(
                            context,
                            icon: Icons.replay_rounded,
                            label: 'Mengulang',
                            value: '$mengulang MK',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMetricItem(
                            context,
                            icon: Icons.account_balance_rounded,
                            label: 'Fakultas',
                            value: fakultas.isNotEmpty ? fakultas : 'UPI YPTK',
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
    );
  }

  Widget _buildMetricItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
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
              Icon(icon, size: 12, color: context.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: context.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: context.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTrendSection(
      BuildContext context, List<Map<String, dynamic>> periodList) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.upiYellowDeep.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.trending_up_rounded,
                    size: 16, color: AppColors.upiYellowDeep),
              ),
              const SizedBox(width: 8),
              const Text(
                'Tren IP per Semester',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final p in periodList) ...[
            _buildTrendRow(context, p),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildTrendRow(BuildContext context, Map<String, dynamic> p) {
    final label = pickString(p, ['periode'], '-');
    final ipsStr = pickString(p, ['ips'], '0');
    final sksStr = pickString(p, ['total_sks'], '');
    final val = double.tryParse(ipsStr.replaceAll(',', '.')) ?? 0.0;
    final progress = (val / 4.0).clamp(0.0, 1.0);

    final color = val >= 3.50
        ? AppColors.green
        : (val >= 3.00 ? AppColors.blue : AppColors.amber);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Row(
              children: [
                if (sksStr.isNotEmpty) ...[
                  Text(
                    sksStr,
                    style: TextStyle(fontSize: 11, color: context.textMuted),
                  ),
                  const SizedBox(width: 8),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'IPS $ipsStr',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            backgroundColor: context.softFill,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildGradeDistribution(
      BuildContext context, Map<String, int> counts, int total) {
    final grades = ['A', 'B', 'C', 'D/E'];
    final colors = [
      AppColors.green,
      AppColors.blue,
      AppColors.amber,
      AppColors.red,
    ];

    return SurfaceCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Distribusi Grade Nilai Kumulatif',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
              Text(
                '$total Mata Kuliah',
                style: TextStyle(fontSize: 11.5, color: context.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (int i = 0; i < grades.length; i++) ...[
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    margin: EdgeInsets.only(right: i < grades.length - 1 ? 6 : 0),
                    decoration: BoxDecoration(
                      color: colors[i].withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors[i].withValues(alpha: 0.20)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Grade ${grades[i]}',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: colors[i],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${counts[grades[i]] ?? 0}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: colors[i],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(
    BuildContext context, {
    required List<Map<String, dynamic>> periodList,
    required int totalCount,
    required Map<String, int> gradeCounts,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Input
        Container(
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.border),
          ),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _searchQuery = v),
            style: const TextStyle(fontSize: 13.5),
            decoration: InputDecoration(
              hintText: 'Cari mata kuliah, kode, atau periode...',
              hintStyle: TextStyle(color: context.textMuted, fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded,
                  color: context.textMuted, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 11),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Filter Semester Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                label: 'Semua Semester ($totalCount)',
                selected: _selectedSemesterFilter == 'all',
                onSelected: () => setState(() => _selectedSemesterFilter = 'all'),
              ),
              for (final p in periodList) ...[
                const SizedBox(width: 6),
                _buildFilterChip(
                  label: pickString(p, ['periode'], '-'),
                  selected: _selectedSemesterFilter == pickString(p, ['periode'], ''),
                  onSelected: () => setState(
                      () => _selectedSemesterFilter = pickString(p, ['periode'], '')),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Filter Grade Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                label: 'Semua Grade',
                selected: _selectedGradeFilter == 'all',
                onSelected: () => setState(() => _selectedGradeFilter = 'all'),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                label: 'Grade A (${gradeCounts['A'] ?? 0})',
                selected: _selectedGradeFilter == 'A',
                color: AppColors.green,
                onSelected: () => setState(() => _selectedGradeFilter = 'A'),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                label: 'Grade B (${gradeCounts['B'] ?? 0})',
                selected: _selectedGradeFilter == 'B',
                color: AppColors.blue,
                onSelected: () => setState(() => _selectedGradeFilter = 'B'),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                label: 'Grade C (${gradeCounts['C'] ?? 0})',
                selected: _selectedGradeFilter == 'C',
                color: AppColors.amber,
                onSelected: () => setState(() => _selectedGradeFilter = 'C'),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                label: 'Grade D/E (${gradeCounts['D/E'] ?? 0})',
                selected: _selectedGradeFilter == 'D/E',
                color: AppColors.red,
                onSelected: () => setState(() => _selectedGradeFilter = 'D/E'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
    Color? color,
  }) {
    final activeColor = color ?? AppColors.upiYellowDeep;
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? activeColor.withValues(alpha: 0.15)
              : context.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? activeColor
                : context.border,
            width: selected ? 1.4 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            color: selected ? activeColor : context.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodCard(BuildContext context, Map<String, dynamic> p) {
    final pNama = pickString(p, ['periode'], 'Periode');
    final ips = pickString(p, ['ips'], '-');
    final subtotal = asMap(p['subtotal']);
    final subSks = pickString(subtotal, ['sks'], pickString(p, ['total_sks'], '0'));
    final subMutu = pickString(subtotal, ['mutu'], '0');
    final mks = p['mata_kuliah'] as List;

    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Periode
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.upiYellowDeep.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(bottom: BorderSide(color: context.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pNama,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.upiYellowDeep,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${mks.length} Mata Kuliah • $subSks SKS • Mutu: $subMutu',
                        style: TextStyle(fontSize: 11, color: context.textMuted),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.upiYellowDeep,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'IPS $ips',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Daftar Mata Kuliah
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                for (final item in mks) ...[
                  if (item is Map) ...[
                    _buildCourseItem(context, asMap(item)),
                    const SizedBox(height: 8),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseItem(BuildContext context, Map<String, dynamic> item) {
    final title = pickString(item, ['nama', 'nama_mk', 'mata_kuliah'], 'Mata Kuliah');
    final titleEn = pickString(item, ['nama_en', 'nama_english'], '');
    final kode = pickString(item, ['kode', 'kode_mk'], '');
    final sks = pickString(item, ['sks'], '0');
    final grade = pickString(item, ['grade', 'nilai', 'nilai_huruf'], '-');
    final bobot = pickString(item, ['bobot'], '');
    final mutu = pickString(item, ['mutu'], '');
    final nilaiAngka = pickString(item, ['nilai_angka', 'nilai_akhir'], '');
    final isRepeated = item['is_repeated'] == true;

    Color gradeCol;
    final g = grade.toUpperCase().trim();
    if (g.startsWith('A')) {
      gradeCol = AppColors.green;
    } else if (g.startsWith('B')) {
      gradeCol = AppColors.blue;
    } else if (g.startsWith('C')) {
      gradeCol = AppColors.amber;
    } else if (g.isEmpty || g == '-') {
      gradeCol = AppColors.grey;
    } else {
      gradeCol = AppColors.red;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.softFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Box Grade
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: gradeCol.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: gradeCol.withValues(alpha: 0.25)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  grade.isEmpty ? '-' : grade,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: gradeCol,
                    height: 1.1,
                  ),
                ),
                if (bobot.isNotEmpty && bobot != '-') ...[
                  Text(
                    bobot,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: gradeCol.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Detail Mata Kuliah
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: context.textPrimary,
                          height: 1.25,
                        ),
                      ),
                    ),
                    if (isRepeated)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        margin: const EdgeInsets.only(left: 4),
                        decoration: BoxDecoration(
                          color: AppColors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Ulang (*)',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.orange,
                          ),
                        ),
                      ),
                  ],
                ),
                if (titleEn.isNotEmpty && titleEn != title) ...[
                  const SizedBox(height: 2),
                  Text(
                    titleEn,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontStyle: FontStyle.italic,
                      color: context.textMuted,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (kode.isNotEmpty)
                      Text(
                        kode,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.upiYellowDeep,
                        ),
                      ),
                    Text(
                      '• $sks SKS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.textMuted,
                      ),
                    ),
                    if (nilaiAngka.isNotEmpty && nilaiAngka != '-')
                      Text(
                        '• Nilai $nilaiAngka',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Box Mutu
          if (mutu.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Mutu',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: context.textMuted,
                    ),
                  ),
                  Text(
                    mutu,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
