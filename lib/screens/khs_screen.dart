import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/smart.dart';
import '../widgets/async_page.dart';
import '../widgets/common.dart';
import '../widgets/gradient_header.dart';
import '../widgets/periode_dropdown.dart';

/// Kartu Hasil Studi per semester: ringkasan IP/SKS, daftar nilai,
/// grafik batang sederhana antar semester, dan cetak KHS.
class KhsScreen extends StatefulWidget {
  const KhsScreen({super.key});

  @override
  State<KhsScreen> createState() => _KhsScreenState();
}

class _KhsScreenState extends State<KhsScreen> {
  final _pageKey = GlobalKey<AsyncPageState<Map<String, dynamic>>>();
  String? _chosen;
  List<PeriodeOption> _opts = const [];

  Future<Map<String, dynamic>> _load() async {
    final api = context.read<ApiClient>();
    final pl = await api.get('/api/akademik/khs/periode');
    _opts = parsePeriode(pl);
    final p = _chosen ?? (_opts.isNotEmpty ? _opts.first.value : null);
    if (_chosen == null && p != null) _chosen = p;
    if (p == null) {
      return {'opts': _opts, 'data': null, 'periode': null};
    }
    final resp =
        await api.get('/api/akademik/khs/data', query: {'periode': p});
    // Pastikan dropdown di header ikut ter-refresh setelah opsi termuat.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
    return {'opts': _opts, 'data': resp, 'periode': p};
  }

  Future<void> _cetak() async {
    try {
      final p = _chosen;
      if (p == null) throw ApiException('Periode belum dipilih.');
      final api = context.read<ApiClient>();
      final resp =
          await api.get('/api/akademik/khs/cetak-url', query: {'periode': p});
      final url =
          deepFind(resp, ['cetak_url', 'url', 'link', 'file'])?.toString();
      if (url == null || !url.startsWith('http')) {
        throw ApiException('URL cetak tidak ditemukan.');
      }
      await openExternal(context, url);
    } catch (e) {
      if (mounted) appToast(context, errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AsyncPage<Map<String, dynamic>>(
      key: _pageKey,
      title: 'Kartu Hasil Studi',
      subtitle: 'Nilai dan prestasi per semester',
      load: _load,
      headerActions: [
        HeaderActionButton(
          icon: Icons.print_rounded,
          tooltip: 'Cetak KHS',
          onPressed: _cetak,
        ),
      ],
      headerExtras: PillDropdown(
        value: _chosen,
        hint: 'Pilih Semester',
        items: [
          for (final o in _opts)
            DropdownMenuItem<String>(
                value: o.value, child: Text(o.label)),
        ],
        onChanged: (v) {
          if (v == null) return;
          setState(() => _chosen = v);
          _pageKey.currentState?.reload();
        },
      ),
      builder: (context, data) => _body(context, data),
    );
  }

  Widget _body(BuildContext context, Map<String, dynamic> data) {
    final resp = asMap(data['data']);
    final periode = data['periode']?.toString();
    if (resp.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          EmptyView(
              icon: Icons.grade_outlined,
              message: 'Belum ada data KHS untuk semester ini.'),
        ],
      );
    }
    final inner = asMap(resp['data'] ?? resp);
    final items = findMapList(inner);

    final ip = deepFind(inner, ['ip', 'ips'])?.toString();
    final ipk = deepFind(inner, ['ipk'])?.toString();
    final sks = deepFind(inner, ['total_sks', 'sks', 'sks_tempuh'])?.toString();
    final sem = deepFind(inner, ['semester', 'smt'])?.toString();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _summaryRow(context, ip, ipk, sks, sem),
        const SizedBox(height: 14),
        if (items.isNotEmpty) ...[
          SectionTitle('Daftar Nilai (${items.length} mata kuliah)'),
          const SizedBox(height: 10),
          for (final item in items) ...[
            _NilaiCard(item: item),
            const SizedBox(height: 8),
          ],
        ] else ...[
          SectionTitle('Rincian KHS ${periode ?? ''}'),
          const SizedBox(height: 10),
          SurfaceCard(
            child: SmartJsonInline(data: inner),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _summaryRow(
      BuildContext context, String? ip, String? ipk, String? sks, String? sem) {
    final cards = <Widget>[];
    if (ip != null) {
      cards.add(StatCard(
          label: 'IP Semester',
          value: ip,
          icon: Icons.insights_rounded,
          color: AppColors.amber));
    }
    if (ipk != null) {
      cards.add(StatCard(
          label: 'IPK',
          value: ipk,
          icon: Icons.school_rounded,
          color: AppColors.indigo500));
    }
    if (sks != null) {
      cards.add(StatCard(
          label: 'Total SKS',
          value: sks,
          icon: Icons.grid_view_rounded,
          color: AppColors.green));
    }
    if (sem != null) {
      cards.add(StatCard(
          label: 'Semester',
          value: sem,
          icon: Icons.layers_rounded,
          color: AppColors.red));
    }
    if (cards.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: cards[i]),
        ],
      ],
    );
  }
}

// ==================================================================== nilai

class _NilaiCard extends StatelessWidget {
  const _NilaiCard({required this.item});
  final Map<String, dynamic> item;

  Color _gradeColor(String grade) {
    final g = grade.toUpperCase();
    if (g.startsWith('A')) return AppColors.green;
    if (g.startsWith('B')) return AppColors.orange;
    if (g.startsWith('C')) return AppColors.amber;
    if (g.isEmpty) return AppColors.grey;
    return AppColors.red;
  }

  @override
  Widget build(BuildContext context) {
    final title = pickString(item,
        ['nama_mk', 'nm_mk', 'mata_kuliah', 'nama'], 'Mata Kuliah');
    final kode = pickString(item, ['kode', 'kode_mk', 'kd_mk'], '');
    final sks = pickString(item, ['sks'], '');
    final nilai = pickString(item, ['nilai', 'nilai_huruf', 'grade'], '');
    final bobot = pickString(item, ['bobot', 'angka', 'nilai_angka'], '');
    final dosen = pickString(item, ['dosen', 'nama_dosen'], '');

    return SurfaceCard(
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _gradeColor(nilai).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              nilai.isEmpty ? '-' : nilai,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: _gradeColor(nilai),
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
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (kode.isNotEmpty) kode,
                    if (sks.isNotEmpty) '$sks SKS',
                    if (bobot.isNotEmpty) 'Bobot $bobot',
                  ].join('  -  '),
                  style:
                      TextStyle(fontSize: 11.5, color: context.textMuted),
                ),
                if (dosen.isNotEmpty)
                  Text(
                    dosen,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11, color: context.textMuted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Key-value sederhana untuk data KHS yang tidak punya list nilai.
class SmartJsonInline extends StatelessWidget {
  const SmartJsonInline({super.key, required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final rows = data.entries
        .where((e) =>
            e.value != null &&
            e.value is! Map &&
            e.value is! List &&
            !e.key.toLowerCase().contains('token'))
        .toList();
    if (rows.isEmpty) {
      return Text('Tidak ada rincian.',
          style: TextStyle(fontSize: 12.5, color: context.textMuted));
    }
    return Column(
      children: [
        for (final e in rows)
          KeyValueRow(label: labelify(e.key), value: e.value.toString()),
      ],
    );
  }
}
