import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../state/auth_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/smart.dart';
import '../widgets/common.dart';
import '../widgets/gradient_header.dart';

/// Halaman Profil Akademik Lengkap Mahasiswa:
/// Menampilkan Identitas, Informasi Akademik, Dosen PA, Kontak, Domisili,
/// dan Riwayat Sekolah serta formulir Ubah Profil akademik.
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
    final identitas = asMap(_data?['identitas']);
    final akademik = asMap(_data?['akademik']);

    final nama = pickString(identitas, ['nama', 'Nama'], auth.nama);
    final nim = pickString(akademik, ['nim', 'NIM'], auth.nim);
    final prodi = pickString(
        akademik, ['program_studi', 'prodi', 'Program Studi'], 'Mahasiswa');
    final fakultas = pickString(akademik, ['fakultas', 'Fakultas'], '');
    final status = pickString(akademik, ['status', 'Status'], 'Aktif');

    return Scaffold(
      backgroundColor: context.bg,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: GradientHeader(
                title: 'Profil Akademik',
                subtitle: 'Biodata & riwayat kemahasiswaan',
                tall: true,
                leading: Navigator.of(context).canPop()
                    ? const HeaderBackButton()
                    : null,
                actions: [
                  HeaderActionButton(
                    icon: Icons.refresh_rounded,
                    tooltip: 'Muat Ulang',
                    onPressed: _fetchProfil,
                  ),
                  HeaderActionButton(
                    icon: Icons.edit_note_rounded,
                    tooltip: 'Ubah Biodata',
                    onPressed: _openEditSheet,
                  ),
                ],
                bottom: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 62,
                          height: 62,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: AppColors.logoGradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Text(
                            initialsOf(nama),
                            style: const TextStyle(
                              color: AppColors.indigo950,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nama,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  InkWell(
                                    onTap: () => copyText(context, nim),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'NIM $nim',
                                            style: const TextStyle(
                                              color: AppColors.amberLight,
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(Icons.copy_rounded,
                                              size: 11,
                                              color: AppColors.amberLight),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.amber.withValues(alpha: 0.25),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                          color: AppColors.amber.withValues(alpha: 0.5)),
                                    ),
                                    child: Text(
                                      status.toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (prodi.isNotEmpty || fakultas.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  [prodi, fakultas]
                                      .where((s) => s.isNotEmpty)
                                      .join(' • '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.82),
                                    fontSize: 12,
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
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverTabHeaderDelegate(
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  indicatorColor: AppColors.upiYellowBright,
                  indicatorWeight: 3.5,
                  labelColor: AppColors.indigo700,
                  unselectedLabelColor: context.textMuted,
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  tabAlignment: TabAlignment.start,
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.school_rounded, size: 18),
                      text: 'Akademik & PA',
                    ),
                    Tab(
                      icon: Icon(Icons.badge_rounded, size: 18),
                      text: 'Identitas Diri',
                    ),
                    Tab(
                      icon: Icon(Icons.contact_phone_rounded, size: 18),
                      text: 'Kontak & Domisili',
                    ),
                    Tab(
                      icon: Icon(Icons.account_balance_rounded, size: 18),
                      text: 'Asal Sekolah',
                    ),
                  ],
                ),
                backgroundColor: context.bg,
                borderColor: context.border,
              ),
            ),
          ];
        },
        body: _loading
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
                      _buildAkademikTab(),
                      _buildIdentitasTab(),
                      _buildKontakTab(),
                      _buildSekolahTab(),
                    ],
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openEditSheet,
        backgroundColor: AppColors.upiYellowDeep,
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.edit_rounded, size: 19),
        label: const Text(
          'Ubah Profil',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
      ),
    );
  }

  // ========================================================== TAB 1: AKADEMIK & PA

  Widget _buildAkademikTab() {
    final akademik = asMap(_data?['akademik']);
    final pa = asMap(_data?['pa']);

    final paNama = pickString(pa, ['nama', 'Nama', 'dosen'], '');
    final paInfoList = (pa['info'] is List)
        ? (pa['info'] as List).map((e) => e.toString()).toList()
        : <String>[];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      children: [
        // Card Dosen PA Spesial
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.upiYellowDeep.withValues(alpha: 0.12),
                AppColors.upiYellowBright.withValues(alpha: 0.06),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.upiYellowBright.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.upiYellowDeep,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.supervised_user_circle_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pembimbing Akademik (Dosen PA)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.upiYellowDeep,
                          ),
                        ),
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
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                for (final info in paInfoList)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 15, color: AppColors.upiYellowDeep),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            info,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textMuted,
                              height: 1.25,
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
        const SizedBox(height: 18),

        const SectionTitle('Informasi Program & Status'),
        const SizedBox(height: 10),
        SurfaceCard(
          child: Column(
            children: [
              _infoTile(
                  icon: Icons.badge_outlined,
                  label: 'NIM',
                  value: pickString(akademik, ['nim', 'NIM'], '-'),
                  copyable: true),
              _infoTile(
                  icon: Icons.account_balance_outlined,
                  label: 'Fakultas',
                  value: pickString(akademik, ['fakultas', 'Fakultas'], '-')),
              _infoTile(
                  icon: Icons.school_outlined,
                  label: 'Program Studi',
                  value: pickString(
                      akademik, ['program_studi', 'Program Studi', 'prodi'], '-')),
              _infoTile(
                  icon: Icons.stairs_outlined,
                  label: 'Jenjang Studi',
                  value: pickString(akademik, ['jenjang', 'Jenjang'], 'S1')),
              _infoTile(
                  icon: Icons.calendar_today_outlined,
                  label: 'Angkatan',
                  value: pickString(akademik, ['angkatan', 'Angkatan'], '-')),
              _infoTile(
                  icon: Icons.event_repeat_outlined,
                  label: 'Semester Masuk / Aktif',
                  value: pickString(akademik,
                      ['semester', 'Semester', 'semester_aktif'], '-')),
              _infoTile(
                  icon: Icons.verified_user_outlined,
                  label: 'Status Mahasiswa',
                  value: pickString(akademik, ['status', 'Status'], 'Aktif')),
              // Tampilkan field tambahan jika ada
              for (final entry in akademik.entries)
                if (!_isStandardAkademikKey(entry.key) &&
                    entry.value != null &&
                    entry.value is! Map &&
                    entry.value is! List)
                  _infoTile(
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

  Widget _buildIdentitasTab() {
    final identitas = asMap(_data?['identitas']);

    final jkRaw = pickString(identitas, ['jenis_kelamin', 'Jenis Kelamin'], '-');
    final jkLabel = jkRaw.toUpperCase() == 'L'
        ? 'Laki-laki (L)'
        : (jkRaw.toUpperCase() == 'P' ? 'Perempuan (P)' : jkRaw);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      children: [
        const SectionTitle('Biodata Pribadi'),
        const SizedBox(height: 10),
        SurfaceCard(
          child: Column(
            children: [
              _infoTile(
                icon: Icons.credit_card_rounded,
                label: 'NIK (Nomor Induk Kependudukan)',
                value: pickString(identitas, ['nik', 'NIK'], '-'),
                copyable: true,
              ),
              _infoTile(
                icon: Icons.person_outline_rounded,
                label: 'Nama Lengkap',
                value: pickString(identitas, ['nama', 'Nama'], '-'),
              ),
              _infoTile(
                icon: Icons.wc_rounded,
                label: 'Jenis Kelamin',
                value: jkLabel,
              ),
              _infoTile(
                icon: Icons.location_city_outlined,
                label: 'Tempat Lahir',
                value: pickString(identitas, ['tempat_lahir', 'Tempat Lahir'], '-'),
              ),
              _infoTile(
                icon: Icons.cake_outlined,
                label: 'Tanggal Lahir',
                value: pickString(identitas, ['tanggal_lahir', 'Tanggal Lahir'], '-'),
              ),
              _infoTile(
                icon: Icons.temple_buddhist_outlined,
                label: 'Agama',
                value: pickString(identitas, ['agama', 'Agama'], '-'),
              ),
              _infoTile(
                icon: Icons.flag_outlined,
                label: 'Warga Negara',
                value: pickString(identitas, ['warga_negara', 'Warga Negara'], 'WNI'),
              ),
              _infoTile(
                icon: Icons.public_rounded,
                label: 'Kebangsaan',
                value: pickString(identitas, ['kebangsaan', 'Kebangsaan'], 'Indonesia'),
              ),
              // Field ekstra
              for (final entry in identitas.entries)
                if (!_isStandardIdentitasKey(entry.key) &&
                    entry.value != null &&
                    entry.value is! Map &&
                    entry.value is! List)
                  _infoTile(
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

  Widget _buildKontakTab() {
    final kontak = asMap(_data?['kontak']);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      children: [
        const SectionTitle('Kontak Mahasiswa'),
        const SizedBox(height: 10),
        SurfaceCard(
          child: Column(
            children: [
              _infoTile(
                icon: Icons.email_outlined,
                label: 'Email',
                value: pickString(kontak, ['email', 'Email'], '-'),
                copyable: true,
              ),
              _infoTile(
                icon: Icons.phone_android_rounded,
                label: 'No. Handphone / WhatsApp',
                value: pickString(kontak, ['handphone', 'hp', 'Handphone'], '-'),
                copyable: true,
              ),
              _infoTile(
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
        SurfaceCard(
          child: Column(
            children: [
              _infoTile(
                icon: Icons.home_outlined,
                label: 'Alamat Lengkap',
                value: pickString(kontak, ['alamat', 'Alamat'], '-'),
              ),
              _infoTile(
                icon: Icons.location_city_rounded,
                label: 'Kota / Kabupaten',
                value: pickString(kontak, ['kota', 'Kota'], '-'),
              ),
              _infoTile(
                icon: Icons.map_outlined,
                label: 'Provinsi',
                value: pickString(kontak, ['propinsi', 'provinsi', 'Propinsi'], '-'),
              ),
              _infoTile(
                icon: Icons.markunread_mailbox_outlined,
                label: 'Kode Pos',
                value: pickString(kontak, ['kode_pos', 'Kode Pos'], '-'),
              ),
              _infoTile(
                icon: Icons.public_outlined,
                label: 'Negara',
                value: pickString(kontak, ['negara', 'Negara'], 'Indonesia'),
              ),
              // Field ekstra
              for (final entry in kontak.entries)
                if (!_isStandardKontakKey(entry.key) &&
                    entry.value != null &&
                    entry.value is! Map &&
                    entry.value is! List)
                  _infoTile(
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

  Widget _buildSekolahTab() {
    final sekolah = asMap(_data?['sekolah']);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      children: [
        const SectionTitle('Pendidikan Terakhir / Sekolah Asal'),
        const SizedBox(height: 10),
        SurfaceCard(
          child: Column(
            children: [
              _infoTile(
                icon: Icons.account_balance_outlined,
                label: 'Nama Sekolah Asal',
                value: pickString(sekolah, ['asal_sekolah', 'Asal Sekolah'], '-'),
              ),
              _infoTile(
                icon: Icons.category_outlined,
                label: 'Jurusan / Peminatan',
                value: pickString(sekolah, ['jurusan_sekolah', 'Jurusan Sekolah'], '-'),
              ),
              _infoTile(
                icon: Icons.location_on_outlined,
                label: 'Kota Sekolah',
                value: pickString(sekolah, ['kota_sekolah', 'Kota Sekolah'], '-'),
              ),
              _infoTile(
                icon: Icons.history_edu_outlined,
                label: 'Tahun Kelulusan',
                value: pickString(sekolah, ['tahun_lulus', 'Tahun Lulus'], '-'),
              ),
              // Field ekstra
              for (final entry in sekolah.entries)
                if (!_isStandardSekolahKey(entry.key) &&
                    entry.value != null &&
                    entry.value is! Map &&
                    entry.value is! List)
                  _infoTile(
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

  // ------------------------------------------------------------- Tile Helper

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
    bool copyable = false,
  }) {
    final isEmpty = value.trim().isEmpty || value == '-' || value == 'null';
    final displayValue = isEmpty ? 'Belum diisi' : value;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.upiYellowDeep.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: AppColors.upiYellowDeep),
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
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.copy_rounded, size: 16),
              color: AppColors.upiYellowDeep,
              tooltip: 'Salin',
              onPressed: () => copyText(context, value),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- Key Filter Helpers

  bool _isStandardAkademikKey(String k) {
    final lk = k.toLowerCase().replaceAll(' ', '_');
    return ['nim', 'fakultas', 'program_studi', 'prodi', 'jenjang', 'angkatan', 'semester', 'semester_aktif', 'status'].contains(lk);
  }

  bool _isStandardIdentitasKey(String k) {
    final lk = k.toLowerCase().replaceAll(' ', '_');
    return ['nik', 'nama', 'jenis_kelamin', 'tempat_lahir', 'tanggal_lahir', 'agama', 'warga_negara', 'kebangsaan'].contains(lk);
  }

  bool _isStandardKontakKey(String k) {
    final lk = k.toLowerCase().replaceAll(' ', '_');
    return ['email', 'handphone', 'hp', 'telepon', 'alamat', 'kota', 'propinsi', 'provinsi', 'kode_pos', 'negara'].contains(lk);
  }

  bool _isStandardSekolahKey(String k) {
    final lk = k.toLowerCase().replaceAll(' ', '_');
    return ['asal_sekolah', 'jurusan_sekolah', 'kota_sekolah', 'tahun_lulus'].contains(lk);
  }
}

// ============================================================ SLIVER TAB BAR DELEGATE

class _SliverTabHeaderDelegate extends SliverPersistentHeaderDelegate {
  _SliverTabHeaderDelegate(this._tabBar,
      {required this.backgroundColor, required this.borderColor});

  final TabBar _tabBar;
  final Color backgroundColor;
  final Color borderColor;

  @override
  double get minExtent => _tabBar.preferredSize.height + 1;

  @override
  double get maxExtent => _tabBar.preferredSize.height + 1;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabHeaderDelegate oldDelegate) {
    return false;
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
                      value: _agama,
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

