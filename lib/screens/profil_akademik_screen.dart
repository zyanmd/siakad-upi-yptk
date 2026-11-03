import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../state/auth_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/smart.dart';
import '../widgets/common.dart';

const _yellowHeaderGradient = [
  Color(0xFFE5A620), // Bright Academic Gold
  Color(0xFFD48B08), // UPI Yellow
  Color(0xFFB87500), // Deep Academic Gold
];

/// Halaman Profil Akademik Lengkap Mahasiswa:
/// Menampilkan Identitas, Informasi Akademik, Dosen PA, Kontak, Domisili,
/// dan Riwayat Sekolah serta formulir Ubah Profil akademik bergaya Neumorphic UI.
class ProfilAkademikScreen extends StatefulWidget {
  const ProfilAkademikScreen({super.key});

  @override
  State<ProfilAkademikScreen> createState() => _ProfilAkademikScreenState();
}

class _ProfilAkademikScreenState extends State<ProfilAkademikScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchProfil();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchProfil() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = context.read<ApiClient>();
      final resp = await api.get('/api/akademik/profil');
      final raw = resp is Map ? (resp['data'] ?? resp) : resp;
      if (!mounted) return;
      setState(() {
        _data = asMap(raw);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorText(e);
        _loading = false;
      });
    }
  }

  Future<void> _openEditSheet() async {
    if (_data == null) {
      appToast(context, 'Data profil belum termuat.', error: true);
      return;
    }

    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditProfilAkademikSheet(initialData: _data!),
    );

    if (updated == true && mounted) {
      appToast(context, 'Profil akademik berhasil diperbarui!');
      _fetchProfil();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = context.isDark;
    final bg = context.bg;

    final identitas = asMap(_data?['identitas']);
    final akademik = asMap(_data?['akademik']);

    final nama = pickString(identitas, ['nama', 'Nama'], auth.nama);
    final nim = pickString(akademik, ['nim', 'NIM'], auth.nim);
    final prodi = pickString(
        akademik, ['program_studi', 'prodi', 'Program Studi'], 'Mahasiswa');
    final fakultas = pickString(akademik, ['fakultas', 'Fakultas'], '');
    final status = pickString(akademik, ['status', 'Status'], 'Aktif');

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          // ──── HEADER KUNING DENGAN LEKUKAN BERSAMBUNG & FLOATING PILL TABS ────
          Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              _buildCurvedYellowHeader(
                nama: nama,
                nim: nim,
                prodi: prodi,
                fakultas: fakultas,
                status: status,
              ),
              Positioned(
                bottom: -18,
                left: 0,
                right: 0,
                child: _buildPillTabBar(context, isDark),
              ),
            ],
          ),
          const SizedBox(height: 26),

          // ──── TAB BAR VIEW CONTENT ────
          Expanded(
            child: _loading
                ? const Center(
                    child: LoadingView(label: 'Memuat profil akademik...'))
                : _error != null
                    ? ErrorRetry(
                        message: _error!,
                        onRetry: _fetchProfil,
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildAkademikTab(isDark),
                          _buildIdentitasTab(isDark),
                          _buildKontakTab(isDark),
                          _buildSekolahTab(isDark),
                        ],
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openEditSheet,
        backgroundColor: AppColors.upiYellowDeep,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.edit_rounded, size: 19),
        label: const Text(
          'Ubah Profil',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────── HEADER KUNING DENGAN LEKUKAN BERSAMBUNG
  Widget _buildCurvedYellowHeader({
    required String nama,
    required String nim,
    required String prodi,
    required String fakultas,
    required String status,
  }) {
    final canPop = Navigator.of(context).canPop();

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
            padding: const EdgeInsets.fromLTRB(22, 12, 22, kCurvedHeaderBottomPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Baris Atas: Tombol Back + Judul Halaman + Tombol Aksi
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (canPop) ...[
                          IconButton(
                            onPressed: () {
                              Navigator.of(context).maybePop();
                            },
                            icon: const Icon(Icons.arrow_back_rounded,
                                color: Colors.white, size: 24),
                            tooltip: 'Kembali',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 8),
                        ],
                        const Text(
                          'Profil Akademik',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ],
                    ),
                    // Action Buttons (Ubah Biodata & Refresh)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IosBounceTap(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _openEditSheet();
                          },
                          child: Container(
                            width: 40,
                            height: 40,
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
                            child: const Icon(
                              Icons.edit_rounded,
                              size: 19,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IosBounceTap(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _fetchProfil();
                            appToast(context, 'Memuat ulang data profil...');
                          },
                          child: Container(
                            width: 40,
                            height: 40,
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
                            child: const Icon(
                              Icons.refresh_rounded,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Baris Profil: Lingkaran Inisial (54x54) + Nama, NIM, Status
                Row(
                  children: [
                    Container(
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
                    const SizedBox(width: 14),

                    // Teks Nama Mahasiswa & Subtitle
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
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                nim.isNotEmpty ? 'NIM $nim' : '-',
                                style: const TextStyle(
                                  color: Color(0xE6FFFFFF),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'UPI YPTK',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: AppColors.green.withValues(alpha: 0.90),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (prodi.isNotEmpty || fakultas.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              [prodi, fakultas].where((s) => s.isNotEmpty).join(' • '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xCCFFFFFF),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
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

  // ────────────────────────────────────────────────── FLOATING PILL TAB BAR
  Widget _buildPillTabBar(BuildContext context, bool isDark) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.40)
                  : Colors.black.withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.center,
          padding: EdgeInsets.zero,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            color: isDark ? const Color(0xFF2C2C30) : AppColors.primaryYellow,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.4)
                    : AppColors.primaryYellow.withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          labelColor: isDark ? Colors.white : const Color(0xFF1C1917),
          unselectedLabelColor:
              isDark ? const Color(0xFF8E8E93) : const Color(0xFF78716C),
          dividerColor: Colors.transparent,
          labelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
          tabs: const [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.school_rounded, size: 15),
                  SizedBox(width: 6),
                  Text('Akademik & PA'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.badge_rounded, size: 15),
                  SizedBox(width: 6),
                  Text('Identitas Diri'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.contact_phone_rounded, size: 15),
                  SizedBox(width: 6),
                  Text('Kontak & Domisili'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.account_balance_rounded, size: 15),
                  SizedBox(width: 6),
                  Text('Asal Sekolah'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────── NEUMORPHIC CARD HELPER
  Widget _buildNeuCard({
    required BuildContext context,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    final isDark = context.isDark;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.border,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.35)
                : const Color(0xFF94A3B8).withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
          if (!isDark)
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.9),
              blurRadius: 10,
              offset: const Offset(-2, -2),
            ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildMetricMiniBox(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    final isDark = context.isDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.border,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : const Color(0xFF94A3B8).withValues(alpha: 0.10),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: context.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: context.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ========================================================== TAB 1: AKADEMIK & PA

  Widget _buildAkademikTab(bool isDark) {
    final akademik = asMap(_data?['akademik']);
    final pa = asMap(_data?['pa']);

    final paNama = pickString(pa, ['nama', 'Nama', 'dosen'], '');
    final paInfoList = (pa['info'] is List)
        ? (pa['info'] as List).map((e) => e.toString()).toList()
        : <String>[];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      children: [
        // 1. VIP Card Dosen PA Neumorphic
        _buildNeuCard(
          context: context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE5A620), Color(0xFFB87500)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.upiYellowDeep.withValues(alpha: 0.30),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.supervised_user_circle_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.upiYellowDeep
                                    .withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Pembimbing Akademik (Dosen PA)',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.upiYellowDeep,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          paNama.isNotEmpty
                              ? paNama
                              : 'Belum ditentukan / Dalam proses',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: context.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (paInfoList.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 10),
                for (final info in paInfoList)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 15, color: AppColors.upiYellowDeep),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            info,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textMuted,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2. Mini Metric Capsules
        Row(
          children: [
            Expanded(
              child: _buildMetricMiniBox(
                context,
                icon: Icons.check_circle_rounded,
                iconColor: AppColors.green,
                title: 'Status',
                value: pickString(akademik, ['status', 'Status'], 'Aktif'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricMiniBox(
                context,
                icon: Icons.school_rounded,
                iconColor: AppColors.upiYellowDeep,
                title: 'Jenjang',
                value: pickString(akademik, ['jenjang', 'Jenjang'], 'S1'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricMiniBox(
                context,
                icon: Icons.calendar_today_rounded,
                iconColor: const Color(0xFF0284C7),
                title: 'Angkatan',
                value: pickString(akademik, ['angkatan', 'Angkatan'], '-'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 3. Detail Akademik Card
        const SectionTitle('Informasi Program & Status'),
        const SizedBox(height: 10),
        _buildNeuCard(
          context: context,
          child: Column(
            children: [
              _infoTile(
                context: context,
                icon: Icons.badge_outlined,
                label: 'NIM',
                value: pickString(akademik, ['nim', 'NIM'], '-'),
                copyable: true,
              ),
              _infoTile(
                context: context,
                icon: Icons.account_balance_outlined,
                label: 'Fakultas',
                value: pickString(akademik, ['fakultas', 'Fakultas'], '-'),
              ),
              _infoTile(
                context: context,
                icon: Icons.school_outlined,
                label: 'Program Studi',
                value: pickString(akademik,
                    ['program_studi', 'Program Studi', 'prodi'], '-'),
              ),
              _infoTile(
                context: context,
                icon: Icons.stairs_outlined,
                label: 'Jenjang Studi',
                value: pickString(akademik, ['jenjang', 'Jenjang'], 'S1'),
              ),
              _infoTile(
                context: context,
                icon: Icons.calendar_today_outlined,
                label: 'Angkatan',
                value: pickString(akademik, ['angkatan', 'Angkatan'], '-'),
              ),
              _infoTile(
                context: context,
                icon: Icons.event_repeat_outlined,
                label: 'Semester Masuk / Aktif',
                value: pickString(akademik,
                    ['semester', 'Semester', 'semester_aktif'], '-'),
              ),
              _infoTile(
                context: context,
                icon: Icons.verified_user_outlined,
                label: 'Status Mahasiswa',
                value: pickString(akademik, ['status', 'Status'], 'Aktif'),
              ),
              // Dynamic fields
              for (final entry in akademik.entries)
                if (!_isStandardAkademikKey(entry.key) &&
                    entry.value != null &&
                    entry.value is! Map &&
                    entry.value is! List)
                  _infoTile(
                    context: context,
                    icon: Icons.check_circle_outline_rounded,
                    label: labelify(entry.key),
                    value: entry.value.toString(),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  // ========================================================== TAB 2: IDENTITAS DIRI

  Widget _buildIdentitasTab(bool isDark) {
    final identitas = asMap(_data?['identitas']);
    final nik = pickString(identitas, ['nik', 'NIK'], '');

    final jkRaw = pickString(identitas, ['jenis_kelamin', 'Jenis Kelamin'], '-');
    final jkLabel = jkRaw.toUpperCase() == 'L'
        ? 'Laki-laki (L)'
        : (jkRaw.toUpperCase() == 'P' ? 'Perempuan (P)' : jkRaw);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      children: [
        // 1. NIK Security Badge Card
        _buildNeuCard(
          context: context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.verified_user_rounded,
                            color: AppColors.green, size: 16),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Terverifikasi PDDikti Kemdikbud',
                        style: TextStyle(
                          color: AppColors.green,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  if (nik.isNotEmpty && nik != '-')
                    IosBounceTap(
                      onTap: () => copyText(context, nik),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color:
                              AppColors.upiYellowDeep.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.copy_rounded,
                                size: 12, color: AppColors.upiYellowDeep),
                            SizedBox(width: 4),
                            Text(
                              'Salin NIK',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.upiYellowDeep,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Nomor Induk Kependudukan (NIK)',
                style: TextStyle(fontSize: 11.5, color: context.textMuted),
              ),
              const SizedBox(height: 4),
              Text(
                nik.isNotEmpty ? nik : 'Belum diisi',
                style: TextStyle(
                  fontSize: 18,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color:
                      nik.isNotEmpty ? context.textPrimary : context.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Biodata Pribadi Card
        const SectionTitle('Biodata Pribadi'),
        const SizedBox(height: 10),
        _buildNeuCard(
          context: context,
          child: Column(
            children: [
              _infoTile(
                context: context,
                icon: Icons.person_outline_rounded,
                label: 'Nama Lengkap',
                value: pickString(identitas, ['nama', 'Nama'], '-'),
              ),
              _infoTile(
                context: context,
                icon: Icons.wc_rounded,
                label: 'Jenis Kelamin',
                value: jkLabel,
              ),
              _infoTile(
                context: context,
                icon: Icons.location_city_outlined,
                label: 'Tempat Lahir',
                value: pickString(
                    identitas, ['tempat_lahir', 'Tempat Lahir'], '-'),
              ),
              _infoTile(
                context: context,
                icon: Icons.cake_outlined,
                label: 'Tanggal Lahir',
                value: pickString(
                    identitas, ['tanggal_lahir', 'Tanggal Lahir'], '-'),
              ),
              _infoTile(
                context: context,
                icon: Icons.temple_buddhist_outlined,
                label: 'Agama',
                value: pickString(identitas, ['agama', 'Agama'], '-'),
              ),
              _infoTile(
                context: context,
                icon: Icons.flag_outlined,
                label: 'Warga Negara',
                value: pickString(
                    identitas, ['warga_negara', 'Warga Negara'], 'WNI'),
              ),
              _infoTile(
                context: context,
                icon: Icons.public_rounded,
                label: 'Kebangsaan',
                value: pickString(
                    identitas, ['kebangsaan', 'Kebangsaan'], 'Indonesia'),
              ),
              // Dynamic fields
              for (final entry in identitas.entries)
                if (!_isStandardIdentitasKey(entry.key) &&
                    entry.value != null &&
                    entry.value is! Map &&
                    entry.value is! List)
                  _infoTile(
                    context: context,
                    icon: Icons.fingerprint_rounded,
                    label: labelify(entry.key),
                    value: entry.value.toString(),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  // ========================================================== TAB 3: KONTAK & DOMISILI

  Widget _buildKontakTab(bool isDark) {
    final kontak = asMap(_data?['kontak']);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      children: [
        const SectionTitle('Kontak Mahasiswa'),
        const SizedBox(height: 10),
        _buildNeuCard(
          context: context,
          child: Column(
            children: [
              _infoTile(
                context: context,
                icon: Icons.email_outlined,
                label: 'Email',
                value: pickString(kontak, ['email', 'Email'], '-'),
                copyable: true,
              ),
              _infoTile(
                context: context,
                icon: Icons.phone_android_rounded,
                label: 'No. Handphone / WhatsApp',
                value: pickString(
                    kontak, ['handphone', 'hp', 'Handphone'], '-'),
                copyable: true,
              ),
              _infoTile(
                context: context,
                icon: Icons.call_outlined,
                label: 'Telepon',
                value: pickString(kontak, ['telepon', 'Telepon'], '-'),
                copyable: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        const SectionTitle('Alamat & Tempat Tinggal'),
        const SizedBox(height: 10),
        _buildNeuCard(
          context: context,
          child: Column(
            children: [
              _infoTile(
                context: context,
                icon: Icons.home_outlined,
                label: 'Alamat Lengkap',
                value: pickString(kontak, ['alamat', 'Alamat'], '-'),
              ),
              _infoTile(
                context: context,
                icon: Icons.location_city_rounded,
                label: 'Kota / Kabupaten',
                value: pickString(kontak, ['kota', 'Kota'], '-'),
              ),
              _infoTile(
                context: context,
                icon: Icons.map_outlined,
                label: 'Provinsi',
                value: pickString(
                    kontak, ['propinsi', 'provinsi', 'Propinsi'], '-'),
              ),
              _infoTile(
                context: context,
                icon: Icons.markunread_mailbox_outlined,
                label: 'Kode Pos',
                value: pickString(kontak, ['kode_pos', 'Kode Pos'], '-'),
              ),
              _infoTile(
                context: context,
                icon: Icons.public_outlined,
                label: 'Negara',
                value: pickString(kontak, ['negara', 'Negara'], 'Indonesia'),
              ),
              // Dynamic fields
              for (final entry in kontak.entries)
                if (!_isStandardKontakKey(entry.key) &&
                    entry.value != null &&
                    entry.value is! Map &&
                    entry.value is! List)
                  _infoTile(
                    context: context,
                    icon: Icons.pin_drop_outlined,
                    label: labelify(entry.key),
                    value: entry.value.toString(),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  // ========================================================== TAB 4: ASAL SEKOLAH

  Widget _buildSekolahTab(bool isDark) {
    final sekolah = asMap(_data?['sekolah']);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      children: [
        const SectionTitle('Pendidikan Terakhir / Sekolah Asal'),
        const SizedBox(height: 10),
        _buildNeuCard(
          context: context,
          child: Column(
            children: [
              _infoTile(
                context: context,
                icon: Icons.account_balance_outlined,
                label: 'Nama Sekolah Asal',
                value: pickString(
                    sekolah, ['asal_sekolah', 'Asal Sekolah'], '-'),
              ),
              _infoTile(
                context: context,
                icon: Icons.category_outlined,
                label: 'Jurusan / Peminatan',
                value: pickString(
                    sekolah, ['jurusan_sekolah', 'Jurusan Sekolah'], '-'),
              ),
              _infoTile(
                context: context,
                icon: Icons.location_on_outlined,
                label: 'Kota Sekolah',
                value: pickString(
                    sekolah, ['kota_sekolah', 'Kota Sekolah'], '-'),
              ),
              _infoTile(
                context: context,
                icon: Icons.history_edu_outlined,
                label: 'Tahun Kelulusan',
                value:
                    pickString(sekolah, ['tahun_lulus', 'Tahun Lulus'], '-'),
              ),
              // Dynamic fields
              for (final entry in sekolah.entries)
                if (!_isStandardSekolahKey(entry.key) &&
                    entry.value != null &&
                    entry.value is! Map &&
                    entry.value is! List)
                  _infoTile(
                    context: context,
                    icon: Icons.school_outlined,
                    label: labelify(entry.key),
                    value: entry.value.toString(),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────── TILE HELPER
  Widget _infoTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    bool copyable = false,
  }) {
    final isEmpty = value.trim().isEmpty || value == '-' || value == 'null';
    final displayValue = isEmpty ? 'Belum diisi' : value;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.upiYellowDeep.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: AppColors.upiYellowDeep),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: context.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  displayValue,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: isEmpty ? context.textMuted : context.textPrimary,
                    fontStyle: isEmpty ? FontStyle.italic : FontStyle.normal,
                    fontWeight: isEmpty ? FontWeight.w400 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (copyable && !isEmpty)
            IosBounceTap(
              onTap: () => copyText(context, value),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.upiYellowDeep.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.copy_rounded,
                  size: 15,
                  color: AppColors.upiYellowDeep,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────── KEY FILTER HELPERS
  bool _isStandardAkademikKey(String k) {
    final lk = k.toLowerCase().replaceAll(' ', '_');
    return [
      'nim',
      'fakultas',
      'program_studi',
      'prodi',
      'jenjang',
      'angkatan',
      'semester',
      'semester_aktif',
      'status'
    ].contains(lk);
  }

  bool _isStandardIdentitasKey(String k) {
    final lk = k.toLowerCase().replaceAll(' ', '_');
    return [
      'nik',
      'nama',
      'jenis_kelamin',
      'tempat_lahir',
      'tanggal_lahir',
      'agama',
      'warga_negara',
      'kebangsaan'
    ].contains(lk);
  }

  bool _isStandardKontakKey(String k) {
    final lk = k.toLowerCase().replaceAll(' ', '_');
    return [
      'email',
      'handphone',
      'hp',
      'telepon',
      'alamat',
      'kota',
      'propinsi',
      'provinsi',
      'kode_pos',
      'negara'
    ].contains(lk);
  }

  bool _isStandardSekolahKey(String k) {
    final lk = k.toLowerCase().replaceAll(' ', '_');
    return [
      'asal_sekolah',
      'jurusan_sekolah',
      'kota_sekolah',
      'tahun_lulus'
    ].contains(lk);
  }
}

// ============================================================ SHEET EDIT PROFIL

class _EditProfilAkademikSheet extends StatefulWidget {
  const _EditProfilAkademikSheet({required this.initialData});

  final Map<String, dynamic> initialData;

  @override
  State<_EditProfilAkademikSheet> createState() =>
      _EditProfilAkademikSheetState();
}

class _EditProfilAkademikSheetState extends State<_EditProfilAkademikSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  late final TextEditingController _namaCtrl;
  late final TextEditingController _nikCtrl;
  late final TextEditingController _tempatLahirCtrl;
  late final TextEditingController _tglLahirCtrl;
  late final TextEditingController _wargaNegaraCtrl;
  late final TextEditingController _kebangsaanCtrl;

  late final TextEditingController _emailCtrl;
  late final TextEditingController _handphoneCtrl;
  late final TextEditingController _teleponCtrl;
  late final TextEditingController _alamatCtrl;
  late final TextEditingController _kotaCtrl;
  late final TextEditingController _propinsiCtrl;
  late final TextEditingController _kodePosCtrl;
  late final TextEditingController _negaraCtrl;

  late final TextEditingController _asalSekolahCtrl;
  late final TextEditingController _kotaSekolahCtrl;
  late final TextEditingController _jurusanSekolahCtrl;
  late final TextEditingController _tahunLulusCtrl;

  String _jenisKelamin = 'L';
  String _agama = 'Islam';

  static const _agamaOptions = [
    'Islam',
    'Kristen Protestan',
    'Katolik',
    'Hindu',
    'Buddha',
    'Khonghucu',
    'Lainnya',
  ];

  @override
  void initState() {
    super.initState();
    final identitas = asMap(widget.initialData['identitas']);
    final kontak = asMap(widget.initialData['kontak']);
    final sekolah = asMap(widget.initialData['sekolah']);

    _namaCtrl = TextEditingController(text: pickString(identitas, ['nama', 'Nama'], ''));
    _nikCtrl = TextEditingController(text: pickString(identitas, ['nik', 'NIK'], ''));
    _tempatLahirCtrl = TextEditingController(text: pickString(identitas, ['tempat_lahir', 'Tempat Lahir'], ''));
    _tglLahirCtrl = TextEditingController(text: pickString(identitas, ['tanggal_lahir', 'Tanggal Lahir'], ''));
    _wargaNegaraCtrl = TextEditingController(text: pickString(identitas, ['warga_negara', 'Warga Negara'], 'WNI'));
    _kebangsaanCtrl = TextEditingController(text: pickString(identitas, ['kebangsaan', 'Kebangsaan'], 'Indonesia'));

    final jk = pickString(identitas, ['jenis_kelamin', 'Jenis Kelamin'], 'L').toUpperCase();
    _jenisKelamin = (jk == 'P' || jk == 'PEREMPUAN') ? 'P' : 'L';

    final ag = pickString(identitas, ['agama', 'Agama'], 'Islam');
    _agama = _agamaOptions.contains(ag) ? ag : 'Islam';

    _emailCtrl = TextEditingController(text: pickString(kontak, ['email', 'Email'], ''));
    _handphoneCtrl = TextEditingController(text: pickString(kontak, ['handphone', 'hp', 'Handphone'], ''));
    _teleponCtrl = TextEditingController(text: pickString(kontak, ['telepon', 'Telepon'], ''));
    _alamatCtrl = TextEditingController(text: pickString(kontak, ['alamat', 'Alamat'], ''));
    _kotaCtrl = TextEditingController(text: pickString(kontak, ['kota', 'Kota'], ''));
    _propinsiCtrl = TextEditingController(text: pickString(kontak, ['propinsi', 'provinsi', 'Propinsi'], ''));
    _kodePosCtrl = TextEditingController(text: pickString(kontak, ['kode_pos', 'Kode Pos'], ''));
    _negaraCtrl = TextEditingController(text: pickString(kontak, ['negara', 'Negara'], 'Indonesia'));

    _asalSekolahCtrl = TextEditingController(text: pickString(sekolah, ['asal_sekolah', 'Asal Sekolah'], ''));
    _kotaSekolahCtrl = TextEditingController(text: pickString(sekolah, ['kota_sekolah', 'Kota Sekolah'], ''));
    _jurusanSekolahCtrl = TextEditingController(text: pickString(sekolah, ['jurusan_sekolah', 'Jurusan Sekolah'], ''));
    _tahunLulusCtrl = TextEditingController(text: pickString(sekolah, ['tahun_lulus', 'Tahun Lulus'], ''));
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _nikCtrl.dispose();
    _tempatLahirCtrl.dispose();
    _tglLahirCtrl.dispose();
    _wargaNegaraCtrl.dispose();
    _kebangsaanCtrl.dispose();
    _emailCtrl.dispose();
    _handphoneCtrl.dispose();
    _teleponCtrl.dispose();
    _alamatCtrl.dispose();
    _kotaCtrl.dispose();
    _propinsiCtrl.dispose();
    _kodePosCtrl.dispose();
    _negaraCtrl.dispose();
    _asalSekolahCtrl.dispose();
    _kotaSekolahCtrl.dispose();
    _jurusanSekolahCtrl.dispose();
    _tahunLulusCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    DateTime initial = DateTime(2003, 1, 1);
    final parts = _tglLahirCtrl.text.split('-');
    if (parts.length == 3) {
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y != null && m != null && d != null) {
        initial = DateTime(y, m, d);
      }
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1960),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.upiYellowDeep,
                  onPrimary: Colors.white,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final y = picked.year.toString().padLeft(4, '0');
      final m = picked.month.toString().padLeft(2, '0');
      final d = picked.day.toString().padLeft(2, '0');
      setState(() => _tglLahirCtrl.text = '$y-$m-$d');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final nama = _namaCtrl.text.trim();
    if (nama.isEmpty) {
      appToast(context, 'Nama lengkap wajib diisi.', error: true);
      return;
    }

    final nik = _nikCtrl.text.trim();
    if (nik.isNotEmpty && (!RegExp(r'^\d+$').hasMatch(nik) || nik.length > 16)) {
      appToast(context, 'NIK harus berupa angka maksimal 16 digit.', error: true);
      return;
    }

    final email = _emailCtrl.text.trim();
    if (email.isNotEmpty && !email.contains('@')) {
      appToast(context, 'Format email tidak valid.', error: true);
      return;
    }

    final tahunLulus = int.tryParse(_tahunLulusCtrl.text.trim());

    setState(() => _saving = true);

    final payload = <String, dynamic>{
      'nama': nama,
      if (nik.isNotEmpty) 'nik': nik,
      'jenis_kelamin': _jenisKelamin,
      'tempat_lahir': _tempatLahirCtrl.text.trim(),
      'tanggal_lahir': _tglLahirCtrl.text.trim(),
      'agama': _agama,
      'warga_negara': _wargaNegaraCtrl.text.trim(),
      'kebangsaan': _kebangsaanCtrl.text.trim(),
      'email': email,
      'handphone': _handphoneCtrl.text.trim(),
      'telepon': _teleponCtrl.text.trim(),
      'alamat': _alamatCtrl.text.trim(),
      'kota': _kotaCtrl.text.trim(),
      'propinsi': _propinsiCtrl.text.trim(),
      'kode_pos': _kodePosCtrl.text.trim(),
      'negara': _negaraCtrl.text.trim(),
      'asal_sekolah': _asalSekolahCtrl.text.trim(),
      'kota_sekolah': _kotaSekolahCtrl.text.trim(),
      'jurusan_sekolah': _jurusanSekolahCtrl.text.trim(),
      if (tahunLulus != null) 'tahun_lulus': tahunLulus,
    };

    try {
      final api = context.read<ApiClient>();
      await api.patch('/api/akademik/profil', body: payload);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      appToast(context, errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle bar
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: context.border,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 14),

            // Header sheet
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.upiYellowDeep.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.edit_note_rounded,
                        color: AppColors.upiYellowDeep, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ubah Profil Akademik',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Data yang diubah otomatis disimpan ke SIAKAD',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: context.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ),
            const Divider(height: 20),

            // Form Fields
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  children: [
                    // ================= Section 1
                    const Text('1. IDENTITAS DIRI',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.upiYellowDeep)),
                    const SizedBox(height: 10),

                    TextFormField(
                      controller: _namaCtrl,
                      decoration: appInput(context, 'Nama Lengkap *',
                          icon: Icons.person_rounded),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _nikCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 16,
                      decoration: appInput(context, 'NIK (16 Digit)',
                          icon: Icons.credit_card_rounded),
                    ),
                    const SizedBox(height: 6),

                    // Jenis Kelamin
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _jenisKelamin = 'L'),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _jenisKelamin == 'L'
                                    ? AppColors.upiYellowDeep
                                    : context.softFill,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _jenisKelamin == 'L'
                                      ? AppColors.upiYellowDeep
                                      : context.border,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.male_rounded,
                                    size: 18,
                                    color: _jenisKelamin == 'L'
                                        ? Colors.white
                                        : context.textMuted,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Laki-laki',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: _jenisKelamin == 'L'
                                          ? Colors.white
                                          : context.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _jenisKelamin = 'P'),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _jenisKelamin == 'P'
                                    ? AppColors.upiYellowDeep
                                    : context.softFill,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _jenisKelamin == 'P'
                                      ? AppColors.upiYellowDeep
                                      : context.border,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.female_rounded,
                                    size: 18,
                                    color: _jenisKelamin == 'P'
                                        ? Colors.white
                                        : context.textMuted,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Perempuan',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: _jenisKelamin == 'P'
                                          ? Colors.white
                                          : context.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _tempatLahirCtrl,
                            decoration: appInput(context, 'Tempat Lahir',
                                icon: Icons.location_city_rounded),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _tglLahirCtrl,
                            readOnly: true,
                            onTap: _pickDate,
                            decoration: appInput(context, 'Tgl Lahir',
                                icon: Icons.calendar_today_rounded),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Agama
                    DropdownButtonFormField<String>(
                      initialValue: _agama,
                      items: _agamaOptions
                          .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _agama = val ?? 'Islam'),
                      decoration: appInput(context, 'Agama',
                          icon: Icons.temple_buddhist_outlined),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _wargaNegaraCtrl,
                            decoration: appInput(context, 'Warga Negara',
                                icon: Icons.flag_outlined),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _kebangsaanCtrl,
                            decoration: appInput(context, 'Kebangsaan',
                                icon: Icons.public_outlined),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    // ================= Section 2
                    const Text('2. KONTAK & ALAMAT DOMISILI',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.upiYellowDeep)),
                    const SizedBox(height: 10),

                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: appInput(context, 'Email Aktif',
                          icon: Icons.email_rounded),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _handphoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: appInput(context, 'No. Handphone / WA',
                                icon: Icons.phone_android_rounded),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _teleponCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: appInput(context, 'Telepon',
                                icon: Icons.call_outlined),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _alamatCtrl,
                      maxLines: 2,
                      keyboardType: TextInputType.streetAddress,
                      decoration: appInput(context, 'Alamat Lengkap',
                          icon: Icons.home_rounded),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _kotaCtrl,
                            decoration: appInput(context, 'Kota / Kab.',
                                icon: Icons.location_city_outlined),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _propinsiCtrl,
                            decoration: appInput(context, 'Provinsi',
                                icon: Icons.map_outlined),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _kodePosCtrl,
                            keyboardType: TextInputType.number,
                            decoration: appInput(context, 'Kode Pos',
                                icon: Icons.markunread_mailbox_outlined),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _negaraCtrl,
                            decoration: appInput(context, 'Negara',
                                icon: Icons.public_rounded),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    // ================= Section 3
                    const Text('3. RIWAYAT PENDIDIKAN (SEKOLAH ASAL)',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.upiYellowDeep)),
                    const SizedBox(height: 10),

                    TextFormField(
                      controller: _asalSekolahCtrl,
                      decoration: appInput(context, 'Nama Sekolah Asal',
                          icon: Icons.account_balance_outlined),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _kotaSekolahCtrl,
                            decoration: appInput(context, 'Kota Sekolah',
                                icon: Icons.location_on_outlined),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _jurusanSekolahCtrl,
                            decoration: appInput(context, 'Jurusan Sekolah',
                                icon: Icons.category_outlined),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _tahunLulusCtrl,
                      keyboardType: TextInputType.number,
                      decoration: appInput(context, 'Tahun Lulus (Contoh: 2025)',
                          icon: Icons.history_edu_outlined),
                    ),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ),

            // Tombol Simpan
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.card,
                border: Border(top: BorderSide(color: context.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.upiYellowDeep,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_rounded, size: 19),
                      label: Text(
                        _saving ? 'Menyimpan...' : 'Simpan Perubahan',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 13.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

