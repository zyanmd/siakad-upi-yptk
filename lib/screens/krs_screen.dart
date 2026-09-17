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
import '../widgets/smart_json.dart';
import 'krs_cetak_screen.dart';
import 'krs_pick_sheet.dart';
import 'kurikulum_screen.dart';

/// Kartu Rencana Studi: daftar MK diambil, ambil MK baru, hapus, cetak.
class KrsScreen extends StatefulWidget {
  const KrsScreen({super.key});

  @override
  State<KrsScreen> createState() => _KrsScreenState();
}

class _KrsScreenState extends State<KrsScreen> {
  final _pageKey = GlobalKey<AsyncPageState<Map<String, dynamic>>>();
  PeriodeProvider? _pp;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pp = context.read<PeriodeProvider>();
      _pp = pp;
      pp.addListener(_onPeriode);
      pp.ensureLoaded().then((_) {
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
    final results = await Future.wait<dynamic>([
      api.get('/api/akademik/krs', query: {'periode': p}),
      api.get('/api/akademik/krs/status'),
    ]);
    return {
      'krs': results[0],
      'status': results[1],
      'periode': p,
    };
  }

  // ------------------------------------------------------------ aksi

  void _cetak() {
    final p = context.read<PeriodeProvider>().value ?? fallbackPeriode();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => KrsCetakScreen(periode: p),
      ),
    );
  }

  Future<void> _openKurikulum() async {
    final p = context.read<PeriodeProvider>().value ?? fallbackPeriode();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => KurikulumScreen(periode: p),
    ));
  }

  Future<void> _hapusItem(Map<String, dynamic> item) async {
    final token = pickString(item, ['delete_token', 'token'], '');
    if (token.isEmpty) {
      appToast(context, 'Token hapus tidak tersedia pada item ini.',
          error: true);
      return;
    }
    final nama = pickString(item,
        ['nama_mk', 'nm_mk', 'mata_kuliah', 'nama'], 'mata kuliah ini');
    final ok = await confirmDialog(
      context,
      'Hapus Mata Kuliah',
      'Yakin ingin menghapus "$nama" dari KRS?',
    );
    if (!ok || !mounted) return;
    try {
      final api = context.read<ApiClient>();
      final resp = await api.delete('/api/akademik/krs/$token');
      final msg = resp is Map
          ? pickString(asMap(resp), ['message'], 'Mata kuliah dihapus.')
          : 'Mata kuliah dihapus.';
      if (!mounted) return;
      appToast(context, msg);
      _pageKey.currentState?.reload();
    } catch (e) {
      if (mounted) appToast(context, errorText(e), error: true);
    }
  }

  Future<void> _bukaAmbilMk() async {
    final pp = context.read<PeriodeProvider>();
    final periode = pp.value ?? fallbackPeriode();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => KrsPickSheet(
        periode: periode,
        onAdded: () => _pageKey.currentState?.reload(),
      ),
    );
  }

  // ------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    return AsyncPage<Map<String, dynamic>>(
      key: _pageKey,
      title: 'Kartu Rencana Studi',
      subtitle: 'Kelola mata kuliah yang diambil',
      load: _load,
      headerActions: [
        HeaderActionButton(
          icon: Icons.print_rounded,
          tooltip: 'Cetak KRS',
          onPressed: _cetak,
        ),
        HeaderActionButton(
          icon: Icons.menu_book_rounded,
          tooltip: 'Kurikulum',
          onPressed: _openKurikulum,
        ),
      ],
      headerExtras: const PeriodeSelector(),
      fab: FloatingActionButton.extended(
        backgroundColor: AppColors.amber,
        foregroundColor: AppColors.indigo950,
        elevation: 2,
        onPressed: _bukaAmbilMk,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Ambil MK',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      builder: (context, data) => _body(context, data),
    );
  }

  Widget _body(BuildContext context, Map<String, dynamic> data) {
    final krsResp = asMap(data['krs']);
    final statusResp = asMap(data['status']);
    final krsData = asMap(krsResp['data'] ?? krsResp);
    final statusData = asMap(statusResp['data'] ?? statusResp);

    List<Map<String, dynamic>> items = [];
    if (krsData['mata_kuliah'] is List) {
      items = (krsData['mata_kuliah'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } else {
      items = findMapList(krsData);
    }

    final totalSks = pickString(krsData, ['total_sks', 'jumlah_sks', 'sks_total'],
        pickString(krsResp, ['total_sks', 'jumlah_sks', 'sks_total'], ''));
    final maksSks = pickString(krsData, ['maks_sks', 'max_sks', 'maksimal_sks'],
        pickString(statusData, ['maks_sks', 'max_sks', 'maksimal_sks'], ''));
    final statusKrs = pickString(krsData, ['status_krs', 'status'],
        pickString(statusData, ['status_krs', 'status'], ''));
    final tglMulai = pickString(krsData, ['tanggal_mulai', 'tgl_mulai'],
        pickString(statusData, ['tanggal_mulai', 'tgl_mulai'], ''));
    final tglSelesai = pickString(krsData, ['tanggal_selesai', 'tgl_selesai'],
        pickString(statusData, ['tanggal_selesai', 'tgl_selesai'], ''));
    final bisaUbah = krsData['bisa_ubah'] == true || statusData['bisa_ubah'] == true;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        _statusCard(
          context,
          statusData: statusData,
          totalSks: totalSks,
          maksSks: maksSks,
          statusKrs: statusKrs,
          tglMulai: tglMulai,
          tglSelesai: tglSelesai,
          bisaUbah: bisaUbah,
        ),
        const SizedBox(height: 16),
        SectionTitle(
          'Mata Kuliah Diambil (${items.length})',
          trailing: (items.isNotEmpty && totalSks.isNotEmpty)
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.upiYellowDeep.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '$totalSks SKS',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.upiYellowDeep,
                    ),
                  ),
                )
              : null,
        ),
        const SizedBox(height: 10),
        if (items.isEmpty) ...[
          const SizedBox(height: 24),
          const EmptyView(
            icon: Icons.assignment_outlined,
            message: 'Belum ada mata kuliah di KRS periode ini.\n'
                'Tekan tombol "Ambil MK" untuk menambah.',
          ),
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton.icon(
              onPressed: _bukaAmbilMk,
              icon: const Icon(Icons.add_rounded, color: AppColors.upiYellowDeep),
              label: const Text(
                'Pilih & Tambah Mata Kuliah',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.upiYellowDeep,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.upiYellowDeep, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ),
        ] else ...[
          for (final item in items) ...[
            _KrsItemCard(
              item: item,
              bisaUbah: bisaUbah,
              onDelete: () => _hapusItem(item),
              onTap: () => _openDetailItem(item, data['periode'].toString()),
            ),
            const SizedBox(height: 10),
          ],
        ],
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _statusCard(
    BuildContext context, {
    required Map<String, dynamic> statusData,
    required String totalSks,
    required String maksSks,
    required String statusKrs,
    required String tglMulai,
    required String tglSelesai,
    required bool bisaUbah,
  }) {
    final double? totalVal = double.tryParse(totalSks);
    final double? maksVal = double.tryParse(maksSks);
    final double progress = (totalVal != null && maksVal != null && maksVal > 0)
        ? (totalVal / maksVal).clamp(0.0, 1.0)
        : 0.0;

    final isOpen = statusKrs.toLowerCase() == 'open' || bisaUbah;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.upiYellowBright, AppColors.upiYellowDeep],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.fact_check_rounded,
                    size: 20, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Status Rencana Studi (KRS)',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                    ),
                    Text(
                      isOpen ? 'Periode KRS Aktif' : 'Periode KRS Ditutup',
                      style: TextStyle(
                        fontSize: 12,
                        color: isOpen ? AppColors.green : context.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isOpen
                      ? AppColors.green.withValues(alpha: 0.12)
                      : Colors.grey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isOpen
                        ? AppColors.green.withValues(alpha: 0.3)
                        : Colors.grey.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: isOpen ? AppColors.green : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isOpen ? 'OPEN' : 'CLOSED',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isOpen ? AppColors.green : context.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Tanggal KRS jika ada
          if (tglMulai.isNotEmpty || tglSelesai.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: context.softFill,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded,
                      size: 13, color: AppColors.upiYellowDeep),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Masa KRS: ${tglMulai.isNotEmpty ? tglMulai : '-'} s/d ${tglSelesai.isNotEmpty ? tglSelesai : '-'}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Baris progress SKS
          if (totalVal != null || maksVal != null) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Beban SKS Diambil',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: context.textMuted,
                  ),
                ),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: context.textPrimary,
                    ),
                    children: [
                      TextSpan(
                        text: totalSks.isNotEmpty ? totalSks : '0',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.upiYellowDeep,
                          fontSize: 14,
                        ),
                      ),
                      if (maksSks.isNotEmpty) ...[
                        TextSpan(
                          text: ' / $maksSks SKS',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: context.textMuted,
                          ),
                        ),
                      ] else ...[
                        const TextSpan(
                          text: ' SKS',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (maksVal != null && maksVal > 0) ...[
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 7,
                  backgroundColor: context.border,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress >= 1.0 ? AppColors.red : AppColors.upiYellowBright,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(progress * 100).toInt()}% terpakai',
                    style: TextStyle(fontSize: 11, color: context.textMuted),
                  ),
                  if (totalVal != null && maksVal - totalVal >= 0)
                    Text(
                      'Sisa ${(maksVal - totalVal).toInt()} SKS',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.green,
                      ),
                    ),
                ],
              ),
            ],
          ],

          // Informasi tambahan jika ada
          if (statusData.isNotEmpty) ...[
            const SizedBox(height: 8),
            SmartJson(
              data: statusData,
              excludeKeys: const [
                'status',
                'status_krs',
                'sts',
                'kondisi',
                'bisa_ubah',
                'tanggal_mulai',
                'tgl_mulai',
                'tanggal_selesai',
                'tgl_selesai',
                'total_sks',
                'maks_sks',
                'max_sks',
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _openDetailItem(Map<String, dynamic> item, String periode) {
    final token = detailTokenOf(item);
    if (token == null || token.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SmartDetailPage(
        title: 'Jadwal Mata Kuliah',
        initialData: item,
        load: () => context.read<ApiClient>().get(
              '/api/akademik/krs/jadwal/$token',
              query: {'periode': periode},
            ),
      ),
    ));
  }
}

// ==================================================================== item

class _KrsItemCard extends StatelessWidget {
  const _KrsItemCard({
    required this.item,
    required this.onDelete,
    this.bisaUbah = true,
    this.onTap,
  });

  final Map<String, dynamic> item;
  final VoidCallback onDelete;
  final bool bisaUbah;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final title = pickString(item,
        ['nama_mk', 'nm_mk', 'mata_kuliah', 'nama'], 'Mata Kuliah');
    final kode = pickString(item, ['kode', 'kode_mk', 'kd_mk'], '');
    final sks = pickString(item, ['sks'], '');
    final kelas = pickString(item, ['kelas', 'nama_kelas'], '');
    final dosen = pickString(item, ['dosen', 'nama_dosen', 'pengajar'], '');
    final ruang = pickString(item, ['ruang', 'kd_ruang', 'nama_ruang'], '');
    final hari = pickString(item, ['hari', 'hari_kuliah'], '');
    final jam = pickString(item, ['jam', 'jam_kuliah', 'waktu'], '');
    final statusMk = pickString(item, ['status', 'status_mk', 'keterangan'], '');
    final deleteToken = pickString(item, ['delete_token', 'token'], '');
    final detailToken = detailTokenOf(item);

    final hasDelete = deleteToken.isNotEmpty && bisaUbah;
    final hasSchedule = hari.isNotEmpty || jam.isNotEmpty;

    return SurfaceCard(
      onTap: detailToken != null ? onTap : null,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // SKS Badge UPI Gold
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.upiYellowBright, AppColors.upiYellowDeep],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.upiYellowDeep.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '${sks.isEmpty ? '-' : sks}\nSKS',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.1,
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
                        if (kode.isNotEmpty && statusMk.isNotEmpty)
                          Text(
                            ' • ',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: context.textMuted,
                            ),
                          ),
                        if (statusMk.isNotEmpty)
                          Text(
                            statusMk,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: statusMk.toLowerCase().contains('batal')
                                  ? AppColors.red
                                  : AppColors.green,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (hasDelete)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Hapus dari KRS',
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 21,
                    color: AppColors.red,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 10),

          // Chips info: Kelas, Jadwal, Ruang, Dosen
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (kelas.isNotEmpty)
                _mini(context, Icons.groups_rounded, 'Kls: $kelas'),
              if (hasSchedule)
                _mini(
                  context,
                  Icons.schedule_rounded,
                  hari.isNotEmpty && jam.isNotEmpty ? '$hari, $jam' : '$hari$jam',
                ),
              if (ruang.isNotEmpty)
                _mini(context, Icons.meeting_room_outlined, 'R: $ruang'),
              if (dosen.isNotEmpty)
                _mini(context, Icons.person_outline_rounded, dosen),
            ],
          ),

          if (detailToken != null) ...[
            const SizedBox(height: 8),
            const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Lihat Detail Jadwal',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.upiYellowDeep,
                  ),
                ),
                SizedBox(width: 2),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 15,
                  color: AppColors.upiYellowDeep,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _mini(BuildContext context, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
      decoration: BoxDecoration(
        color: context.softFill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.5, color: AppColors.upiYellowDeep),
          const SizedBox(width: 4.5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

