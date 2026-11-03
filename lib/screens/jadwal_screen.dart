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
import '../widgets/smart_detail_page.dart';
import 'jadwal_cetak_screen.dart';

/// Jadwal kuliah per periode, dikelompokkan berdasarkan hari
/// dengan pemilih periode (dropdown), metrik perkuliahan, dan tautan grup kelas.
class JadwalScreen extends StatefulWidget {
  const JadwalScreen({super.key});

  @override
  State<JadwalScreen> createState() => _JadwalScreenState();
}

class _JadwalScreenState extends State<JadwalScreen> {
  final _pageKey = GlobalKey<AsyncPageState<Map<String, dynamic>>>();
  PeriodeProvider? _pp;
  String? _selectedPeriode;
  List<PeriodeOption> _periodeOpts = [];

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
    _pp?.removeListener(_onPeriode);
    super.dispose();
  }

  Future<Map<String, dynamic>> _load() async {
    final api = context.read<ApiClient>();
    final p = _selectedPeriode ??
        context.read<PeriodeProvider>().value ??
        fallbackPeriode();

    final resp = await api.get('/api/akademik/jadwal', query: {'periode': p});
    final data = resp is Map ? (resp['data'] ?? resp) : resp;
    final mapData = asMap(data);

    // Ekstrak periode_tersedia jika dikembalikan oleh backend
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

    // Refresh UI dropdown jika opsi baru saja termuat
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

  void _cetak() {
    final p = _selectedPeriode ??
        context.read<PeriodeProvider>().value ??
        fallbackPeriode();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => JadwalCetakScreen(periode: p),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Pastikan value dropdown valid
    final activeValue = _periodeOpts.any((o) => o.value == _selectedPeriode)
        ? _selectedPeriode
        : (_periodeOpts.isNotEmpty ? _periodeOpts.first.value : _selectedPeriode);

    return AsyncPage<Map<String, dynamic>>(
      key: _pageKey,
      title: 'Jadwal Kuliah',
      subtitle: 'Jadwal perkuliahan semester berjalan',
      load: _load,
      headerActions: [
        HeaderActionButton(
          icon: Icons.print_rounded,
          tooltip: 'Cetak Jadwal',
          onPressed: _cetak,
        ),
      ],
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
    // 1. Deteksi struktur jadwal
    Map<String, dynamic> scheduleMap = {};
    if (data['jadwal'] is Map) {
      scheduleMap = asMap(data['jadwal']);
    } else {
      scheduleMap = data;
    }

    final groups = mapOfLists(scheduleMap);
    final ordered = <String, List<Map<String, dynamic>>>{};

    const dayOrder = [
      'senin', 'selasa', 'rabu', 'kamis', 'jumat', 'sabtu', 'minggu'
    ];

    if (groups.isNotEmpty) {
      final keys = groups.keys.toList();
      keys.sort((a, b) {
        final ia = dayOrder.indexOf(a.toLowerCase().trim());
        final ib = dayOrder.indexOf(b.toLowerCase().trim());
        if (ia == -1 && ib == -1) return 0;
        if (ia == -1) return 1;
        if (ib == -1) return -1;
        return ia.compareTo(ib);
      });
      for (final k in keys) {
        ordered[k] = groups[k]!;
      }
    } else {
      final flat = findMapList(scheduleMap);
      if (flat.isNotEmpty) {
        ordered['Jadwal'] = flat;
      }
    }

    final periode = _selectedPeriode ??
        context.read<PeriodeProvider>().value ??
        '';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        // ============================================================
        // 1. HEADER CARD: Dropdown Periode & Metrik Jadwal
        // ============================================================
        _buildPeriodeOverviewCard(context, data),

        const SizedBox(height: 16),

        // ============================================================
        // 2. DAFTAR JADWAL PER HARI
        // ============================================================
        if (ordered.isEmpty) ...[
          const SizedBox(height: 40),
          const EmptyView(
            icon: Icons.event_busy_rounded,
            message: 'Belum ada jadwal untuk periode ini.',
          ),
          const SizedBox(height: 40),
        ] else ...[
          for (final entry in ordered.entries) ...[
            _buildDayHeader(context, entry.key, entry.value.length),
            const SizedBox(height: 9),
            for (final item in entry.value) ...[
              _SessionCard(
                item: item,
                onTap: () => _openDetail(item, periode),
              ),
              const SizedBox(height: 9),
            ],
            const SizedBox(height: 12),
          ],
        ],

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildPeriodeOverviewCard(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final metrics = asMap(data['metrics']);
    final hariKuliah = pickString(metrics, ['hari_kuliah', 'hari'], '');
    final mataKuliah = pickString(metrics, ['mata_kuliah', 'mk'], '');
    final totalSks = pickString(metrics, ['total_sks', 'sks'], '');

    final statusKrs = pickString(
      data,
      ['status_krs_label', 'status_krs'],
      'KRS Valid',
    );
    final tglMulai = pickString(data, ['tanggal_mulai'], '');
    final tglSelesai = pickString(data, ['tanggal_selesai'], '');

    final activeValue = _periodeOpts.any((o) => o.value == _selectedPeriode)
        ? _selectedPeriode
        : (_periodeOpts.isNotEmpty ? _periodeOpts.first.value : null);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.upiYellowDeep.withValues(alpha: 0.25),
        ),
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
          // Row Dropdown Periode & Status KRS
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
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
                  Icons.calendar_month_rounded,
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
              // Status KRS Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 13,
                      color: AppColors.green,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      statusKrs,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Tanggal Rentang Kuliah jika ada
          if (tglMulai.isNotEmpty && tglSelesai.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.date_range_rounded,
                  size: 13,
                  color: context.textMuted,
                ),
                const SizedBox(width: 5),
                Text(
                  '$tglMulai – $tglSelesai',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: context.textMuted,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Metrik Ringkas: Hari Kuliah, SKS, Mata Kuliah
          Row(
            children: [
              Expanded(
                child: _miniMetric(
                  context,
                  label: 'Hari Kuliah',
                  value: hariKuliah.isNotEmpty ? hariKuliah : '-',
                  icon: Icons.view_week_rounded,
                  color: AppColors.upiYellowDeep,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniMetric(
                  context,
                  label: 'Total SKS',
                  value: totalSks.isNotEmpty
                      ? totalSks.replaceAll(' terjadwal', '')
                      : '-',
                  icon: Icons.stars_rounded,
                  color: AppColors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniMetric(
                  context,
                  label: 'Mata Kuliah',
                  value: mataKuliah.isNotEmpty
                      ? mataKuliah.replaceAll(' Valid', ' MK')
                      : '-',
                  icon: Icons.auto_stories_rounded,
                  color: AppColors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Badge Pengingat Kuliah Otomatis + Tombol Tes
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.green.withValues(alpha: 0.25),
                width: 0.8,
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.notifications_active_rounded,
                  size: 15,
                  color: AppColors.green,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pengingat Kuliah Aktif (15 Menit Sebelum Jam Kuliah)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.green,
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

  Widget _miniMetric(
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
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: context.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: context.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayHeader(BuildContext context, String day, int count) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.upiYellowDeep,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.today_rounded, size: 13, color: Colors.white),
              const SizedBox(width: 5),
              Text(
                _prettyDay(day),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$count sesi perkuliahan',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: context.textMuted,
          ),
        ),
      ],
    );
  }

  String _prettyDay(String raw) {
    final s = raw.trim();
    if (s.length <= 2) return s.toUpperCase();
    return s[0].toUpperCase() + s.substring(1);
  }

  void _openDetail(Map<String, dynamic> item, String periode) {
    final token = detailTokenOf(item);
    if (token == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SmartDetailPage(
        title: 'Detail Jadwal',
        initialData: item,
        load: () => context.read<ApiClient>().get(
              '/api/akademik/jadwal/detail/$token',
              query: {'periode': periode},
            ),
      ),
    ));
  }
}

/// Kartu Sesi Mata Kuliah yang rapi dan informatif
class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.item, this.onTap});

  final Map<String, dynamic> item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final title = pickString(
      item,
      ['matkul', 'nama_mk', 'nm_mk', 'mata_kuliah', 'nama', 'mk'],
      'Mata Kuliah',
    );
    final kode = pickString(item, ['kode', 'kode_mk', 'kd_mk'], '');
    final ruang = pickString(item, ['ruang', 'ruangan', 'lokasi'], '');
    final kelas = pickString(item, ['kelas', 'nama_kelas'], '');
    final dosen = pickString(item, ['dosen', 'nama_dosen', 'pengajar'], '');
    final info = pickString(item, ['info'], '');
    final metodeDetail = pickString(item, ['metode_detail', 'metode'], '');
    final waUrl = pickString(item, ['whatsapp_url', 'wa_url', 'link_wa'], '');
    final token = detailTokenOf(item);

    // Format Jam Perkuliahan
    String jamDisplay = '';
    final wm = pickString(item, ['waktu_mulai', 'jam_mulai'], '');
    final ws = pickString(item, ['waktu_selesai', 'jam_selesai'], '');
    if (wm.isNotEmpty && ws.isNotEmpty) {
      final cleanWs = ws.replaceFirst('s.d. ', '').trim();
      jamDisplay = '$wm - $cleanWs WIB';
    } else {
      jamDisplay = pickString(item, ['jam', 'waktu', 'jam_kuliah'], '');
    }

    final isDaring = metodeDetail.toLowerCase().contains('daring') ||
        ruang.toLowerCase().contains('e-learning');

    return SurfaceCard(
      onTap: token != null ? onTap : null,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ikon Kuliah
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDaring
                      ? AppColors.blue.withValues(alpha: 0.1)
                      : AppColors.upiYellowDeep.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isDaring ? Icons.devices_rounded : Icons.menu_book_rounded,
                  size: 22,
                  color: isDaring ? AppColors.blue : AppColors.upiYellowDeep,
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
                    Row(
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
                        if (kode.isNotEmpty && info.isNotEmpty)
                          Text(
                            ' • ',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: context.textMuted,
                            ),
                          ),
                        if (info.isNotEmpty)
                          Text(
                            info,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: context.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (token != null)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: context.textMuted,
                ),
            ],
          ),

          const SizedBox(height: 10),

          // Badges: Jam, Ruang, Kelas, Metode
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (jamDisplay.isNotEmpty)
                _chip(
                  context,
                  Icons.schedule_rounded,
                  jamDisplay,
                  color: AppColors.upiYellowDeep,
                ),
              if (ruang.isNotEmpty)
                _chip(
                  context,
                  Icons.meeting_room_outlined,
                  ruang,
                  color: isDaring ? AppColors.blue : AppColors.grey,
                ),
              if (kelas.isNotEmpty)
                _chip(
                  context,
                  Icons.groups_rounded,
                  'Kelas $kelas',
                  color: AppColors.indigo700,
                ),
              if (metodeDetail.isNotEmpty)
                _chip(
                  context,
                  isDaring ? Icons.wifi_rounded : Icons.apartment_rounded,
                  metodeDetail,
                  color: isDaring ? AppColors.blue : AppColors.amber,
                ),
            ],
          ),

          // Dosen Pengampu & Grup WA
          if (dosen.isNotEmpty || (waUrl.isNotEmpty && waUrl.startsWith('http'))) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                if (dosen.isNotEmpty) ...[
                  Icon(
                    Icons.person_outline_rounded,
                    size: 14,
                    color: context.textMuted,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      dosen,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: context.textMuted,
                      ),
                    ),
                  ),
                ] else
                  const Spacer(),

                // Tombol Grup WhatsApp
                if (waUrl.isNotEmpty && waUrl.startsWith('http'))
                  InkWell(
                    onTap: () => openExternal(context, waUrl),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF25D366).withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_rounded,
                            size: 12.5,
                            color: Color(0xFF25D366),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Grup WA',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF25D366),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context,
    IconData icon,
    String label, {
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
