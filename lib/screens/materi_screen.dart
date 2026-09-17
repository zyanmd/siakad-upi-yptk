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
import '../widgets/smart_json.dart';

/// Daftar kelas yang punya materi, lanjut ke daftar materinya.
class MateriScreen extends StatefulWidget {
  const MateriScreen({super.key});

  @override
  State<MateriScreen> createState() => _MateriScreenState();
}

class _MateriScreenState extends State<MateriScreen> {
  final _pageKey = GlobalKey<AsyncPageState<Map<String, dynamic>>>();
  PeriodeProvider? _pp;

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
    final resp =
        await api.get('/api/akademik/materi', query: {'periode': p});
    final data = resp is Map ? (resp['data'] ?? resp) : resp;
    return asMap(data);
  }

  @override
  Widget build(BuildContext context) {
    return AsyncPage<Map<String, dynamic>>(
      key: _pageKey,
      title: 'Materi Kuliah',
      subtitle: 'Materi & bahan ajar per kelas',
      load: _load,
      headerExtras: const PeriodeSelector(),
      builder: (context, data) {
        final items = findMapList(data);
        if (items.isEmpty) {
          return ListView(
            children: const [
              SizedBox(height: 80),
              EmptyView(
                  icon: Icons.menu_book_outlined,
                  message: 'Belum ada kelas dengan materi untuk periode ini.'),
            ],
          );
        }
        final periode =
            context.read<PeriodeProvider>().value ?? '';
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final item in items) ...[
              _KelasCard(
                item: item,
                onTap: () {
                  final token = detailTokenOf(item);
                  if (token == null) return;
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => MateriKelasPage(
                      kelasToken: token,
                      periode: periode,
                      judul: pickString(item,
                          ['nama_mk', 'nm_mk', 'mata_kuliah', 'nama'],
                          'Materi Kelas'),
                    ),
                  ));
                },
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

class _KelasCard extends StatelessWidget {
  const _KelasCard({required this.item, this.onTap});
  final Map<String, dynamic> item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final title = pickString(item,
        ['nama_mk', 'nm_mk', 'mata_kuliah', 'nama'], 'Mata Kuliah');
    final kelas = pickString(item, ['kelas', 'nama_kelas'], '');
    final dosen = pickString(item, ['dosen', 'nama_dosen', 'pengajar'], '');
    final jumlah = pickString(
        item, ['jumlah', 'jumlah_materi', 'total', 'total_materi'], '');

    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.orange.withOpacity(0.13),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.folder_shared_rounded,
                size: 22, color: AppColors.orange),
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
                const SizedBox(height: 4),
                Text(
                  [
                    if (kelas.isNotEmpty) 'Kelas $kelas',
                    if (dosen.isNotEmpty) dosen,
                    if (jumlah.isNotEmpty) '$jumlah materi',
                  ].join('  -  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: context.textMuted),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              size: 20, color: context.textMuted),
        ],
      ),
    );
  }
}

// ============================================================ materi kelas

/// Daftar materi dalam satu kelas.
class MateriKelasPage extends StatefulWidget {
  const MateriKelasPage({
    super.key,
    required this.kelasToken,
    required this.periode,
    required this.judul,
  });

  final String kelasToken;
  final String periode;
  final String judul;

  @override
  State<MateriKelasPage> createState() => _MateriKelasPageState();
}

class _MateriKelasPageState extends State<MateriKelasPage> {
  Future<Map<String, dynamic>> _load() async {
    final api = context.read<ApiClient>();
    final resp = await api.get(
      '/api/akademik/materi/kelas/${widget.kelasToken}',
      query: {'periode': widget.periode},
    );
    final data = resp is Map ? (resp['data'] ?? resp) : resp;
    return asMap(data);
  }

  @override
  Widget build(BuildContext context) {
    return AsyncPage<Map<String, dynamic>>(
      title: widget.judul,
      subtitle: 'Daftar materi pertemuan',
      load: _load,
      builder: (context, data) {
        final items = findMapList(data);
        if (items.isEmpty) {
          return ListView(
            children: const [
              SizedBox(height: 80),
              EmptyView(
                  icon: Icons.description_outlined,
                  message: 'Belum ada materi yang diunggah di kelas ini.'),
            ],
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final m in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: SurfaceCard(
                  padding: const EdgeInsets.all(13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: AppColors.indigo700.withOpacity(0.09),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.description_rounded,
                                size: 17, color: AppColors.indigo500),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              pickString(m,
                                  ['judul', 'nama', 'title', 'topik'], 'Materi'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: context.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      if (pickString(m,
                              ['tanggal', 'tgl', 'created_at', 'waktu'], '')
                          .isNotEmpty)
                        Text(
                          pickString(
                              m, ['tanggal', 'tgl', 'created_at', 'waktu']),
                          style: TextStyle(
                              fontSize: 11, color: context.textMuted),
                        ),
                      if (pickString(m,
                              ['deskripsi', 'keterangan', 'isi', 'konten'], '')
                          .isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          pickString(
                              m, ['deskripsi', 'keterangan', 'isi', 'konten']),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, color: context.textMuted,
                              height: 1.45),
                        ),
                      ],
                      const SizedBox(height: 8),
                      SmartJson(data: m, excludeKeys: const [
                        'judul', 'nama', 'title', 'topik', 'tanggal', 'tgl',
                        'created_at', 'waktu', 'deskripsi', 'keterangan',
                        'isi', 'konten',
                      ]),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }
}
