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

/// Kartu ujian UTS / UAS dengan toggle jenis dan tombol cetak.
class KartuUjianScreen extends StatefulWidget {
  const KartuUjianScreen({super.key});

  @override
  State<KartuUjianScreen> createState() => _KartuUjianScreenState();
}

class _KartuUjianScreenState extends State<KartuUjianScreen> {
  final _pageKey = GlobalKey<AsyncPageState<Map<String, dynamic>>>();
  PeriodeProvider? _pp;
  String _jenis = 'uts';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _pp = context.read<PeriodeProvider>();
      _pp!.addListener(_onPeriode);
      _pp!.ensureLoaded().then((_) {
        if (mounted) _pageKey.currentState?.reload();
      });
    });
  }

  void _onPeriode() {
    if (mounted) _pageKey.currentState?.reload();
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
    final resp = await api.get('/api/akademik/kartu-ujian/data',
        query: {'jenis': _jenis, 'periode': p});
    final data = resp is Map ? (resp['data'] ?? resp) : resp;
    return asMap(data);
  }

  Future<void> _cetak() async {
    try {
      final api = context.read<ApiClient>();
      final p =
          context.read<PeriodeProvider>().value ?? fallbackPeriode();
      final resp = await api.get('/api/akademik/kartu-ujian/cetak-url',
          query: {'jenis': _jenis, 'periode': p});
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
      title: 'Kartu Ujian',
      subtitle: 'Kartu rencana ujian UTS dan UAS',
      load: _load,
      headerActions: [
        HeaderActionButton(
          icon: Icons.print_rounded,
          tooltip: 'Cetak Kartu',
          onPressed: _cetak,
        ),
      ],
      headerExtras: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 240,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                    value: 'uts',
                    label: Text('UTS'),
                    icon: Icon(Icons.edit_note_rounded, size: 16)),
                ButtonSegment(
                    value: 'uas',
                    label: Text('UAS'),
                    icon: Icon(Icons.edit_document, size: 16)),
              ],
              selected: {_jenis},
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: AppColors.amber,
                selectedForegroundColor: AppColors.indigo950,
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withOpacity(0.12),
                side: BorderSide(color: Colors.white.withOpacity(0.25)),
                textStyle:
                    const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                padding: const EdgeInsets.symmetric(vertical: 7),
              ),
              onSelectionChanged: (s) {
                setState(() => _jenis = s.first);
                _pageKey.currentState?.reload();
              },
            ),
          ),
          const SizedBox(height: 10),
          const PeriodeSelector(),
        ],
      ),
      builder: (context, data) {
        final items = findMapList(data);
        if (items.isEmpty) {
          return ListView(
            children: [
              const SizedBox(height: 80),
              EmptyView(
                  icon: Icons.badge_outlined,
                  message:
                      'Belum ada jadwal ujian ${_jenis.toUpperCase()} untuk periode ini.'),
            ],
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final item in items) ...[
              _UjianCard(item: item),
              const SizedBox(height: 9),
            ],
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }
}

class _UjianCard extends StatelessWidget {
  const _UjianCard({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final title = pickString(item,
        ['nama_mk', 'nm_mk', 'mata_kuliah', 'nama'], 'Mata Kuliah');
    final kode = pickString(item, ['kode', 'kode_mk', 'kd_mk'], '');
    final tanggal =
        pickString(item, ['tanggal', 'tgl_ujian', 'tgl', 'hari'], '');
    final jam = pickString(item, ['jam', 'waktu', 'jam_ujian'], '');
    final ruang = pickString(item, ['ruang', 'ruangan', 'lokasi'], '');
    final kursi = pickString(item, ['no_kursi', 'nomor_kursi', 'kursi'], '');

    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.red.withOpacity(0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.event_seat_rounded,
                size: 22, color: AppColors.red),
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
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary,
                  ),
                ),
                if (kode.isNotEmpty)
                  Text(kode,
                      style: TextStyle(
                          fontSize: 11.5, color: context.textMuted)),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (tanggal.isNotEmpty)
                      _chip(context, Icons.calendar_today_rounded, tanggal),
                    if (jam.isNotEmpty)
                      _chip(context, Icons.schedule_rounded, jam),
                    if (ruang.isNotEmpty)
                      _chip(context, Icons.place_rounded, ruang),
                    if (kursi.isNotEmpty)
                      _chip(context, Icons.event_seat_rounded, 'No. $kursi'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: context.softFill,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.5, color: AppColors.indigo500),
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
