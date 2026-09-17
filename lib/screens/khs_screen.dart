import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../utils/smart.dart';
import '../widgets/async_page.dart';
import '../widgets/common.dart';
import '../widgets/gradient_header.dart';
import '../widgets/periode_dropdown.dart';
import 'khs_cetak_screen.dart';

/// Kartu Hasil Studi (KHS) per semester:
/// - Dropdown pilihan semester (ID numerik khas KHS)
/// - Hero card identitas mahasiswa & highlight pencapaian IPS / IPK
/// - Visualisasi distribusi grade nilai
/// - Pencarian real-time & filter grade
/// - Daftar kartu mata kuliah terstruktur
/// - Lembar cetak KHS resmi terintegrasi (native preview & PDF)
class KhsScreen extends StatefulWidget {
  const KhsScreen({super.key});

  @override
  State<KhsScreen> createState() => _KhsScreenState();
}

class _KhsScreenState extends State<KhsScreen> {
  final _pageKey = GlobalKey<AsyncPageState<Map<String, dynamic>>>();
  final TextEditingController _searchCtrl = TextEditingController();

  String? _chosen;
  List<PeriodeOption> _opts = [];
  String _searchQuery = '';
  String _selectedGradeFilter = 'all'; // all, A, B, C, etc.
  Map<String, dynamic>? _lastLoadedData;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _load() async {
    final api = context.read<ApiClient>();

    // 1. Ambil daftar periode KHS
    String? defaultSelectedId;
    try {
      final pl = await api.get('/api/akademik/khs/periode');
      if (pl is Map) {
        final pData = pl['data'] ?? pl;
        final pList = (pData is Map ? pData['periode'] : null) ??
            (pData is List ? pData : null);
        if (pList is List) {
          final customOpts = <PeriodeOption>[];
          for (final item in pList) {
            if (item is Map) {
              final m = asMap(item);
              final id = pickString(m, ['id', 'kode', 'value'], '');
              final label = pickString(m, ['label', 'nama', 'periode'], id);
              if (id.isNotEmpty) {
                customOpts.add(PeriodeOption(value: id, label: label));
                if (m['selected'] == true) {
                  defaultSelectedId = id;
                }
              }
            }
          }
          if (customOpts.isNotEmpty) {
            _opts = customOpts;
          }
        }
      }
      if (_opts.isEmpty) {
        final parsed = parsePeriode(pl);
        if (parsed.isNotEmpty) _opts = parsed;
      }
    } catch (_) {
      // Abaikan jika sudah ada opsi
    }

    _chosen ??=
        defaultSelectedId ?? (_opts.isNotEmpty ? _opts.first.value : null);
    final p = _chosen ?? (_opts.isNotEmpty ? _opts.first.value : null);

    // 2. Ambil data KHS:
    // PENTING: Endpoint biasa /api/akademik/khs sering menghasilkan nilai kosong
    // atau _error_data. Karena itu, utamakan endpoint yang LENGKAP:
    // Prioritas 1: /api/akademik/khs/cetak (data resmi siap tampil: nilai, mutu, bobot, status, signatures, url)
    // Prioritas 2: /api/akademik/khs/data (endpoint AJAX dengan rows & student)
    // Prioritas 3 (Fallback terakhir): /api/akademik/khs
    Map<String, dynamic> khsPayload = {};

    // Prioritas 1: /api/akademik/khs/cetak
    try {
      final cetakResp = await api.get(
        '/api/akademik/khs/cetak',
        query: p != null ? {'periode': p} : null,
      );
      final cMap =
          asMap(cetakResp is Map ? (cetakResp['data'] ?? cetakResp) : cetakResp);
      final mks = cMap['mata_kuliah'];
      if (mks is List && mks.isNotEmpty) {
        khsPayload = cMap;
      }
    } catch (_) {}

    // Prioritas 2: /api/akademik/khs/data
    if (khsPayload.isEmpty ||
        (khsPayload['mata_kuliah'] is! List ||
            (khsPayload['mata_kuliah'] as List).isEmpty)) {
      try {
        final dataResp = await api.get(
          '/api/akademik/khs/data',
          query: p != null ? {'periode': p} : null,
        );
        final dMap =
            asMap(dataResp is Map ? (dataResp['data'] ?? dataResp) : dataResp);
        final innerData = asMap(dMap['data']);
        final rows = innerData['rows'];
        if (rows is List && rows.isNotEmpty) {
          final student = asMap(innerData['student']);
          final summary = asMap(innerData['summary']);
          final periodInfo = asMap(innerData['period']);

          final normalizedMk = <Map<String, dynamic>>[];
          for (int i = 0; i < rows.length; i++) {
            final r = asMap(rows[i]);
            normalizedMk.add({
              'no': (i + 1).toString(),
              'kode': pickString(r, ['kode_mk'], ''),
              'nama': pickString(r, ['nama_mk'], ''),
              'nama_en': pickString(r, ['nama_english'], ''),
              'sks': pickString(r, ['sks'], '0'),
              'nilai_angka': pickString(r, ['nilai_akhir'], '-'),
              'grade': pickString(r, ['grade'], '-'),
              'bobot': pickString(r, ['bobot'], '-'),
              'mutu': pickString(r, ['mutu'], '-'),
              'status': (r['lulus'] == true) ? 'Lulus' : 'Tidak Lulus',
              'semester': pickString(r, ['semester'], ''),
            });
          }

          khsPayload = {
            'judul': 'KARTU HASIL STUDI (KHS)',
            'periode': pickString(periodInfo, ['label', 'periode'], p ?? ''),
            'mahasiswa': {
              'nama': pickString(student, ['nama'], ''),
              'nim': pickString(student, ['nim'], ''),
              'program_studi': pickString(student, ['program_studi'], ''),
              'fakultas': pickString(student, ['fakultas'], ''),
              'program_kelas':
                  '${pickString(student, ['program'], '')} / ${pickString(student, ['kelas'], '')}'
                      .trim(),
              'dosen_pa': pickString(student, ['dosen_pa'], ''),
              'angkatan': pickString(student, ['angkatan'], ''),
            },
            'mata_kuliah': normalizedMk,
            'summary': {
              'ips': pickString(summary, ['ips'], '0,00'),
              'total_sks':
                  pickString(summary, ['total_sks', 'passed_sks'], '0'),
              'total_mutu': pickString(summary, ['total_mutu'], '0'),
            },
            'signatures': [
              if (pickString(student, ['dosen_pa'], '').isNotEmpty)
                {
                  'label': 'Dosen Pembimbing Akademik,',
                  'nama': pickString(student, ['dosen_pa'], ''),
                  'keterangan': 'Dosen Pembimbing Akademik',
                },
              {
                'label': 'Mahasiswa,',
                'nama': pickString(student, ['nama'], ''),
                'keterangan': 'NIM. ${pickString(student, ['nim'], '')}',
              },
            ],
          };
        }
      } catch (_) {}
    }

    // Prioritas 3 (Fallback terakhir): /api/akademik/khs
    if (khsPayload.isEmpty ||
        (khsPayload['mata_kuliah'] is! List ||
            (khsPayload['mata_kuliah'] as List).isEmpty)) {
      try {
        final rawResp = await api.get(
          '/api/akademik/khs',
          query: p != null ? {'periode': p} : null,
        );
        final rMap =
            asMap(rawResp is Map ? (rawResp['data'] ?? rawResp) : rawResp);
        final listCheck = rMap['mata_kuliah'] ?? rMap['nilai'];
        if (listCheck is List && listCheck.isNotEmpty) {
          khsPayload = rMap;
        } else if (khsPayload.isEmpty) {
          khsPayload = rMap;
        }
      } catch (_) {}
    }

    // Ekstrak opsi periode_tersedia jika ada di payload
    if (khsPayload['periode_tersedia'] is List) {
      final list = <PeriodeOption>[];
      for (final e in (khsPayload['periode_tersedia'] as List)) {
        if (e is Map) {
          final m = asMap(e);
          final id = pickString(m, ['id', 'kode', 'value'], '');
          final label = pickString(m, ['label', 'nama', 'periode'], id);
          if (id.isNotEmpty) {
            list.add(PeriodeOption(value: id, label: label));
          }
        }
      }
      if (list.isNotEmpty && _opts.isEmpty) {
        _opts = list;
      }
    }

    // Pastikan dropdown di header ikut ter-refresh
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });

    final res = {'opts': _opts, 'data': khsPayload, 'periode': p};
    _lastLoadedData = khsPayload;
    return res;
  }

  void _bukaLembarCetak() {
    final p = _chosen ?? (_opts.isNotEmpty ? _opts.first.value : '');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => KhsCetakScreen(periode: p),
      ),
    );
  }

  Future<void> _bukaCetakUrl(Map<String, dynamic> data) async {
    try {
      final p = _chosen;
      final printUrl = pickString(data, ['print_url', 'url'], '');
      if (printUrl.isNotEmpty && printUrl.startsWith('http')) {
        await openExternal(context, printUrl);
        return;
      }

      if (p == null) throw ApiException('Periode belum dipilih.');
      final api = context.read<ApiClient>();
      final resp =
          await api.get('/api/akademik/khs/cetak-url', query: {'periode': p});
      final url =
          deepFind(resp, ['cetak_url', 'url', 'link', 'file'])?.toString();
      if (url == null || !url.startsWith('http')) {
        // Fallback: buka halaman cetak internal
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pilihan Cetak KHS',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Periode ${_chosen ?? '-'}',
                          style: TextStyle(fontSize: 12, color: ctx.textMuted),
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
                    color: AppColors.upiYellowDeep.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.description_rounded,
                      color: AppColors.upiYellowDeep),
                ),
                title: const Text('Pratinjau Lembar Cetak Resmi KHS',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                subtitle: const Text(
                    'Tampilan kertas resmi universitas siap cetak PDF langsung.',
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
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                subtitle: const Text('Buka halaman cetak bawaan web kampus.',
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

  @override
  Widget build(BuildContext context) {
    return AsyncPage<Map<String, dynamic>>(
      key: _pageKey,
      title: 'Kartu Hasil Studi',
      subtitle: 'Nilai dan prestasi akademik per semester',
      load: _load,
      headerActions: [
        HeaderActionButton(
          icon: Icons.print_rounded,
          tooltip: 'Cetak KHS',
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
      headerExtras: PillDropdown(
        value: _opts.any((o) => o.value == _chosen)
            ? _chosen
            : (_opts.isNotEmpty ? _opts.first.value : null),
        hint: 'Pilih Semester',
        items: [
          for (final o in _opts)
            DropdownMenuItem<String>(
              value: o.value,
              child: Text(
                o.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (v) {
          if (v == null || v == _chosen) return;
          setState(() {
            _chosen = v;
            _searchQuery = '';
            _selectedGradeFilter = 'all';
          });
          _pageKey.currentState?.reload();
        },
      ),
      builder: (context, data) => _buildContent(context, data),
    );
  }

  Widget _buildContent(BuildContext context, Map<String, dynamic> payload) {
    final data = asMap(payload['data']);
    if (data.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          EmptyView(
            icon: Icons.grade_outlined,
            message: 'Belum ada data KHS untuk semester ini.',
          ),
        ],
      );
    }

    // Ekstrak daftar nilai
    final rawList = <Map<String, dynamic>>[];
    final listSource = data['mata_kuliah'] ?? data['nilai'];
    if (listSource is List) {
      for (final it in listSource) {
        if (it is Map) rawList.add(asMap(it));
      }
    }

    // Hitung distribusi nilai
    final gradeCounts = <String, int>{};
    for (final item in rawList) {
      final g = pickString(item, ['grade', 'nilai', 'nilai_huruf'], '')
          .toUpperCase()
          .trim();
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
    final filteredList = rawList.where((it) {
      // Grade filter
      final g = pickString(it, ['grade', 'nilai', 'nilai_huruf'], '')
          .toUpperCase();
      if (_selectedGradeFilter == 'A' && !g.startsWith('A')) return false;
      if (_selectedGradeFilter == 'B' && !g.startsWith('B')) return false;
      if (_selectedGradeFilter == 'C' && !g.startsWith('C')) return false;
      if (_selectedGradeFilter == 'D/E' &&
          (g.startsWith('A') || g.startsWith('B') || g.startsWith('C'))) {
        return false;
      }

      // Search query
      if (q.isEmpty) return true;
      final nama = pickString(
              it, ['nama', 'nama_mk', 'matkul', 'mata_kuliah'])
          .toLowerCase();
      final kode = pickString(it, ['kode', 'kode_mk', 'kd_mk']).toLowerCase();
      final dosen = pickString(it, ['dosen', 'nama_dosen']).toLowerCase();
      final kelas = pickString(it, ['kelas', 'nama_kelas']).toLowerCase();
      return nama.contains(q) ||
          kode.contains(q) ||
          dosen.contains(q) ||
          kelas.contains(q);
    }).toList();

    return RefreshIndicator(
      onRefresh: () async => _pageKey.currentState?.reload(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Hero Card: Identitas Mahasiswa & Pencapaian Indeks Prestasi
          _buildHeroCard(context, data),
          const SizedBox(height: 14),

          // 2. Visualisasi Distribusi Grade Nilai
          if (rawList.isNotEmpty) ...[
            _buildGradeDistribution(context, gradeCounts, rawList.length),
            const SizedBox(height: 16),
          ],

          // 3. Search Bar & Filter Chips
          _buildSearchAndFilters(
            context,
            totalCount: rawList.length,
            gradeCounts: gradeCounts,
          ),
          const SizedBox(height: 14),

          // 4. Daftar Mata Kuliah & Nilai
          if (filteredList.isEmpty)
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
                    rawList.isEmpty
                        ? 'Belum ada rincian nilai mata kuliah untuk semester ini.'
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
              _NilaiCard(item: item),
              const SizedBox(height: 10),
            ],

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context, Map<String, dynamic> data) {
    final mhs = asMap(data['mahasiswa']);
    final nama = pickString(mhs, ['nama'], 'Mahasiswa');
    final nim = pickString(mhs, ['nim', 'nobp'], '-');
    final prodi = pickString(mhs, ['program_studi', 'prodi'], '');
    final kelas = pickString(mhs, ['program_kelas', 'kelas'], '');
    final inisial = nama.isNotEmpty ? nama[0] : 'M';

    String dosenPa = pickString(mhs, ['dosen_pa', 'pembimbing_akademik'], '');
    if (dosenPa.isEmpty && data['signatures'] is List) {
      for (final s in (data['signatures'] as List)) {
        if (s is Map) {
          final sm = asMap(s);
          final jab = pickString(sm, ['jabatan', 'label', 'keterangan'], '')
              .toLowerCase();
          final nm = pickString(sm, ['nama'], '');
          if (jab.contains('dosen') ||
              jab.contains('pembimbing') ||
              jab.contains('pa')) {
            if (nm.isNotEmpty) dosenPa = nm;
          }
        }
      }
    }

    final summary = asMap(data['summary']);
    final total = asMap(data['total']);
    final ips = pickString(summary, ['ips', 'ip'], '-');
    final ipk = pickString(summary, ['ipk'], '-');
    final totalSks = pickString(
        total, ['sks'], pickString(summary, ['total_sks', 'sks', 'passed_sks'], '-'));
    final totalMutu = pickString(
        total, ['mutu'], pickString(summary, ['total_mutu'], '-'));
    final maksSks = pickString(summary, ['maks_sks'], '');

    final double ipsVal = double.tryParse(ips.replaceAll(',', '.')) ?? 0.0;
    final (String predikat, Color predikatColor) = _evaluasiIps(ipsVal);

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
                width: 46,
                height: 46,
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
                    fontSize: 20,
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
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textMuted,
                            ),
                          ),
                        if (kelas.isNotEmpty)
                          Text(
                            '• $kelas',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textMuted,
                            ),
                          ),
                        if (dosenPa.isNotEmpty)
                          Text(
                            '• PA: $dosenPa',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textMuted,
                            ),
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

          // Showcase Pencapaian: IPS & IPK Utama
          Row(
            children: [
              // Box IPS Utama
              Expanded(
                flex: 5,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: predikatColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: predikatColor.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'IP Semester (IPS)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: predikatColor,
                            ),
                          ),
                          Icon(Icons.trending_up_rounded,
                              size: 16, color: predikatColor),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ips,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: predikatColor,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
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
                    _subMetricRow('IPK Kumulatif', ipk, Icons.school_rounded,
                        AppColors.indigo500),
                    const SizedBox(height: 6),
                    _subMetricRow('Total SKS', '$totalSks SKS',
                        Icons.grid_view_rounded, AppColors.green),
                    const SizedBox(height: 6),
                    _subMetricRow('Total Mutu', totalMutu,
                        Icons.auto_awesome_rounded, AppColors.orange),
                  ],
                ),
              ),
            ],
          ),

          if (maksSks.isNotEmpty && maksSks != '0') ...[
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: context.softFill,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 13, color: AppColors.upiYellowDeep),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Maksimal beban semester depan: $maksSks SKS',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Tombol Aksi Cepat Cetak KHS
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _bukaLembarCetak,
                  icon: const Icon(Icons.description_rounded, size: 16),
                  label: const Text(
                    'Lihat Lembar Cetak KHS',
                    style:
                        TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.upiYellowDeep,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _showCetakMenu(data),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  side: BorderSide(color: context.border),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Icon(Icons.more_horiz_rounded, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _subMetricRow(
      String label, String val, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.softFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: context.textMuted),
            ),
          ),
          Text(
            val,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: context.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  (String, Color) _evaluasiIps(double ips) {
    if (ips >= 3.51) return ('Dengan Pujian', AppColors.green);
    if (ips >= 3.00) return ('Sangat Memuaskan', const Color(0xFF0D9488));
    if (ips >= 2.76) return ('Memuaskan', AppColors.blue);
    if (ips >= 2.00) return ('Cukup', AppColors.amber);
    return ('Perlu Peningkatan', AppColors.red);
  }

  Widget _buildGradeDistribution(
    BuildContext context,
    Map<String, int> counts,
    int total,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Distribusi Nilai',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                ),
              ),
              Text(
                '$total Mata Kuliah',
                style: TextStyle(fontSize: 11, color: context.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _gradePill('Grade A', counts['A'] ?? 0, AppColors.green),
              const SizedBox(width: 8),
              _gradePill('Grade B', counts['B'] ?? 0, AppColors.blue),
              const SizedBox(width: 8),
              _gradePill('Grade C', counts['C'] ?? 0, AppColors.amber),
              if ((counts['D/E'] ?? 0) > 0) ...[
                const SizedBox(width: 8),
                _gradePill('Grade D/E', counts['D/E'] ?? 0, AppColors.red),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _gradePill(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(
              '$count MK',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w800, color: color),
            ),
            Text(
              label,
              style: TextStyle(
                  fontSize: 9.5, color: color.withValues(alpha: 0.8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters(
    BuildContext context, {
    required int totalCount,
    required Map<String, int> gradeCounts,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search bar
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

        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _filterChip(
                label: 'Semua ($totalCount)',
                selected: _selectedGradeFilter == 'all',
                onSelected: () =>
                    setState(() => _selectedGradeFilter = 'all'),
              ),
              const SizedBox(width: 8),
              _filterChip(
                label: 'Grade A (${gradeCounts['A'] ?? 0})',
                selected: _selectedGradeFilter == 'A',
                activeColor: AppColors.green,
                onSelected: () => setState(() => _selectedGradeFilter = 'A'),
              ),
              const SizedBox(width: 8),
              _filterChip(
                label: 'Grade B (${gradeCounts['B'] ?? 0})',
                selected: _selectedGradeFilter == 'B',
                activeColor: AppColors.blue,
                onSelected: () => setState(() => _selectedGradeFilter = 'B'),
              ),
              if ((gradeCounts['C'] ?? 0) > 0) ...[
                const SizedBox(width: 8),
                _filterChip(
                  label: 'Grade C (${gradeCounts['C'] ?? 0})',
                  selected: _selectedGradeFilter == 'C',
                  activeColor: AppColors.amber,
                  onSelected: () =>
                      setState(() => _selectedGradeFilter = 'C'),
                ),
              ],
              if ((gradeCounts['D/E'] ?? 0) > 0) ...[
                const SizedBox(width: 8),
                _filterChip(
                  label: 'Grade D/E (${gradeCounts['D/E'] ?? 0})',
                  selected: _selectedGradeFilter == 'D/E',
                  activeColor: AppColors.red,
                  onSelected: () =>
                      setState(() => _selectedGradeFilter = 'D/E'),
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

// ==================================================================== Kartu Nilai

class _NilaiCard extends StatelessWidget {
  const _NilaiCard({required this.item});
  final Map<String, dynamic> item;

  Color _gradeColor(String grade) {
    final g = grade.toUpperCase().trim();
    if (g.startsWith('A')) return AppColors.green;
    if (g.startsWith('B')) return AppColors.blue;
    if (g.startsWith('C')) return AppColors.amber;
    if (g.isEmpty || g == '-') return AppColors.grey;
    return AppColors.red;
  }

  @override
  Widget build(BuildContext context) {
    final title = pickString(
      item,
      ['nama_mk', 'nm_mk', 'mata_kuliah', 'nama'],
      'Mata Kuliah',
    );
    final titleEn = pickString(item, ['nama_en', 'nama_english'], '');
    final kode = pickString(item, ['kode', 'kode_mk', 'kd_mk'], '');
    final sks = pickString(item, ['sks'], '0');
    final grade = pickString(item, ['grade', 'nilai', 'nilai_huruf'], '-');
    final bobot = pickString(item, ['bobot', 'angka'], '');
    final nilaiAngka =
        pickString(item, ['nilai_angka', 'nilai_akhir'], '');
    final mutu = pickString(item, ['mutu', 'total_mutu'], '');
    final status = pickString(item, ['status', 'status_nilai'], '');
    final dosen = pickString(item, ['dosen', 'nama_dosen'], '');
    final kelas = pickString(item, ['kelas', 'nama_kelas'], '');

    final gradeCol = _gradeColor(grade);

    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Box Grade & Bobot
          Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: gradeCol.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: gradeCol.withValues(alpha: 0.25)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  grade.isEmpty ? '-' : grade,
                  style: TextStyle(
                    fontSize: 18,
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
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary,
                    height: 1.25,
                  ),
                ),
                if (titleEn.isNotEmpty && titleEn != title) ...[
                  const SizedBox(height: 2),
                  Text(
                    titleEn,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: context.textMuted,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
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
                    Text(
                      '• $sks SKS',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: context.textMuted,
                      ),
                    ),
                    if (nilaiAngka.isNotEmpty && nilaiAngka != '-')
                      Text(
                        '• Nilai $nilaiAngka',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimary,
                        ),
                      ),
                    if (kelas.isNotEmpty)
                      Text(
                        '• Kelas $kelas',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: context.textMuted,
                        ),
                      ),
                    if (status.isNotEmpty &&
                        status.toLowerCase().contains('lulus'))
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppColors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Lulus',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.green,
                          ),
                        ),
                      ),
                  ],
                ),
                if (dosen.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.person_outline_rounded,
                          size: 13, color: context.textMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          dosen,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
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

          // Mutu Badge
          if (mutu.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: context.softFill,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Mutu',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: context.textMuted,
                    ),
                  ),
                  Text(
                    mutu,
                    style: TextStyle(
                      fontSize: 12,
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
