import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/dashboard_service.dart';
import '../state/auth_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/smart.dart';
import '../widgets/common.dart';
import 'download_screen.dart';
import 'foto_ijazah_screen.dart';
import 'jadwal_screen.dart';
import 'kalender_screen.dart';
import 'kartu_ujian_screen.dart';
import 'khs_screen.dart';
import 'krs_screen.dart';
import 'materi_screen.dart';
import 'presensi_screen.dart';
import 'profil_akademik_screen.dart';
import 'tagihan_screen.dart';
import 'transkrip_screen.dart';

/// Beranda: sambutan, ringkasan akademik, akses cepat semua modul.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _tick = 0;

  Future<Map<String, dynamic>> _dashboard() async {
    try {
      final api = context.read<ApiClient>();
      final resp = await DashboardService(api).getDashboard();
      final data = resp is Map ? (resp['data'] ?? resp) : resp;
      return asMap(data);
    } catch (_) {
      return {};
    }
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 11) return 'Selamat pagi';
    if (h < 15) return 'Selamat siang';
    if (h < 19) return 'Selamat sore';
    return 'Selamat malam';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: context.bg,
      body: RefreshIndicator(
        color: AppColors.indigo700,
        backgroundColor: Colors.white,
        onRefresh: () async {
          setState(() => _tick++);
        },
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _header(auth.nama, auth.nim),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              child: FutureBuilder<Map<String, dynamic>>(
                key: ValueKey('dash-$_tick'),
                future: _dashboard(),
                builder: (context, snap) {
                  final data = snap.data ?? const <String, dynamic>{};
                  final stats = _extractStats(data, auth.user);
                  final jadwals = _extractJadwalHariIni(data);
                  final notes = _extractNotices(data);
                  final isLoading = snap.connectionState == ConnectionState.waiting;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isLoading)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.all(Radius.circular(4)),
                            child: LinearProgressIndicator(
                              minHeight: 3,
                              color: AppColors.upiYellowDeep,
                              backgroundColor: Colors.transparent,
                            ),
                          ),
                        ),

                      // 1. Ringkasan IPK / SKS / Periode
                      if (stats.isNotEmpty) ...[
                        _buildStatsRow(stats),
                        const SizedBox(height: 14),
                      ],

                      // 2. CTA Tagihan & Pembayaran
                      _tagihanCta(context),
                      const SizedBox(height: 18),

                      // 3. Layanan Akademik (8 Grid Items)
                      const SectionTitle('Layanan Akademik'),
                      const SizedBox(height: 10),
                      _menuGrid(context),
                      const SizedBox(height: 20),

                      // 4. Jadwal Kuliah Hari Ini
                      _buildJadwalHariIniSection(context, jadwals,
                          isLoading: isLoading),
                      const SizedBox(height: 20),

                      // 5. Pengumuman
                      if (notes.isNotEmpty) ...[
                        _buildPengumumanSection(context, notes),
                      ],

                      if (data.isNotEmpty &&
                          stats.isEmpty &&
                          notes.isEmpty &&
                          jadwals.isEmpty)
                        SurfaceCard(child: SmartJsonCompact(data: data)),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------- header

  Widget _header(String nama, String nim) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.headerGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -34,
            top: -26,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.amber.withValues(alpha: 0.14),
              ),
            ),
          ),
          Positioned(
            right: 90,
            bottom: -30,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _greeting(),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          nama,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.13),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.22)),
                          ),
                          child: Text(
                            'NIM $nim',
                            style: const TextStyle(
                              color: AppColors.amberLight,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ProfilAkademikScreen(),
                      ),
                    ),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: AppColors.logoGradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        initialsOf(nama),
                        style: const TextStyle(
                          color: AppColors.indigo950,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------ ringkasan stats

  Widget _buildStatsRow(List<Widget> stats) {
    if (stats.length <= 3) {
      return Row(
        children: [
          for (var i = 0; i < stats.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: stats[i]),
          ],
        ],
      );
    }
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.2,
      children: stats,
    );
  }

  List<Widget> _extractStats(Map<String, dynamic> data,
      [Map<String, dynamic>? userFallback]) {
    final merged = <String, dynamic>{};
    if (userFallback != null) merged.addAll(userFallback);
    merged.addAll(data);
    if (merged.isEmpty) return const [];
    final widgets = <Widget>[];
    void add(String label, dynamic v, IconData icon, Color color) {
      if (v == null) return;
      final s = v.toString().trim();
      if (s.isEmpty || s == 'null' || s == '-') return;
      widgets.add(StatCard(label: label, value: s, icon: icon, color: color));
    }

    add('IPK', deepFind(merged, ['ipk']), Icons.school_rounded,
        AppColors.upiYellowDeep);
    add('SKS', deepFind(merged, ['total_sks', 'sks', 'sks_lulus']),
        Icons.grid_view_rounded, AppColors.green);
    add('Periode',
        deepFind(merged, ['periode', 'periode_aktif', 'semester', 'smt']),
        Icons.event_note_rounded,
        AppColors.amber);
    return widgets;
  }

  // ------------------------------------------------------ jadwal hari ini

  List<Map<String, dynamic>> _extractJadwalHariIni(Map<String, dynamic> data) {
    if (data.isEmpty) return const [];
    return deepFindMapList(
        data, ['jadwal_hari_ini', 'jadwal', 'today_schedule']);
  }

  Widget _buildJadwalHariIniSection(
      BuildContext context, List<Map<String, dynamic>> jadwals,
      {bool isLoading = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          'Jadwal Kuliah Hari Ini',
          trailing: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const JadwalScreen()),
            ),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text(
              'Lihat Semua',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.upiYellowDeep,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        if (isLoading && jadwals.isEmpty)
          SurfaceCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.upiYellowDeep,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Memuat jadwal kuliah hari ini...',
                  style: TextStyle(fontSize: 12, color: context.textMuted),
                ),
              ],
            ),
          )
        else if (jadwals.isEmpty)
          SurfaceCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.event_available_rounded,
                      size: 22, color: AppColors.green),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tidak ada jadwal kuliah hari ini',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Jadwal perkuliahan hari ini kosong.',
                        style:
                            TextStyle(fontSize: 11.5, color: context.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          for (final j in jadwals)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SurfaceCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.access_time_rounded,
                              size: 14, color: AppColors.upiYellowDeep),
                          const SizedBox(height: 3),
                          Text(
                            pickString(j, ['jam', 'waktu'], '-'),
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.upiYellowDeep,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pickString(
                                j, ['matkul', 'nama_matkul'], 'Mata Kuliah'),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: context.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (pickString(j, ['kode_kelas', 'kelas'], '')
                                  .isNotEmpty) ...[
                                Text(
                                  pickString(j, ['kode_kelas', 'kelas'], ''),
                                  style: TextStyle(
                                      fontSize: 11, color: context.textMuted),
                                ),
                                const SizedBox(width: 8),
                              ],
                              if (pickString(j, ['ruang', 'ruangan'], '')
                                  .isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: context.isDark
                                        ? Colors.white10
                                        : const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.room_rounded,
                                          size: 11, color: context.textMuted),
                                      const SizedBox(width: 3),
                                      Text(
                                        pickString(
                                            j, ['ruang', 'ruangan'], ''),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: context.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  // ------------------------------------------------------ pengumuman

  List<Map<String, dynamic>> _extractNotices(Map<String, dynamic> data) {
    if (data.isEmpty) return const [];
    return deepFindMapList(
        data, ['pengumuman', 'notices', 'notice', 'informasi', 'berita']);
  }

  Widget _buildPengumumanSection(
      BuildContext context, List<Map<String, dynamic>> notes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Pengumuman'),
        const SizedBox(height: 8),
        for (final n in notes.take(3))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SurfaceCard(
              padding: const EdgeInsets.all(13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.campaign_rounded,
                          size: 17, color: AppColors.orange),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          pickString(n,
                              ['judul', 'title', 'nama', 'keterangan'], 'Pengumuman'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: context.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    pickString(n,
                        ['isi', 'deskripsi', 'konten', 'keterangan', 'text'], ''),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: context.textMuted),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------- CTA

  Widget _tagihanCta(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const TagihanScreen()),
      ),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.indigo900, AppColors.indigo500],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.indigo700.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.receipt_long_rounded,
                  color: AppColors.amberLight, size: 22),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tagihan & Pembayaran',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Cek status tagihan, VA, dan riwayat bayar',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.amber, size: 26),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- menu

  Widget _menuGrid(BuildContext context) {
    final menus = [
      (
        label: 'KRS',
        icon: Icons.assignment_rounded,
        color: AppColors.indigo500,
        page: const KrsScreen()
      ),
      (
        label: 'Jadwal',
        icon: Icons.calendar_month_rounded,
        color: AppColors.upiYellowDeep,
        page: const JadwalScreen()
      ),
      (
        label: 'Presensi',
        icon: Icons.fact_check_rounded,
        color: AppColors.green,
        page: const PresensiScreen()
      ),
      (
        label: 'Materi',
        icon: Icons.menu_book_rounded,
        color: AppColors.orange,
        page: const MateriScreen()
      ),
      (
        label: 'Kartu Ujian',
        icon: Icons.badge_rounded,
        color: AppColors.red,
        page: const KartuUjianScreen()
      ),
      (
        label: 'KHS',
        icon: Icons.grade_rounded,
        color: AppColors.amber,
        page: const KhsScreen()
      ),
      (
        label: 'Transkrip',
        icon: Icons.workspace_premium_rounded,
        color: AppColors.indigo700,
        page: const TranskripScreen()
      ),
      (
        label: 'Kalender',
        icon: Icons.event_note_rounded,
        color: Colors.teal,
        page: const KalenderScreen()
      ),
      (
        label: 'Download',
        icon: Icons.cloud_download_rounded,
        color: Colors.blueAccent,
        page: const DownloadScreen()
      ),
      (
        label: 'Profil Akd',
        icon: Icons.school_rounded,
        color: AppColors.upiYellowDark,
        page: const ProfilAkademikScreen()
      ),
      (
        label: 'Foto Ijazah',
        icon: Icons.account_box_rounded,
        color: Colors.redAccent,
        page: const FotoIjazahScreen()
      ),
    ];

    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.82,
      children: [
        for (final m in menus)
          MenuTile(
            label: m.label,
            icon: m.icon,
            color: m.color,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => m.page),
            ),
          ),
      ],
    );
  }
}

/// SmartJson ringkas khusus dashboard (tanpa nested expansion default).
class SmartJsonCompact extends StatelessWidget {
  const SmartJsonCompact({super.key, required this.data});
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
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final e in rows)
          KeyValueRow(
            label: labelify(e.key),
            value: e.value.toString(),
          ),
      ],
    );
  }
}
