import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../state/periode_provider.dart';
import '../theme/app_theme.dart';
import '../utils/smart.dart';
import '../widgets/async_page.dart';
import '../widgets/common.dart';
import '../widgets/periode_dropdown.dart';

/// Halaman Materi Kuliah:
/// Menampilkan daftar mata kuliah, progres publikasi bahan ajar,
/// metrik materi, pemilih periode dropdown dinamis, dan rincian berkas materi per pertemuan.
class MateriScreen extends StatefulWidget {
  const MateriScreen({super.key});

  @override
  State<MateriScreen> createState() => _MateriScreenState();
}

class _MateriScreenState extends State<MateriScreen> {
  final _pageKey = GlobalKey<AsyncPageState<Map<String, dynamic>>>();
  final TextEditingController _searchCtrl = TextEditingController();
  PeriodeProvider? _pp;
  String? _selectedPeriode;
  List<PeriodeOption> _periodeOpts = [];
  String _searchQuery = '';
  String _selectedFilter = 'all'; // all, tersedia, menunggu

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

    final resp = await api.get('/api/akademik/materi', query: {'periode': p});
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

  void _onSelectPeriode(String? newPeriode) {
    if (newPeriode == null || newPeriode == _selectedPeriode) return;
    setState(() {
      _selectedPeriode = newPeriode;
    });
    context.read<PeriodeProvider>().set(newPeriode);
    _pageKey.currentState?.reload();
  }

  void _openMateriKelas(Map<String, dynamic> item, String periode) {
    final token = pickString(item, ['kelas_token', 'token', 'detail_token'], '');
    if (token.isEmpty) return;

    final nama = pickString(item, ['nama', 'nama_mk', 'matkul'], 'Materi Kelas');
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MateriKelasPage(
        kelasToken: token,
        periode: periode,
        judul: nama,
        initialData: item,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final activeValue = _periodeOpts.any((o) => o.value == _selectedPeriode)
        ? _selectedPeriode
        : (_periodeOpts.isNotEmpty ? _periodeOpts.first.value : _selectedPeriode);

    return AsyncPage<Map<String, dynamic>>(
      key: _pageKey,
      title: 'Materi Kuliah',
      subtitle: 'Materi & bahan ajar perkuliahan',
      load: _load,
      headerExtras: _periodeOpts.isNotEmpty
          ? PillDropdown(
              value: activeValue,
              hint: 'Pilih Periode',
              items: [
                for (final o in _periodeOpts)
                  DropdownMenuItem<String>(
                    value: o.value,
                    child: Text(o.label),
                  ),
              ],
              onChanged: _onSelectPeriode,
            )
          : const PeriodeSelector(),
      builder: (context, data) => _body(context, data),
    );
  }

  Widget _body(BuildContext context, Map<String, dynamic> data) {
    List<Map<String, dynamic>> allItems = [];
    if (data['mata_kuliah'] is List) {
      allItems = (data['mata_kuliah'] as List).whereType<Map>().map((e) => asMap(e)).toList();
    } else {
      allItems = findMapList(data);
    }

    final periode = _selectedPeriode ??
        context.read<PeriodeProvider>().value ??
        '';

    // Hitung counter status filter
    int tersediaCount = 0;
    int menungguCount = 0;

    for (final item in allItems) {
      final status = pickString(item, ['status_label', 'status'], '').toLowerCase();
      final progress = pickString(item, ['progress'], '');
      final isTersedia = progress.startsWith(RegExp(r'[1-9]')) ||
          status.contains('tersedia') ||
          status.contains('diterbitkan');

      if (isTersedia) {
        tersediaCount++;
      } else {
        menungguCount++;
      }
    }

    // Filter berdasarkan pencarian & tab status
    final filtered = allItems.where((item) {
      final name = pickString(item, ['nama', 'matkul', 'nama_mk'], '').toLowerCase();
      final code = pickString(item, ['kode', 'kode_mk'], '').toLowerCase();
      final dosen = pickString(item, ['dosen', 'nama_dosen'], '').toLowerCase();
      final kelas = pickString(item, ['kelas'], '').toLowerCase();
      final q = _searchQuery.toLowerCase().trim();

      if (q.isNotEmpty &&
          !name.contains(q) &&
          !code.contains(q) &&
          !dosen.contains(q) &&
          !kelas.contains(q)) {
        return false;
      }

      final status = pickString(item, ['status_label', 'status'], '').toLowerCase();
      final progress = pickString(item, ['progress'], '');
      final isTersedia = progress.startsWith(RegExp(r'[1-9]')) ||
          status.contains('tersedia') ||
          status.contains('diterbitkan');

      if (_selectedFilter == 'tersedia' && !isTersedia) {
        return false;
      }
      if (_selectedFilter == 'menunggu' && isTersedia) {
        return false;
      }

      return true;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. OVERVIEW & METRICS CARD
        _buildOverviewCard(context, data),

        const SizedBox(height: 16),

        // 2. SEARCH BAR
        _buildSearchBar(context),

        const SizedBox(height: 12),

        // 3. FILTER CHIPS
        _buildFilterChips(
          context,
          allCount: allItems.length,
          tersediaCount: tersediaCount,
          menungguCount: menungguCount,
        ),

        const SizedBox(height: 14),

        // 4. LIST MATA KULIAH MATERI
        if (filtered.isEmpty) ...[
          const SizedBox(height: 30),
          _buildEmptyState(context),
          const SizedBox(height: 40),
        ] else ...[
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 10),
            child: Text(
              'Menampilkan ${filtered.length} kelas perkuliahan',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: context.textMuted,
              ),
            ),
          ),
          for (final item in filtered) ...[
            _MateriCard(
              item: item,
              onTap: () => _openMateriKelas(item, periode),
            ),
            const SizedBox(height: 10),
          ],
        ],

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildOverviewCard(BuildContext context, Map<String, dynamic> data) {
    final metrics = asMap(data['metrics']);
    final totalMateri = pickString(metrics, ['total_materi'], '0 Berkas');
    final cakupanPertemuan = pickString(metrics, ['cakupan_pertemuan'], '0 Pertemuan');
    final totalKelas = pickString(metrics, ['mata_kuliah'], '8 Kelas');

    final activeValue = _periodeOpts.any((o) => o.value == _selectedPeriode)
        ? _selectedPeriode
        : (_periodeOpts.isNotEmpty ? _periodeOpts.first.value : null);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.upiYellowDeep.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: AppColors.upiYellowDeep.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.folder_copy_rounded,
                  size: 20,
                  color: AppColors.upiYellowDeep,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Periode Akademik',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.textMuted,
                      ),
                    ),
                    if (_periodeOpts.isNotEmpty)
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: activeValue,
                          isExpanded: true,
                          isDense: true,
                          dropdownColor: context.card,
                          borderRadius: BorderRadius.circular(12),
                          icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 20,
                            color: AppColors.upiYellowDeep,
                          ),
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: context.textPrimary,
                          ),
                          items: _periodeOpts.map((o) {
                            return DropdownMenuItem<String>(
                              value: o.value,
                              child: Text(
                                o.label,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: _onSelectPeriode,
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          pickString(data, ['periode'], _selectedPeriode ?? '-'),
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: context.textPrimary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Badge Total Materi
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.upiYellowDeep.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.upiYellowDeep.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.file_present_rounded, size: 13, color: AppColors.upiYellowDeep),
                    const SizedBox(width: 4),
                    Text(
                      totalMateri,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.upiYellowDeep,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Metrik Ringkas: Total Materi, Cakupan Pertemuan, Total Kelas
          Row(
            children: [
              Expanded(
                child: _statItem(
                  context,
                  label: 'Total Materi',
                  value: totalMateri,
                  icon: Icons.inventory_2_outlined,
                  color: AppColors.upiYellowDeep,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statItem(
                  context,
                  label: 'Cakupan Pertemuan',
                  value: cakupanPertemuan,
                  icon: Icons.calendar_view_week_rounded,
                  color: AppColors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statItem(
                  context,
                  label: 'Mata Kuliah',
                  value: totalKelas,
                  icon: Icons.class_outlined,
                  color: AppColors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
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
              Icon(icon, size: 12.5, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: context.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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

  Widget _buildSearchBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (val) {
          setState(() {
            _searchQuery = val;
          });
        },
        style: TextStyle(fontSize: 13.5, color: context.textPrimary),
        decoration: InputDecoration(
          hintText: 'Cari mata kuliah, kode, kelas, atau dosen...',
          hintStyle: TextStyle(fontSize: 13, color: context.textMuted),
          prefixIcon: Icon(Icons.search_rounded, size: 20, color: context.textMuted),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: InputBorder.none,
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildFilterChips(
    BuildContext context, {
    required int allCount,
    required int tersediaCount,
    required int menungguCount,
  }) {
    final filters = [
      {'key': 'all', 'label': 'Semua', 'count': allCount, 'color': AppColors.upiYellowDeep},
      {'key': 'menunggu', 'label': 'Menunggu Publikasi', 'count': menungguCount, 'color': AppColors.grey},
      if (tersediaCount > 0)
        {'key': 'tersedia', 'label': 'Tersedia', 'count': tersediaCount, 'color': AppColors.green},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final key = f['key'] as String;
          final label = f['label'] as String;
          final count = f['count'] as int;
          final color = f['color'] as Color;
          final isSelected = _selectedFilter == key;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedFilter = key;
                });
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5.5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color
                      : color.withValues(alpha: context.isDark ? 0.12 : 0.07),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? color : color.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected ? Colors.white : color,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.25)
                            : color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? Colors.white : color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.border),
      ),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.amber.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.menu_book_outlined,
              size: 26,
              color: AppColors.upiYellowDeep,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Materi Tidak Ditemukan',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tidak ada kelas materi yang cocok dengan pencarian atau filter Anda.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: context.textMuted),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              _searchCtrl.clear();
              setState(() {
                _searchQuery = '';
                _selectedFilter = 'all';
              });
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.upiYellowDeep,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Reset Filter', style: TextStyle(fontSize: 12.5)),
          ),
        ],
      ),
    );
  }
}

/// Kartu Kelas Materi
class _MateriCard extends StatelessWidget {
  const _MateriCard({required this.item, required this.onTap});

  final Map<String, dynamic> item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = pickString(item, ['nama', 'matkul', 'nama_mk'], 'Mata Kuliah');
    final kode = pickString(item, ['kode', 'kode_mk'], '');
    final kelas = pickString(item, ['kelas'], '');
    final dosen = pickString(item, ['dosen'], '');
    final hari = pickString(item, ['hari'], '');
    final jam = pickString(item, ['jam'], '');
    final ruang = pickString(item, ['ruang'], '');
    final info = pickString(item, ['info'], '');
    final progress = pickString(item, ['progress'], '0/16 pertemuan');
    final statusLabel = pickString(item, ['status_label', 'status'], 'Menunggu publikasi dosen');

    final progressVal = double.tryParse(RegExp(r'(\d+)').firstMatch(progress)?.group(1) ?? '0') ?? 0;
    final progressPct = (progressVal / 16).clamp(0.0, 1.0);

    final isTersedia = progressVal > 0 || statusLabel.toLowerCase().contains('tersedia');
    final statusColor = isTersedia ? AppColors.green : AppColors.grey;

    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.upiYellowDeep.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.folder_open_rounded,
                  size: 22,
                  color: AppColors.upiYellowDeep,
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
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 3),
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
                        if (kelas.isNotEmpty)
                          Text(
                            '• Kelas $kelas',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: context.textMuted,
                            ),
                          ),
                        if (info.isNotEmpty)
                          Text(
                            '• $info',
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
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, size: 20, color: context.textMuted),
            ],
          ),

          const SizedBox(height: 10),

          // Baris Progress Materi & Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Materi: $progress',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: context.textMuted,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withValues(alpha: 0.25)),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progressPct,
              minHeight: 5.5,
              backgroundColor: context.softFill,
              valueColor: AlwaysStoppedAnimation(statusColor),
            ),
          ),

          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // Baris Jadwal, Ruang, Dosen
          Row(
            children: [
              if (hari.isNotEmpty || jam.isNotEmpty || ruang.isNotEmpty) ...[
                Icon(Icons.schedule_rounded, size: 13, color: context.textMuted),
                const SizedBox(width: 4),
                Text(
                  [hari, jam, if (ruang.isNotEmpty) 'R. $ruang'].where((s) => s.isNotEmpty).join(' • '),
                  style: TextStyle(fontSize: 11, color: context.textMuted),
                ),
                const SizedBox(width: 10),
              ],
              if (dosen.isNotEmpty) ...[
                Icon(Icons.person_outline_rounded, size: 13, color: context.textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    dosen,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: context.textMuted),
                  ),
                ),
              ] else
                const Spacer(),

              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Lihat Materi',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.upiYellowDeep,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 13,
                    color: AppColors.upiYellowDeep,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// Halaman Rincian Materi Kelas (16 Pertemuan + Materi Umum)
// ====================================================================

class MateriKelasPage extends StatelessWidget {
  const MateriKelasPage({
    super.key,
    required this.kelasToken,
    required this.periode,
    required this.judul,
    this.initialData,
  });

  final String kelasToken;
  final String periode;
  final String judul;
  final Map<String, dynamic>? initialData;

  @override
  Widget build(BuildContext context) {
    return AsyncPage<Map<String, dynamic>>(
      title: judul,
      subtitle: 'Bahan ajar & materi pertemuan',
      load: () async {
        final api = context.read<ApiClient>();
        final resp = await api.get(
          '/api/akademik/materi/kelas/$kelasToken',
          query: {'periode': periode},
        );
        final data = resp is Map ? (resp['data'] ?? resp) : resp;
        return asMap(data);
      },
      builder: (context, data) => _buildBody(context, data),
    );
  }

  Widget _buildBody(BuildContext context, Map<String, dynamic> data) {
    final nama = pickString(data, ['nama'], judul);
    final kode = pickString(data, ['kode'], pickString(initialData ?? {}, ['kode'], ''));
    final kelas = pickString(data, ['kelas'], pickString(initialData ?? {}, ['kelas'], ''));
    final dosen = pickString(data, ['dosen'], pickString(initialData ?? {}, ['dosen'], ''));
    final sks = pickString(data, ['sks'], pickString(initialData ?? {}, ['info'], ''));
    final materiTersedia = pickString(data, ['materi_tersedia', 'total_materi_tampil'], '0 Materi');
    final materiDesc = pickString(data, ['materi_desc'], '');

    final pertemuanList = asList(data['pertemuan']).map((e) => asMap(e)).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      children: [
        // 1. HERO HEADER CARD
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.upiYellowDeep.withValues(alpha: 0.25)),
            boxShadow: [
              BoxShadow(
                color: AppColors.upiYellowDeep.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nama,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: context.textPrimary,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (kode.isNotEmpty)
                              _chip(context, Icons.tag_rounded, kode, AppColors.upiYellowDeep),
                            if (kelas.isNotEmpty)
                              _chip(context, Icons.groups_rounded, 'Kelas $kelas', AppColors.indigo700),
                            if (sks.isNotEmpty)
                              _chip(context, Icons.school_rounded, sks, AppColors.grey),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.upiYellowDeep.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.upiYellowDeep.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      materiTersedia,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.upiYellowDeep,
                      ),
                    ),
                  ),
                ],
              ),
              if (dosen.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.person_outline_rounded, size: 14, color: context.textMuted),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        dosen,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.textMuted),
                      ),
                    ),
                  ],
                ),
              ],
              if (materiDesc.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  materiDesc,
                  style: TextStyle(fontSize: 11, color: context.textMuted),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 18),

        // 2. SECTION TITLE
        SectionTitle('Rincian Bahan Ajar (${pertemuanList.length} Sesi)'),
        const SizedBox(height: 10),

        // 3. DAFTAR PERTEMUAN & BERKAS MATERI
        if (pertemuanList.isEmpty)
          const EmptyView(message: 'Belum ada data pertemuan untuk kelas ini.')
        else
          for (final p in pertemuanList)
            _buildPertemuanItem(context, p),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _chip(BuildContext context, IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildPertemuanItem(BuildContext context, Map<String, dynamic> p) {
    final judul = pickString(p, ['judul'], 'Pertemuan');
    final label = pickString(p, ['label'], '');
    final total = pickString(p, ['total'], '0 materi');
    final kosongMsg = pickString(p, ['kosong_msg'], 'Belum ada materi yang diterbitkan.');
    final materiList = asList(p['materi']).map((e) => asMap(e)).toList();

    final hasMateri = materiList.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Sesi Pertemuan
          Row(
            children: [
              if (label.isNotEmpty)
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: hasMateri
                        ? AppColors.green.withValues(alpha: 0.12)
                        : AppColors.upiYellowDeep.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: hasMateri ? AppColors.green : AppColors.upiYellowDeep,
                    ),
                  ),
                ),
              Expanded(
                child: Text(
                  judul,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: hasMateri
                      ? AppColors.green.withValues(alpha: 0.1)
                      : context.softFill,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasMateri
                        ? AppColors.green.withValues(alpha: 0.3)
                        : context.border,
                  ),
                ),
                child: Text(
                  total,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: hasMateri ? AppColors.green : context.textMuted,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Daftar Berkas Materi atau Pesan Kosong
          if (hasMateri) ...[
            for (final m in materiList)
              _buildFileCard(context, m),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.softFill,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: context.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      kosongMsg,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: context.textMuted,
                        fontStyle: FontStyle.italic,
                      ),
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

  Widget _buildFileCard(BuildContext context, Map<String, dynamic> m) {
    final title = pickString(m, ['judul', 'nama', 'title'], 'Berkas Materi');
    final desc = pickString(m, ['deskripsi', 'keterangan'], '');
    final tipe = pickString(m, ['tipe'], 'pdf').toLowerCase();
    final ukuran = pickString(m, ['ukuran'], '');
    final url = pickString(m, ['url', 'download_url', 'link'], '');

    final IconData fileIcon = tipe.contains('pdf')
        ? Icons.picture_as_pdf_rounded
        : (tipe.contains('ppt') || tipe.contains('presentation')
            ? Icons.slideshow_rounded
            : (tipe.contains('doc') || tipe.contains('word')
                ? Icons.article_rounded
                : (tipe.contains('zip') || tipe.contains('rar')
                    ? Icons.folder_zip_rounded
                    : Icons.insert_drive_file_rounded)));

    final Color fileColor = tipe.contains('pdf')
        ? AppColors.red
        : (tipe.contains('ppt')
            ? AppColors.orange
            : (tipe.contains('doc') ? AppColors.blue : AppColors.upiYellowDeep));

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fileColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fileColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(fileIcon, size: 18, color: fileColor),
          ),
          const SizedBox(width: 10),
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
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: context.textMuted),
                  ),
                ],
                if (ukuran.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    ukuran,
                    style: TextStyle(fontSize: 10, color: context.textMuted, fontWeight: FontWeight.w500),
                  ),
                ],
              ],
            ),
          ),
          if (url.isNotEmpty && url.startsWith('http'))
            IconButton(
              tooltip: 'Buka / Unduh Berkas',
              icon: const Icon(Icons.download_rounded, color: AppColors.upiYellowDeep, size: 20),
              onPressed: () => openExternal(context, url),
            ),
        ],
      ),
    );
  }
}
