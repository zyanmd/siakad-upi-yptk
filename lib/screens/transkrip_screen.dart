import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/smart.dart';
import '../widgets/async_page.dart';
import '../widgets/common.dart';
import '../widgets/gradient_header.dart';

/// Transkrip nilai keseluruhan: ringkasan IPK/SKS, tren IP antar
/// semester, daftar mata kuliah, dan cetak transkrip.
class TranskripScreen extends StatefulWidget {
  const TranskripScreen({super.key});

  @override
  State<TranskripScreen> createState() => _TranskripScreenState();
}

class _TranskripScreenState extends State<TranskripScreen> {
  Future<Map<String, dynamic>> _load() async {
    final api = context.read<ApiClient>();
    final resp = await api.get('/api/akademik/transkrip/data');
    final data = resp is Map ? (resp['data'] ?? resp) : resp;
    return asMap(data);
  }

  Future<void> _cetak() async {
    try {
      final api = context.read<ApiClient>();
      final resp = await api.get('/api/akademik/transkrip/cetak-url');
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
      title: 'Transkrip Nilai',
      subtitle: 'Rekap nilai selama perkuliahan',
      load: _load,
      headerActions: [
        HeaderActionButton(
          icon: Icons.print_rounded,
          tooltip: 'Cetak Transkrip',
          onPressed: _cetak,
        ),
      ],
      builder: (context, data) => _body(context, data),
    );
  }

  Widget _body(BuildContext context, Map<String, dynamic> data) {
    if (data.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          EmptyView(
              icon: Icons.workspace_premium_outlined,
              message: 'Belum ada data transkrip.'),
        ],
      );
    }

    final ipk = deepFind(data, ['ipk'])?.toString();
    final totalSks = deepFind(
        data, ['total_sks', 'sks_total', 'jumlah_sks'])?.toString();
    final sksLulus =
        deepFind(data, ['sks_lulus', 'sks_diperoleh'])?.toString();
    final items = findMapList(data);
    final hasCourses = items.any((m) =>
        pickString(m, ['nama_mk', 'nm_mk', 'mata_kuliah'], '')
            .isNotEmpty);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _bigSummary(context, ipk, totalSks, sksLulus),
        const SizedBox(height: 14),
        _trendSection(context, data),
        const SizedBox(height: 14),
        if (hasCourses) ...[
          SectionTitle('Daftar Nilai (${items.length})'),
          const SizedBox(height: 10),
          for (final item in items) ...[
            _courseTile(context, item),
            const SizedBox(height: 8),
          ],
        ] else ...[
          SectionTitle('Rincian Transkrip'),
          const SizedBox(height: 10),
          SurfaceCard(
            child: SmartJsonTranskrip(data: data),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _bigSummary(
      BuildContext context, String? ipk, String? totalSks, String? sksLulus) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.indigo900, AppColors.indigo500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('IPK Keseluruhan',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.72), fontSize: 12)),
              const SizedBox(height: 4),
              Text(
                ipk ?? '-',
                style: const TextStyle(
                  color: AppColors.amberLight,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _pill('Total SKS', totalSks ?? '-'),
              const SizedBox(height: 7),
              _pill('SKS Lulus', sksLulus ?? '-'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.7), fontSize: 10.5)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  /// Cari riwayat per semester (semester + ip) lalu render bar sederhana.
  Widget _trendSection(BuildContext context, Map<String, dynamic> data) {
    final history = deepFindMapList(data, [
      'riwayat_semester', 'per_semester', 'riwayat', 'semester_list', 'history'
    ]);
    if (history.isEmpty) return const SizedBox.shrink();

    final points = <(String, double)>[];
    for (final m in history) {
      final label = pickString(m, ['semester', 'smt', 'periode', 'nama'], '');
      final ipRaw = pickString(m, ['ip', 'ips', 'ipk'], '');
      final v = double.tryParse(ipRaw.replaceAll(RegExp(r'[^0-9.]'), ''));
      if (label.isNotEmpty && v != null && v > 0) {
        points.add((label, v));
      }
    }
    if (points.isEmpty) return const SizedBox.shrink();

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.trending_up_rounded,
                  size: 17, color: AppColors.orange),
              SizedBox(width: 7),
              Text('Tren IP per Semester',
                  style:
                      TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 14),
          for (final p in points)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 86,
                    child: Text(
                      p.$1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11.5, color: context.textMuted),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (p.$2 / 4.0).clamp(0.0, 1.0),
                        minHeight: 9,
                        backgroundColor: context.softFill,
                        valueColor: const AlwaysStoppedAnimation(
                            AppColors.indigo500),
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  SizedBox(
                    width: 34,
                    child: Text(
                      p.$2.toStringAsFixed(2),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _courseTile(BuildContext context, Map<String, dynamic> item) {
    final title = pickString(item,
        ['nama_mk', 'nm_mk', 'mata_kuliah', 'nama'], 'Mata Kuliah');
    final kode = pickString(item, ['kode', 'kode_mk', 'kd_mk'], '');
    final sks = pickString(item, ['sks'], '');
    final nilai = pickString(item, ['nilai', 'nilai_huruf', 'grade'], '');
    final semester = pickString(item, ['semester', 'smt', 'periode'], '');
    final color = nilai.toUpperCase().startsWith('A')
        ? AppColors.green
        : (nilai.toUpperCase().startsWith('B')
            ? AppColors.orange
            : AppColors.grey);

    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (semester.isNotEmpty) 'Smt $semester',
                    if (kode.isNotEmpty) kode,
                    if (sks.isNotEmpty) '$sks SKS',
                  ].join('  -  '),
                  style:
                      TextStyle(fontSize: 11, color: context.textMuted),
                ),
              ],
            ),
          ),
          if (nilai.isNotEmpty)
            Text(
              nilai,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
        ],
      ),
    );
  }
}

class SmartJsonTranskrip extends StatelessWidget {
  const SmartJsonTranskrip({super.key, required this.data});
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
