import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/dashboard_service.dart';
import '../state/auth_provider.dart';
import '../state/periode_provider.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';
import '../utils/format.dart';
import '../utils/smart.dart';
import '../widgets/common.dart';
import 'chat_assistant_screen.dart';
import 'download_screen.dart';
import 'foto_ijazah_screen.dart';
import 'jadwal_screen.dart';
import 'kalender_screen.dart';
import 'kartu_qrcode_wisuda_screen.dart';
import 'kartu_ujian_screen.dart';
import 'khs_screen.dart';
import 'krs_screen.dart';
import 'materi_screen.dart';
import 'presensi_screen.dart';
import 'profil_akademik_screen.dart';
import 'tagihan_screen.dart';
import 'transkrip_screen.dart';

// ═══════════════════════════════════════════════════════════════════
//  NEUMORPHIC THEME HELPERS
// ═══════════════════════════════════════════════════════════════════

class Neu {
  static Color bg(BuildContext context) =>
      context.isDark ? const Color(0xFF19191D) : const Color(0xFFE8EBF3);

  static Color light(BuildContext context) =>
      context.isDark ? const Color(0xFF26262E) : Colors.white;

  static Color dark(BuildContext context) =>
      context.isDark ? const Color(0xFF0C0C0E) : const Color(0xFFCAD0DE);

  /// Shadow timbul ganda khas Neumorphic (soft light di atas-kiri, shadow di bawah-kanan)
  static List<BoxShadow> convex(BuildContext context,
      {double blur = 11, Offset offset = const Offset(4.5, 4.5), double opacity = 1.0}) {
    return [
      BoxShadow(
        color: light(context).withValues(alpha: opacity),
        offset: Offset(-offset.dx, -offset.dy),
        blurRadius: blur,
      ),
      BoxShadow(
        color: dark(context).withValues(alpha: opacity),
        offset: offset,
        blurRadius: blur,
      ),
    ];
  }

  /// Permukaan gradien convex untuk pantulan cahaya 3D realistis
  static LinearGradient surface(BuildContext context) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: context.isDark
          ? [const Color(0xFF222228), const Color(0xFF18181C)]
          : [const Color(0xFFEFF2F9), const Color(0xFFE0E5EF)],
    );
  }

  /// Permukaan gradien emas khusus kartu aktif/sorotan
  static const LinearGradient goldSurface = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFE5A620),
      Color(0xFFD48B08),
      Color(0xFFB87500),
    ],
  );
}

// ═══════════════════════════════════════════════════════════════════
//  DASHBOARD SCREEN
// ═══════════════════════════════════════════════════════════════════

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _tick = 0;
  int _categoryIndex = 0; // 0: Semua, 1: Jadwal Hari Ini, 2: Akademik, 3: Keuangan, 4: Wisuda

  static const List<Color> _yellowHeaderGradient = [
    Color(0xFFE5A620), // Bright Academic Gold
    Color(0xFFD48B08), // UPI Yellow
    Color(0xFFB87500), // Deep Academic Gold
  ];

  Future<Map<String, dynamic>> _dashboard() async {
    Map<String, dynamic> data = {};
    try {
      final api = context.read<ApiClient>();
      final resp = await DashboardService(api).getDashboard();
      final raw = resp is Map ? (resp['data'] ?? resp) : resp;
      data = asMap(raw);
    } catch (_) {
      data = {};
    }

    // Jika payload dashboard tidak memuat jadwal hari ini, ambil dari
    // endpoint jadwal khusus (/api/akademik/jadwal) yang dikelompokkan
    // per hari. Hal ini agar dashboard tetap menampilkan jadwal kuliah
    // hari ini walau endpoint /api/dashboard tidak menyertakannya.
    try {
      final existing = _extractJadwalHariIni(data);
      if (existing.isEmpty) {
        final fromJadwal = await _fetchJadwalHariIni();
        if (fromJadwal.isNotEmpty) {
          data = {...data, 'jadwal_hari_ini': fromJadwal};
        }
      }
    } catch (_) {
      // Abaikan: dashboard tetap tampil walau jadwal gagal dimuat.
    }

    return data;
  }

  /// Ambil jadwal hari ini langsung dari endpoint akademik (`/api/akademik/jadwal`),
  /// lalu normalisasi field agar cocok dengan kartu timeline di dashboard.
  Future<List<Map<String, dynamic>>> _fetchJadwalHariIni() async {
    final api = context.read<ApiClient>();
    final pp = context.read<PeriodeProvider>();
    if (!pp.loaded) {
      await pp.ensureLoaded();
    }
    final periode = pp.value ?? fallbackPeriode();

    final resp = await api.get('/api/akademik/jadwal', query: {'periode': periode});
    final raw = resp is Map ? (resp['data'] ?? resp) : resp;
    final mapData = asMap(raw);

    // Sumber utama: data['jadwal'] berupa Map per hari.
    final rawJadwal = mapData['jadwal'] is Map ? mapData['jadwal'] : mapData;
    final groups = mapOfLists(asMap(rawJadwal));

    const dayMap = {
      1: ['senin', 'mon', 'monday'],
      2: ['selasa', 'tue', 'tuesday'],
      3: ['rabu', 'wed', 'wednesday'],
      4: ['kamis', 'thu', 'thursday'],
      5: ['jumat', "jum'at", 'fri', 'friday'],
      6: ['sabtu', 'sat', 'saturday'],
      7: ['minggu', 'ahad', 'sun', 'sunday'],
    };
    final todayAliases = dayMap[DateTime.now().weekday] ?? [];

    List<Map<String, dynamic>> items = [];
    for (final entry in groups.entries) {
      final dayKey = entry.key.toString().toLowerCase().trim();
      if (todayAliases.any((alias) => dayKey.contains(alias))) {
        items = entry.value;
        break;
      }
    }

    // Fallback: jika data berbentuk list datar dengan field hari.
    if (items.isEmpty) {
      final flat = findMapList(asMap(rawJadwal));
      items = flat.where((m) {
        final h = pickString(m, ['hari', 'nama_hari', 'day', 'hari_kuliah'], '')
            .toLowerCase()
            .trim();
        return h.isNotEmpty && todayAliases.any((alias) => h.contains(alias));
      }).toList();
    }

    return items.map(_normalizeJadwalItem).toList();
  }

  /// Samakan nama field dari endpoint jadwal ke field yang dibaca kartu
  /// timeline dashboard (`jam`, `matkul`, `ruang`, `jenis`, `dosen`, `kelas`).
  Map<String, dynamic> _normalizeJadwalItem(Map<String, dynamic> item) {
    final out = <String, dynamic>{...item};

    final jamMulai = pickString(
        item, ['waktu_mulai', 'jam_mulai', 'jam_mulai_kuliah'], '');
    final jamSelesai = pickString(
        item, ['waktu_selesai', 'jam_selesai', 'jam_selesai_kuliah'], '');

    String time = pickString(out, ['jam', 'waktu', 'jam_kuliah'], '');
    if (time.isEmpty) {
      if (jamMulai.isNotEmpty && jamSelesai.isNotEmpty) {
        time = '$jamMulai – $jamSelesai';
      } else if (jamMulai.isNotEmpty) {
        time = jamMulai;
      }
    }
    if (time.isNotEmpty) out['jam'] = time;

    if (pickString(out, ['matkul', 'nama_matkul'], '').isEmpty) {
      final mk = pickString(
          item, ['matkul', 'nama_mk', 'nm_mk', 'mata_kuliah', 'nama', 'mk'], '');
      if (mk.isNotEmpty) out['matkul'] = mk;
    }

    if (pickString(out, ['ruang', 'ruangan'], '').isEmpty) {
      final ruang = pickString(item, ['ruang', 'ruangan', 'lokasi'], '');
      if (ruang.isNotEmpty) out['ruang'] = ruang;
    }

    if (pickString(out, ['jenis', 'tipe', 'type'], '').isEmpty) {
      final kelas = pickString(item, ['kelas', 'nama_kelas'], '');
      out['jenis'] = kelas.isNotEmpty ? 'Kelas $kelas' : 'Kuliah';
    }

    return out;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = context.isDark;
    final bg = isDark ? const Color(0xFF000000) : const Color(0xFFF9FAFB);

    return Scaffold(
      backgroundColor: bg,
      body: RefreshIndicator(
        color: AppColors.upiYellowDeep,
        backgroundColor: bg,
        onRefresh: () async {
          setState(() => _tick++);
        },
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            // ──── HEADER KUNING DENGAN LEKUKAN BERSAMBUNG & FLOATING PILLS ────
            Stack(
              alignment: Alignment.bottomCenter,
              clipBehavior: Clip.none,
              children: [
                _buildCurvedYellowHeader(auth.nama, auth.nim),
                Positioned(
                  bottom: -18,
                  left: 0,
                  right: 0,
                  child: _buildCategoryPills(context),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ──── KONTEN DASHBOARD MODERN ────
            ResponsiveCenter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 96),
                child: FutureBuilder<Map<String, dynamic>>(
                  key: ValueKey('dash-$_tick'),
                  future: _dashboard(),
                  builder: (context, snap) {
                    final data = snap.data ?? const <String, dynamic>{};
                    final stats = _extractStats(data, auth.user);
                    final jadwals = _extractJadwalHariIni(data);
                    final notes = _extractNotices(data);
                    final isLoading =
                        snap.connectionState == ConnectionState.waiting;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isLoading)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 14),
                            child: ClipRRect(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(6)),
                              child: LinearProgressIndicator(
                                minHeight: 3.5,
                                color: AppColors.upiYellowDeep,
                                backgroundColor: Colors.transparent,
                              ),
                            ),
                          ),

                        // Carousel Kartu Unggulan & Progress
                        if (_categoryIndex == 0) ...[
                          _buildFeaturedCardsCarousel(
                              context, data, auth.user, jadwals),
                          const SizedBox(height: 18),
                          _buildAcademicProgressBanner(context, data, auth.user),
                          const SizedBox(height: 22),
                        ],

                        // Konten sesuai Kategori Terpilih
                        if (_categoryIndex == 1) ...[
                          // Kategori: Jadwal Hari Ini
                          _buildJadwalTimeline(context, jadwals,
                              isLoading: isLoading),
                          const SizedBox(height: 20),
                          if (stats.isNotEmpty) ...[
                            _buildStatsRow(stats),
                            const SizedBox(height: 18),
                          ],
                        ] else if (_categoryIndex == 0) ...[
                          // Kategori: Semua
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Layanan Kampus',
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  color: context.isDark
                                      ? Colors.white
                                      : const Color(0xFF1C1917),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const Text(
                                'UPI YPTK',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.upiYellowDeep,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildLayananKampusSection(context),
                          const SizedBox(height: 24),
                          _buildJadwalTimeline(context, jadwals,
                              isLoading: isLoading),
                          const SizedBox(height: 20),
                          if (stats.isNotEmpty) ...[
                            _buildStatsRow(stats),
                            const SizedBox(height: 18),
                          ],
                          _tagihanCta(context),
                          const SizedBox(height: 22),
                          if (notes.isNotEmpty)
                            _buildPengumumanSection(context, notes),
                        ] else ...[
                          // Kategori Spesifik (Akademik, Keuangan, Layanan Lain)
                          Text(
                            _categoryIndex == 2
                                ? 'Layanan Akademik'
                                : _categoryIndex == 3
                                    ? 'Keuangan & Administrasi'
                                    : 'Layanan Lainnya',
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: context.isDark
                                  ? Colors.white
                                  : const Color(0xFF1C1917),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildLayananKampusSection(context),
                          const SizedBox(height: 20),
                          if (_categoryIndex == 3) _tagihanCta(context),
                        ],

                        if (data.isNotEmpty &&
                            stats.isEmpty &&
                            notes.isEmpty &&
                            jadwals.isEmpty)
                          _NeuCard(child: SmartJsonCompact(data: data)),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────── HEADER KUNING DENGAN LEKUKAN BERSAMBUNG
  Widget _buildCurvedYellowHeader(String nama, String nim) {
    return ClipPath(
      clipper: const SeamlessWaveClipper(),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: _yellowHeaderGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                22, 12, 22, kCurvedHeaderBottomPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Baris Atas: Judul/Branding SIAKAD & Tombol Reload
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.school_rounded,
                              size: 19, color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'SIAKAD Mobile',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ],
                    ),
                    // Tombol Reload
                    IosBounceTap(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _tick++);
                        appToast(context, 'Memuat ulang data beranda...');
                      },
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.10),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.refresh_rounded,
                            size: 20, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Baris Profil: Lingkaran Avatar/Inisial (54x54) + Nama & NIM
                Row(
                  children: [
                    IosBounceTap(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ProfilAkademikScreen(),
                        ),
                      ),
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.85),
                            width: 1.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            initialsOf(nama),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nama.isNotEmpty ? nama : 'Mahasiswa UPI YPTK',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            nim.isNotEmpty
                                ? 'NIM $nim • UPI YPTK Padang'
                                : 'Portal Akademik Mahasiswa',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.92),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
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
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────── CATEGORY PILLS (KAPSUL FILTER HORIZONTAL)
  //  Disamakan dengan gaya Floating Pill Tab Bar pada Tagihan:
  //  container putih/gelap rounded 30, pill aktif memakai gradien kuning UPI & rounded 26.
  Widget _buildCategoryPills(BuildContext context) {
    final isDark = context.isDark;
    final categories = [
      (label: 'Semua', icon: Icons.grid_view_rounded),
      (label: 'Jadwal Hari Ini', icon: Icons.today_rounded),
      (label: 'Akademik', icon: Icons.school_rounded),
      (label: 'Keuangan', icon: Icons.account_balance_wallet_rounded),
      (label: 'Layanan Lain', icon: Icons.widgets_rounded),
    ];

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.30)
                  : Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(categories.length, (i) {
              final isSelected = _categoryIndex == i;
              final cat = categories[i];
              return IosBounceTap(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _categoryIndex = i);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? const LinearGradient(
                            colors: _yellowHeaderGradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.upiYellowDeep
                                  .withValues(alpha: 0.30),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        cat.icon,
                        size: 14.5,
                        color: isSelected
                            ? Colors.white
                            : (isDark
                                ? const Color(0xFF98989F)
                                : const Color(0xFF6B7280)),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        cat.label,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          letterSpacing: -0.2,
                          color: isSelected
                              ? Colors.white
                              : (isDark
                                  ? const Color(0xFF98989F)
                                  : const Color(0xFF6B7280)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────── HELPER STATUS WAKTU JADWAL
  bool _isSchedulePassed(Map<String, dynamic> item) {
    try {
      String rawEnd = pickString(
          item, ['waktu_selesai', 'jam_selesai', 'jam_selesai_kuliah'], '');
      rawEnd = rawEnd.replaceFirst('s.d. ', '').replaceFirst('sd ', '').trim();

      if (rawEnd.isEmpty) {
        final timeStr =
            pickString(item, ['jam', 'waktu', 'jam_kuliah'], '');
        final parts = timeStr.split(RegExp(r'[-–—~]'));
        if (parts.length >= 2) {
          rawEnd = parts[1].trim();
        } else if (parts.isNotEmpty) {
          rawEnd = parts[0].trim();
        }
      }

      if (rawEnd.isEmpty) return false;

      final match = RegExp(r'(\d{1,2})[:.](\d{2})').firstMatch(rawEnd);
      if (match != null) {
        final hour = int.tryParse(match.group(1)!);
        final minute = int.tryParse(match.group(2)!);
        if (hour != null && minute != null) {
          final now = DateTime.now();
          final currentMinutes = now.hour * 60 + now.minute;
          final endMinutes = hour * 60 + minute;
          return currentMinutes >= endMinutes;
        }
      }
    } catch (_) {}
    return false;
  }

  bool _isScheduleOngoing(Map<String, dynamic> item) {
    try {
      String rawStart = pickString(
          item, ['waktu_mulai', 'jam_mulai', 'jam_mulai_kuliah'], '');
      String rawEnd = pickString(
          item, ['waktu_selesai', 'jam_selesai', 'jam_selesai_kuliah'], '');
      rawEnd = rawEnd.replaceFirst('s.d. ', '').replaceFirst('sd ', '').trim();

      if (rawStart.isEmpty || rawEnd.isEmpty) {
        final timeStr =
            pickString(item, ['jam', 'waktu', 'jam_kuliah'], '');
        final parts = timeStr.split(RegExp(r'[-–—~]'));
        if (parts.length >= 2) {
          if (rawStart.isEmpty) rawStart = parts[0].trim();
          if (rawEnd.isEmpty) rawEnd = parts[1].trim();
        }
      }

      final matchStart = RegExp(r'(\d{1,2})[:.](\d{2})').firstMatch(rawStart);
      final matchEnd = RegExp(r'(\d{1,2})[:.](\d{2})').firstMatch(rawEnd);

      if (matchStart != null && matchEnd != null) {
        final startH = int.tryParse(matchStart.group(1)!);
        final startM = int.tryParse(matchStart.group(2)!);
        final endH = int.tryParse(matchEnd.group(1)!);
        final endM = int.tryParse(matchEnd.group(2)!);

        if (startH != null && startM != null && endH != null && endM != null) {
          final now = DateTime.now();
          final currentMinutes = now.hour * 60 + now.minute;
          final startMinutes = startH * 60 + startM;
          final endMinutes = endH * 60 + endM;
          return currentMinutes >= startMinutes && currentMinutes < endMinutes;
        }
      }
    } catch (_) {}
    return false;
  }

  // ────────────────────────────────────────────────── FEATURED CARDS CAROUSEL (DRIBBLE STYLE)
  Widget _buildFeaturedCardsCarousel(
    BuildContext context,
    Map<String, dynamic> data,
    Map<String, dynamic>? userFallback,
    List<Map<String, dynamic>> jadwals,
  ) {
    final isDark = context.isDark;

    // Ambil info jadwal hari ini jika ada
    final hasJadwal = jadwals.isNotEmpty;
    final ongoingJadwal =
        jadwals.where((j) => _isScheduleOngoing(j)).firstOrNull;
    final upcomingJadwal =
        jadwals.where((j) => !_isSchedulePassed(j)).firstOrNull;
    final activeJadwal =
        ongoingJadwal ?? upcomingJadwal ?? (hasJadwal ? jadwals.last : null);

    final isPassed = activeJadwal != null && _isSchedulePassed(activeJadwal);
    final isOngoing = activeJadwal != null && _isScheduleOngoing(activeJadwal);

    final matkulName = activeJadwal != null
        ? (activeJadwal['matkul'] ?? 'Perkuliahan')
        : 'Tidak Ada Jadwal Hari Ini';
    final jamStr =
        activeJadwal != null ? (activeJadwal['jam'] ?? '-') : 'Istirahat';
    final ruangStr =
        activeJadwal != null ? (activeJadwal['ruang'] ?? '-') : 'Online/Libur';

    final badgeLabel = !hasJadwal
        ? 'Agenda Hari Ini'
        : (isOngoing
            ? 'Sedang Berjalan'
            : (isPassed ? 'Selesai Hari Ini' : 'Jadwal Hari Ini'));

    final merged = <String, dynamic>{};
    if (userFallback != null) merged.addAll(userFallback);
    merged.addAll(data);

    final ipkRaw = deepFind(merged, ['ipk']);
    final sksRaw = deepFind(
        merged, ['total_sks', 'sks', 'sks_lulus', 'sks_kumulatif']);
    final ipkVal = (ipkRaw != null && ipkRaw.toString().trim().isNotEmpty)
        ? ipkRaw.toString()
        : '3.75';
    final sksVal = (sksRaw != null && sksRaw.toString().trim().isNotEmpty)
        ? '$sksRaw SKS'
        : '24 SKS';

    return SizedBox(
      height: 168,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          // Kartu 1: Jadwal Kuliah Hari Ini (Emas UPI YPTK)
          _buildFeaturedCardItem(
            context,
            badge: badgeLabel,
            badgeBg: Colors.white.withValues(alpha: 0.25),
            badgeTextColor: Colors.white,
            title: matkulName,
            titleStrikethrough: isPassed,
            subtitle: hasJadwal
                ? (activeJadwal?['dosen'] ??
                    activeJadwal?['jenis'] ??
                    'Kelas Reguler')
                : 'Tidak ada jam kuliah aktif hari ini',
            tag1Icon: Icons.access_time_rounded,
            tag1Text: jamStr,
            tag1Strikethrough: isPassed,
            tag2Icon: Icons.meeting_room_rounded,
            tag2Text: ruangStr,
            gradientColors: _yellowHeaderGradient,
            isLightText: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const JadwalScreen()),
            ),
          ),
          const SizedBox(width: 14),

          // Kartu 2: Status Akademik & Nilai (Dark Slate Elegan dengan aksen Emas)
          _buildFeaturedCardItem(
            context,
            badge: 'Semester Aktif',
            badgeBg: const Color(0xFFE5A620).withValues(alpha: 0.2),
            badgeTextColor: const Color(0xFFE5A620),
            title: 'KHS & Transkrip Akademik',
            subtitle: 'Pantau rekapitulasi nilai dan IPK',
            tag1Icon: Icons.star_rounded,
            tag1Text: 'IPK: $ipkVal',
            tag2Icon: Icons.menu_book_rounded,
            tag2Text: sksVal,
            gradientColors: isDark
                ? [const Color(0xFF2C2C2E), const Color(0xFF1C1C1E)]
                : [const Color(0xFF2C2C2E), const Color(0xFF1C1C1E)],
            isLightText: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const KhsScreen()),
            ),
          ),
          const SizedBox(width: 14),

          // Kartu 3: Keuangan & Tagihan Kuliah
          _buildFeaturedCardItem(
            context,
            badge: 'Administrasi',
            badgeBg: Colors.teal.withValues(alpha: 0.15),
            badgeTextColor: Colors.teal,
            title: 'Tagihan & Administrasi Kuliah',
            subtitle: 'Status pembayaran SPP dan praktikum',
            tag1Icon: Icons.account_balance_wallet_rounded,
            tag1Text: 'Cek Tagihan',
            tag2Icon: Icons.verified_rounded,
            tag2Text: 'Layanan BAAK',
            gradientColors: isDark
                ? [const Color(0xFF134E4A), const Color(0xFF042F2E)]
                : [const Color(0xFF0D9488), const Color(0xFF0F766E)],
            isLightText: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TagihanScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedCardItem(
    BuildContext context, {
    required String badge,
    required Color badgeBg,
    required Color badgeTextColor,
    required String title,
    bool titleStrikethrough = false,
    required String subtitle,
    required IconData tag1Icon,
    required String tag1Text,
    bool tag1Strikethrough = false,
    required IconData tag2Icon,
    required String tag2Text,
    required List<Color> gradientColors,
    required bool isLightText,
    required VoidCallback onTap,
  }) {
    return IosBounceTap(
      onTap: onTap,
      child: Container(
        width: 290,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: gradientColors.first.withValues(alpha: 0.28),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge Pill di atas
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: badgeTextColor,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color:
                        isLightText ? Colors.white : context.textPrimary,
                    letterSpacing: -0.3,
                    decoration: titleStrikethrough
                        ? TextDecoration.lineThrough
                        : null,
                    decorationColor:
                        isLightText ? Colors.white : context.textPrimary,
                    decorationThickness: 1.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: isLightText
                        ? Colors.white.withValues(alpha: 0.85)
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            // Tag Pills di Bawah Khas Gambar Dribbble
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(tag1Icon, size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                tag1Text,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  decoration: tag1Strikethrough
                                      ? TextDecoration.lineThrough
                                      : null,
                                  decorationColor: Colors.white,
                                  decorationThickness: 1.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(tag2Icon, size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                tag2Text,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Tombol Panah Lingkaran Khas Dribbble
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────── PROGRESS BANNER (DRIBBLE STYLE)
  Widget _buildAcademicProgressBanner(
    BuildContext context,
    Map<String, dynamic> data,
    Map<String, dynamic>? userFallback,
  ) {
    final isDark = context.isDark;

    final merged = <String, dynamic>{};
    if (userFallback != null) merged.addAll(userFallback);
    merged.addAll(data);

    final sksRaw = deepFind(
        merged, ['total_sks', 'sks', 'sks_lulus', 'sks_kumulatif']);
    double progress = 0.75;
    if (sksRaw != null) {
      final match = RegExp(r'\d+').firstMatch(sksRaw.toString());
      if (match != null) {
        final sksNum = double.tryParse(match.group(0)!);
        if (sksNum != null && sksNum > 0) {
          progress = (sksNum / 144.0).clamp(0.05, 1.0);
        }
      }
    }

    final percentText = '${(progress * 100).toInt()}% Selesai';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
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
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.upiYellowDeep.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.flag_rounded,
                  color: AppColors.upiYellowDeep,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kemajuan Studi Semester',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color:
                            isDark ? Colors.white : const Color(0xFF1C1917),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Target kelulusan & keaktifan perkuliahan',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark
                            ? const Color(0xFF98989F)
                            : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: AppColors.upiYellowDeep.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  percentText,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.upiYellowDeep,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              color: AppColors.upiYellowDeep,
              backgroundColor: isDark
                  ? const Color(0xFF2C2C2E)
                  : const Color(0xFFE2E8F0),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────── LAYANAN KAMPUS STYLE IPB (MIRIP GAMBAR KIRI)
  // ────────────────────────────────────────────────── LAYANAN KAMPUS (DRIBBLE & IPB STYLE)
  Widget _buildLayananKampusSection(BuildContext context) {
    final menus = [
      (
        label: 'KRS Online',
        desc: 'Rencana Studi',
        category: 'akademik',
        icon: Icons.assignment_rounded,
        color: const Color(0xFF3B82F6),
        page: const KrsScreen(),
      ),
      (
        label: 'Jadwal Kuliah',
        desc: 'Jadwal Mingguan',
        category: 'jadwal',
        icon: Icons.calendar_month_rounded,
        color: AppColors.upiYellowDeep,
        page: const JadwalScreen(),
      ),
      (
        label: 'Presensi',
        desc: 'Kehadiran Kuliah',
        category: 'akademik',
        icon: Icons.fact_check_rounded,
        color: AppColors.green,
        page: const PresensiScreen(),
      ),
      (
        label: 'Materi Kuliah',
        desc: 'Bahan Pembelajaran',
        category: 'akademik',
        icon: Icons.menu_book_rounded,
        color: AppColors.orange,
        page: const MateriScreen(),
      ),
      (
        label: 'Kartu Ujian',
        desc: 'UTS & UAS',
        category: 'akademik',
        icon: Icons.badge_rounded,
        color: AppColors.red,
        page: const KartuUjianScreen(),
      ),
      (
        label: 'KHS Mahasiswa',
        desc: 'Hasil Studi',
        category: 'akademik',
        icon: Icons.grade_rounded,
        color: const Color(0xFF8B5CF6),
        page: const KhsScreen(),
      ),
      (
        label: 'Transkrip Nilai',
        desc: 'Kumulatif Nilai',
        category: 'akademik',
        icon: Icons.workspace_premium_rounded,
        color: const Color(0xFF06B6D4),
        page: const TranskripScreen(),
      ),
      (
        label: 'Kalender Akd',
        desc: 'Agenda Kampus',
        category: 'akademik',
        icon: Icons.event_note_rounded,
        color: Colors.teal,
        page: const KalenderScreen(),
      ),
      (
        label: 'Tagihan Kuliah',
        desc: 'Pembayaran SPP',
        category: 'keuangan',
        icon: Icons.account_balance_wallet_rounded,
        color: Colors.teal,
        page: const TagihanScreen(),
      ),
      (
        label: 'Download Berkas',
        desc: 'Unduh Dokumen',
        category: 'lain',
        icon: Icons.cloud_download_rounded,
        color: Colors.blueAccent,
        page: const DownloadScreen(),
      ),
      (
        label: 'Profil Akademik',
        desc: 'Data Mahasiswa',
        category: 'lain',
        icon: Icons.school_rounded,
        color: AppColors.upiYellowDark,
        page: const ProfilAkademikScreen(),
      ),
      (
        label: 'Foto Ijazah',
        desc: 'Syarat Wisuda',
        category: 'lain',
        icon: Icons.account_box_rounded,
        color: Colors.redAccent,
        page: const FotoIjazahScreen(),
      ),
      (
        label: 'Kartu Wisuda',
        desc: 'QR Code Wisudawan',
        category: 'lain',
        icon: Icons.qr_code_2_rounded,
        color: const Color(0xFFD97706),
        page: const KartuQrCodeWisudaScreen(),
      ),
      (
        label: context.tr('assistant_ai', 'Asisten AI'),
        desc: 'Tanya Jawab Pintar',
        category: 'lain',
        icon: Icons.auto_awesome_rounded,
        color: AppColors.upiYellowDeep,
        page: const ChatAssistantScreen(),
      ),
    ];

    final filtered = menus.where((m) {
      if (_categoryIndex == 1) {
        return m.category == 'jadwal';
      } else if (_categoryIndex == 2) {
        return m.category == 'akademik';
      } else if (_categoryIndex == 3) {
        return m.category == 'keuangan';
      } else if (_categoryIndex == 4) {
        return m.category == 'lain';
      }
      return true;
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 36),
          child: Column(
            children: [
              Icon(Icons.widgets_outlined,
                  size: 46,
                  color: context.isDark ? Colors.white38 : Colors.grey.shade400),
              const SizedBox(height: 10),
              Text(
                'Tidak ada layanan yang sesuai',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color:
                      context.isDark ? Colors.white70 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.builder(
          itemCount: filtered.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.22,
          ),
          itemBuilder: (context, i) {
            final m = filtered[i];
            return _buildIpbStyleNeuCard(
              context,
              label: m.label,
              desc: m.desc,
              icon: m.icon,
              color: m.color,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => m.page),
              ),
            );
          },
        ),
      ],
    );
  }

  /// Kartu layanan modern khas Dribbble & IPB University
  Widget _buildIpbStyleNeuCard(
    BuildContext context, {
    required String label,
    required String desc,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = context.isDark;

    return IosBounceTap(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.35)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isDark ? 0.16 : 0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, size: 23, color: color),
                ),
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark
                        ? const Color(0xFF2C2C2E)
                        : const Color(0xFFF8FAFC),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 11,
                    color: isDark ? Colors.white70 : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: isDark ? Colors.white : const Color(0xFF1C1917),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDark
                        ? const Color(0xFF98989F)
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────── NEUMORPHIC JADWAL TIMELINE
  Widget _buildJadwalTimeline(
      BuildContext context, List<Map<String, dynamic>> jadwals,
      {bool isLoading = false}) {
    final now = DateTime.now();
    final dayNames = [
      'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'
    ];
    final dayLabel = dayNames[now.weekday - 1];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Seksi Jadwal
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.tr('today_schedule', 'Jadwal Kuliah Hari Ini'),
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: context.textPrimary,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const JadwalScreen()),
              ),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(
                context.tr('view_all', 'Lihat Semua'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.upiYellowDeep,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Loading
        if (isLoading && jadwals.isEmpty)
          _NeuCard(
            padding: const EdgeInsets.all(16),
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
                  style:
                      TextStyle(fontSize: 12, color: context.textMuted),
                ),
              ],
            ),
          )

        // Empty State: Tidak ada jadwal kuliah hari ini
        else if (jadwals.isEmpty)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Kolom Tanggal Kiri (Badge adaptif tema)
              Container(
                width: 52,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: context.isDark ? const Color(0xFF1C1C1E) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: context.isDark
                          ? Colors.black.withValues(alpha: 0.3)
                          : Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      dayLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${now.day}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: context.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Kartu Tidak Ada Jadwal (adaptif tema)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.isDark ? const Color(0xFF1C1C1E) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: context.isDark
                            ? Colors.black.withValues(alpha: 0.3)
                            : Colors.black.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.upiYellowDeep.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.hotel_class_rounded,
                            size: 24, color: AppColors.upiYellowDeep),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('no_class_title',
                                  'Tidak ada jadwal kuliah'),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                color: context.textPrimary,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              context.tr('no_class_subtitle',
                                  'Selamat istirahat ✨'),
                              style: TextStyle(
                                fontSize: 11.5,
                                color: context.textMuted,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          )

        // Timeline Daftar Kelas
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Kolom Tanggal Kiri (Badge adaptif tema)
              Container(
                width: 52,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: context.isDark ? const Color(0xFF1C1C1E) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: context.isDark
                          ? Colors.black.withValues(alpha: 0.3)
                          : Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      dayLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${now.day}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: context.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Garis Timeline Vertikal & Card Kelas
              Expanded(
                child: () {
                  final ongoingIndex =
                      jadwals.indexWhere((j) => _isScheduleOngoing(j));
                  final firstUpcomingIndex =
                      jadwals.indexWhere((j) => !_isSchedulePassed(j));
                  final activeIndex = ongoingIndex != -1
                      ? ongoingIndex
                      : (firstUpcomingIndex != -1 ? firstUpcomingIndex : -1);

                  return Column(
                    children: [
                      for (int i = 0; i < jadwals.length; i++)
                        _buildTimelineRowItem(
                          context,
                          jadwals[i],
                          position: i,
                          isLast: i == jadwals.length - 1,
                          isActive: i == activeIndex,
                        ),
                    ],
                  );
                }(),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildTimelineRowItem(
    BuildContext context,
    Map<String, dynamic> j, {
    required int position,
    required bool isLast,
    required bool isActive,
  }) {
    final time = pickString(j, ['jam', 'waktu'], '-');
    final matkul = pickString(j, ['matkul', 'nama_matkul'], 'Mata Kuliah');
    final ruang = pickString(j, ['ruang', 'ruangan'], '');
    final jenis = pickString(j, ['jenis', 'tipe', 'type'], 'Kuliah');

    final isPassed = _isSchedulePassed(j);
    final isDark = context.isDark;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Garis Vertikal & Dot
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 1.5,
                  height: 12,
                  color: position == 0
                      ? Colors.transparent
                      : (isDark ? Colors.white12 : const Color(0xFFD4D8E2)),
                ),
                Container(
                  width: isActive ? 14 : (isPassed ? 14 : 10),
                  height: isActive ? 14 : (isPassed ? 14 : 10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive
                        ? AppColors.upiYellowDeep
                        : isPassed
                            ? (isDark
                                ? const Color(0xFF2C2C2E)
                                : const Color(0xFFE2E8F0))
                            : (isDark
                                ? Colors.white24
                                : const Color(0xFF9E9E9E)),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color:
                                  AppColors.upiYellowDeep.withValues(alpha: 0.4),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: isPassed
                      ? Icon(
                          Icons.check_rounded,
                          size: 9,
                          color: isDark ? Colors.white54 : Colors.black45,
                        )
                      : null,
                ),
                Expanded(
                  child: isLast
                      ? const SizedBox.shrink()
                      : Container(
                          width: 1.5,
                          color: isDark
                              ? Colors.white12
                              : const Color(0xFFD4D8E2),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Kartu Jadwal Neumorphic
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: isActive
                  // Kartu Aktif (kuning emas UPI seperti tema aplikasi)
                  ? Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: _yellowHeaderGradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color:
                                AppColors.upiYellowDeep.withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  jenis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            matkul,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.schedule_rounded,
                                  size: 15, color: Colors.white),
                              const SizedBox(width: 6),
                              Text(
                                time != '-' ? time : 'Sekarang',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.95),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          if (ruang.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.room_rounded,
                                    size: 14, color: Colors.white),
                                const SizedBox(width: 6),
                                Text(
                                  ruang,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.90),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    )
                  // Card Biasa (adaptif tema)
                  : Builder(builder: (context) {
                      final cardWidget = Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.isDark
                              ? const Color(0xFF1C1C1E)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: context.isDark
                                  ? Colors.black.withValues(alpha: 0.3)
                                  : Colors.black.withValues(alpha: 0.06),
                              blurRadius: 12,
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
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: context.isDark
                                        ? const Color(0xFF2C2C2E)
                                        : const Color(0xFFF5F5F5),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    jenis,
                                    style: TextStyle(
                                      color: context.textMuted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (isPassed) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 3.5),
                                    decoration: BoxDecoration(
                                      color: (isDark
                                              ? Colors.white
                                              : Colors.black)
                                          .withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.check_circle_rounded,
                                          size: 11,
                                          color: context.textMuted,
                                        ),
                                        const SizedBox(width: 3.5),
                                        Text(
                                          'Selesai',
                                          style: TextStyle(
                                            color: context.textMuted,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              matkul,
                              style: TextStyle(
                                color: isPassed
                                    ? context.textMuted
                                    : context.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                                decoration:
                                    isPassed ? TextDecoration.lineThrough : null,
                                decorationColor: context.textMuted,
                                decorationThickness: 1.8,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.schedule_rounded,
                                    size: 15, color: context.textMuted),
                                const SizedBox(width: 6),
                                Text(
                                  time,
                                  style: TextStyle(
                                    color: context.textMuted,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    decoration: isPassed
                                        ? TextDecoration.lineThrough
                                        : null,
                                    decorationColor: context.textMuted,
                                    decorationThickness: 1.8,
                                  ),
                                ),
                              ],
                            ),
                            if (ruang.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.room_rounded,
                                      size: 14, color: context.textMuted),
                                  const SizedBox(width: 6),
                                  Text(
                                    ruang,
                                    style: TextStyle(
                                      color: context.textMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                      return isPassed
                          ? Opacity(opacity: 0.65, child: cardWidget)
                          : cardWidget;
                    }),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────── STATS ROW (IPK / SKS / Periode)
  Widget _buildStatsRow(List<Widget> stats) {
    if (stats.length <= 3) {
      return Row(
        children: [
          for (var i = 0; i < stats.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: stats[i]),
          ],
        ],
      );
    }
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
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
      widgets.add(_NeuStatCard(label: label, value: s, icon: icon, color: color));
    }

    add('IPK', deepFind(merged, ['ipk']), Icons.school_rounded,
        AppColors.upiYellowDeep);
    add('SKS', deepFind(merged, ['total_sks', 'sks', 'sks_lulus']),
        Icons.grid_view_rounded, AppColors.green);
    add(
        'Periode',
        deepFind(
            merged, ['periode', 'periode_aktif', 'semester', 'smt']),
        Icons.event_note_rounded,
        AppColors.amber);
    return widgets;
  }

  List<Map<String, dynamic>> _extractJadwalHariIni(Map<String, dynamic> data) {
    if (data.isEmpty) return const [];

    final now = DateTime.now();
    const dayMap = {
      1: ['senin', 'mon', 'monday'],
      2: ['selasa', 'tue', 'tuesday'],
      3: ['rabu', 'wed', 'wednesday'],
      4: ['kamis', 'thu', 'thursday'],
      5: ['jumat', "jum'at", 'fri', 'friday'],
      6: ['sabtu', 'sat', 'saturday'],
      7: ['minggu', 'ahad', 'sun', 'sunday'],
    };
    final todayAliases = dayMap[now.weekday] ?? [];

    // 1. Cek jika ada key eksplisit `jadwal_hari_ini` atau `today_schedule`
    for (final key in ['jadwal_hari_ini', 'today_schedule', 'jadwal_today']) {
      if (data.containsKey(key)) {
        final val = data[key];
        if (val is List) {
          if (val.isEmpty) return []; // Eksplisit kosong untuk hari ini
          return val.whereType<Map>().map((e) => asMap(e)).toList();
        }
      }
    }

    // 2. Cek jika data['jadwal'] adalah Map pengelompokan per hari
    final rawJadwal = data['jadwal'];
    if (rawJadwal is Map) {
      for (final entry in rawJadwal.entries) {
        final dayKey = entry.key.toString().toLowerCase().trim();
        if (todayAliases.any((alias) => dayKey.contains(alias))) {
          if (entry.value is List) {
            return (entry.value as List)
                .whereType<Map>()
                .map((e) => asMap(e))
                .toList();
          }
        }
      }
      return [];
    }

    // 3. Jika rawJadwal adalah list jadwal umum
    final list = deepFindMapList(data, ['jadwal', 'jadwal_kuliah', 'schedule']);
    if (list.isEmpty) return [];

    // Periksa apakah item di list memiliki field 'hari' atau 'day'
    final hasDayField = list.any((m) {
      final h = pickString(m, ['hari', 'nama_hari', 'day', 'hari_kuliah'], '');
      return h.isNotEmpty && h != '-';
    });

    if (hasDayField) {
      final filtered = list.where((m) {
        final h = pickString(m, ['hari', 'nama_hari', 'day', 'hari_kuliah'], '')
            .toLowerCase()
            .trim();
        return todayAliases.any((alias) => h.contains(alias));
      }).toList();
      return filtered;
    }

    if (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday) {
      return [];
    }

    return list;
  }

  List<Map<String, dynamic>> _extractNotices(Map<String, dynamic> data) {
    if (data.isEmpty) return const [];
    return deepFindMapList(
        data, ['pengumuman', 'notices', 'notice', 'informasi', 'berita']);
  }

  // ────────────────────────────────────────────────── PENGUMUMAN (ADAPTIF TEMA)
  Widget _buildPengumumanSection(
      BuildContext context, List<Map<String, dynamic>> notes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('announcement', 'Pengumuman'),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        for (final n in notes.take(3))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.isDark ? const Color(0xFF1C1C1E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: context.isDark
                        ? Colors.black.withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.campaign_rounded,
                          size: 18, color: AppColors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          pickString(
                              n,
                              ['judul', 'title', 'nama', 'keterangan'],
                              'Pengumuman'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            color: context.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    pickString(
                        n,
                        [
                          'isi',
                          'deskripsi',
                          'konten',
                          'keterangan',
                          'text'
                        ],
                        ''),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12, color: context.textMuted),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ────────────────────────────────────────────────── CTA TAGIHAN (ADAPTIF TEMA)
  Widget _tagihanCta(BuildContext context) {
    final isDark = context.isDark;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TagihanScreen()),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: _yellowHeaderGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.account_balance_wallet_rounded,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Keuangan & Tagihan Mahasiswa',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Cek status SPP, Virtual Account BSI & riwayat',
                    style: TextStyle(
                      color: context.textMuted,
                      fontSize: 11.5,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: context.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  WIDGETS CARD UMUM (ADAPTIF TEMA TERANG/GELAP)
// ═══════════════════════════════════════════════════════════════════

/// Kartu serbaguna adaptif tema yang bersih dan rapi
class _NeuCard extends StatelessWidget {
  const _NeuCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.border, width: 1),
        boxShadow: context.isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: child,
    );
  }
}

/// Stat Card untuk IPK, SKS, dan Periode
class _NeuStatCard extends StatelessWidget {
  const _NeuStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.border, width: 1),
        boxShadow: context.isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: context.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────── SMART JSON COMPACT
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
