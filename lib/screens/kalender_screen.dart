import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../utils/smart.dart';
import '../widgets/async_page.dart';
import '../widgets/common.dart';
import '../widgets/gradient_header.dart';
import '../widgets/periode_dropdown.dart';
import '../widgets/smart_detail_page.dart';

/// Kalender akademik per tahun ajaran: agenda penting kampus.
class KalenderScreen extends StatefulWidget {
  const KalenderScreen({super.key});

  @override
  State<KalenderScreen> createState() => _KalenderScreenState();
}

class _KalenderScreenState extends State<KalenderScreen> {
  final _pageKey = GlobalKey<AsyncPageState<Map<String, dynamic>>>();
  late String _tahun;

  @override
  void initState() {
    super.initState();
    _tahun = currentTahunAkademik();
  }

  List<String> get _tahunOptions {
    final parts = _tahun.split('/');
    final y = int.tryParse(parts.first) ?? DateTime.now().year;
    return [for (var i = -2; i <= 2; i++) '${y + i}/${y + i + 1}'];
  }

  Future<Map<String, dynamic>> _load() async {
    final api = context.read<ApiClient>();
    final resp = await api
        .get('/api/akademik/kalender/data', query: {'tahun': _tahun});
    final data = resp is Map ? (resp['data'] ?? resp) : resp;
    return asMap(data);
  }

  void _openDetail(Map<String, dynamic> item) {
    final token = detailTokenOf(item);
    if (token == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SmartDetailPage(
        title: 'Detail Agenda',
        load: () =>
            context.read<ApiClient>().get('/api/akademik/kalender/detail/$token'),
        printLoader: () =>
            context.read<ApiClient>().get('/api/akademik/kalender/cetak-url/$token'),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AsyncPage<Map<String, dynamic>>(
      key: _pageKey,
      title: 'Kalender Akademik',
      subtitle: 'Tahun ajaran $_tahun',
      load: _load,
      headerExtras: PillDropdown(
        value: _tahun,
        items: [
          for (final t in _tahunOptions)
            DropdownMenuItem<String>(value: t, child: Text(t)),
        ],
        onChanged: (v) {
          if (v == null) return;
          setState(() => _tahun = v);
          _pageKey.currentState?.reload();
        },
      ),
      builder: (context, data) {
        final items = findMapList(data);
        if (items.isEmpty) {
          return ListView(
            children: const [
              SizedBox(height: 80),
              EmptyView(
                  icon: Icons.event_note_outlined,
                  message: 'Belum ada agenda untuk tahun ajaran ini.'),
            ],
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final item in items) ...[
              _AgendaCard(
                item: item,
                onTap: detailTokenOf(item) != null
                    ? () => _openDetail(item)
                    : null,
              ),
              const SizedBox(height: 9),
            ],
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }
}

class _AgendaCard extends StatelessWidget {
  const _AgendaCard({required this.item, this.onTap});
  final Map<String, dynamic> item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final title = pickString(item,
        ['kegiatan', 'judul', 'nama', 'agenda', 'keterangan'], 'Agenda');
    final tanggal =
        pickString(item, ['tanggal', 'tgl', 'waktu', 'periode_waktu'], '');
    final keterangan =
        pickString(item, ['keterangan', 'deskripsi', 'isi', 'catatan'], '');

    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.indigo300.withOpacity(0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.event_available_rounded,
                size: 21, color: AppColors.indigo700),
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
                if (tanggal.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    tanggal,
                    style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.orange,
                        fontWeight: FontWeight.w600),
                  ),
                ],
                if (keterangan.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    keterangan,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11.5, color: context.textMuted),
                  ),
                ],
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.chevron_right_rounded,
                size: 20, color: context.textMuted),
        ],
      ),
    );
  }
}
