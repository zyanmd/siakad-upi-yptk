import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/akademik_service.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../utils/smart.dart';
import '../widgets/common.dart';

/// Bottom sheet daftar mata kuliah yang bisa diambil (Section 03: Tambah KRS)
/// Sesuai dengan tampilan web SIAKAD UPI YPTK Padang:
/// - Badge section: 03 Tambah KRS
/// - Result badge: N jadwal (misal 217 jadwal)
/// - Simpan Pilihan (bulk submit)
/// - Selection summary banner (N jadwal dipilih dari beberapa halaman & Hapus Pilihan)
/// - Kolom & atribut: Mata Kuliah (Wajib/Pilihan), Semester, Kelas & Ruang,
///   Jadwal (Hari & Jam), Dosen Pengampu, Kapasitas (Terisi/Kuota),
///   Ketersediaan (Dapat dipilih vs Bentrok), dan Aksi.
class KrsPickSheet extends StatefulWidget {
  const KrsPickSheet({super.key, required this.periode, required this.onAdded});

  final String periode;
  final VoidCallback onAdded;

  @override
  State<KrsPickSheet> createState() => _KrsPickSheetState();
}

class _KrsPickSheetState extends State<KrsPickSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _selectedHari = '';
  String _selectedSemester = '';
  bool _hanyaDapatDipilih = false;
  int _page = 1;

  late Future<Map<String, dynamic>> _future;
  final Set<String> _busyTokens = <String>{};
  final Set<String> _selectedTokens = <String>{};
  bool _isSubmittingBulk = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _searchCtrl.addListener(() {
      if (mounted) setState(() => _query = _searchCtrl.text.trim());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _load() async {
    final api = context.read<ApiClient>();
    final resp = await AkademikService(api).krsAvailable(
      widget.periode,
      matakuliah: _query.isNotEmpty ? _query : null,
      semester: _selectedSemester.isNotEmpty ? _selectedSemester : null,
      hari: _selectedHari.isNotEmpty ? _selectedHari : null,
      page: _page,
    );
    final map = asMap(resp);
    final data = map['data'] ?? map;
    return asMap(data);
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _ambilSatu(Map<String, dynamic> item) async {
    final token = pickString(item, ['value', 'jadwal', 'token'], '');
    if (token.isEmpty) {
      appToast(context, 'Token jadwal tidak ditemukan.', error: true);
      return;
    }
    if (_busyTokens.contains(token)) return;

    setState(() => _busyTokens.add(token));
    try {
      final api = context.read<ApiClient>();
      final resp = await AkademikService(api).krsAdd({
        'periode': widget.periode,
        'jadwal': token,
      });
      final msg = resp is Map
          ? pickString(asMap(resp), ['message'],
              'Mata kuliah berhasil ditambahkan ke KRS.')
          : 'Mata kuliah berhasil ditambahkan.';
      if (!mounted) return;
      appToast(context, msg);
      widget.onAdded();
      _selectedTokens.remove(token);
      _refresh();
    } catch (e) {
      if (mounted) {
        appToast(context, errorText(e), error: true);
      }
    } finally {
      if (mounted) {
        setState(() => _busyTokens.remove(token));
      }
    }
  }

  Future<void> _ambilBulk() async {
    if (_selectedTokens.isEmpty || _isSubmittingBulk) return;
    setState(() => _isSubmittingBulk = true);

    try {
      final api = context.read<ApiClient>();
      final resp = await AkademikService(api).krsBulk({
        'periode': widget.periode,
        'jadwal': _selectedTokens.toList(),
      });
      final msg = resp is Map
          ? pickString(asMap(resp), ['message'],
              '${_selectedTokens.length} mata kuliah berhasil ditambahkan.')
          : '${_selectedTokens.length} mata kuliah berhasil ditambahkan.';
      if (!mounted) return;
      appToast(context, msg);
      widget.onAdded();
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        appToast(context, errorText(e), error: true);
        setState(() => _isSubmittingBulk = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: context.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 10),
          Container(
            width: 44,
            height: 4.5,
            decoration: BoxDecoration(
              color: context.border,
              borderRadius: BorderRadius.circular(3),
            ),
          ),

          // Header Section 03: Tambah KRS
          _buildSectionHeader(),

          // Selection Summary (Banner jika ada item dipilih)
          if (_selectedTokens.isNotEmpty) _buildSelectionSummaryBanner(),

          // Filter & Search Controls
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _searchCtrl,
              onSubmitted: (_) {
                _page = 1;
                _refresh();
              },
              decoration: appInput(
                context,
                'Cari mata kuliah, kode, atau dosen...',
                icon: Icons.search_rounded,
              ).copyWith(
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          _page = 1;
                          _refresh();
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Filter bar
          _buildFilterBar(),

          // List content
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const LoadingView(label: 'Memuat jadwal mata kuliah...');
                }
                if (snap.hasError) {
                  return ErrorRetry(
                    message: errorText(snap.error ?? 'Terjadi kesalahan.'),
                    onRetry: _refresh,
                  );
                }

                final data = snap.data ?? const <String, dynamic>{};
                final resultSummary = pickString(
                    data, ['result_summary', 'summary'], '');
                final totalPages = int.tryParse(
                        data['total_pages']?.toString() ?? '1') ?? 1;
                final currentPage = int.tryParse(
                        data['page']?.toString() ?? '1') ?? 1;

                List<Map<String, dynamic>> jadwalList =
                    deepFindMapList(data, ['jadwal', 'items', 'list']);

                // Filter client-side
                if (_hanyaDapatDipilih) {
                  jadwalList = jadwalList.where((m) {
                    final dapat = m['dapat_dipilih'];
                    final blocked = m['is_blocked'];
                    return dapat == true && blocked != true;
                  }).toList();
                }

                if (_query.isNotEmpty) {
                  final q = _query.toLowerCase();
                  jadwalList = jadwalList.where((m) {
                    final nama = pickString(m, ['nama', 'nama_mk']).toLowerCase();
                    final kode = pickString(m, ['kode', 'kode_mk']).toLowerCase();
                    final dosen = pickString(m, ['dosen']).toLowerCase();
                    return nama.contains(q) ||
                        kode.contains(q) ||
                        dosen.contains(q);
                  }).toList();
                }

                if (jadwalList.isEmpty) {
                  return EmptyView(
                    icon: Icons.search_off_rounded,
                    message: _query.isNotEmpty
                        ? 'Tidak ada jadwal yang cocok dengan "$_query".'
                        : 'Tidak ada jadwal mata kuliah tersedia pada filter ini.',
                  );
                }

                // Check how many items on this page can be picked
                final selectableOnPage = jadwalList.where((m) {
                  final val = pickString(m, ['value', 'jadwal', 'token'], '');
                  final dapat = m['dapat_dipilih'] == true;
                  final blocked = m['is_blocked'] == true;
                  return val.isNotEmpty && dapat && !blocked;
                }).toList();

                final allSelectableChecked = selectableOnPage.isNotEmpty &&
                    selectableOnPage.every((m) =>
                        _selectedTokens.contains(pickString(m, ['value', 'jadwal', 'token'], '')));

                return Column(
                  children: [
                    // Subheader: Summary text & Select-all toggle
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                      child: Row(
                        children: [
                          if (selectableOnPage.isNotEmpty) ...[
                            InkWell(
                              borderRadius: BorderRadius.circular(6),
                              onTap: () {
                                setState(() {
                                  if (allSelectableChecked) {
                                    for (final item in selectableOnPage) {
                                      final t = pickString(item, ['value', 'jadwal', 'token'], '');
                                      _selectedTokens.remove(t);
                                    }
                                  } else {
                                    for (final item in selectableOnPage) {
                                      final t = pickString(item, ['value', 'jadwal', 'token'], '');
                                      if (t.isNotEmpty) _selectedTokens.add(t);
                                    }
                                  }
                                });
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: Checkbox(
                                      value: allSelectableChecked,
                                      activeColor: AppColors.upiYellowDeep,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      onChanged: (v) {
                                        setState(() {
                                          if (v == true) {
                                            for (final item in selectableOnPage) {
                                              final t = pickString(item, ['value', 'jadwal', 'token'], '');
                                              if (t.isNotEmpty) _selectedTokens.add(t);
                                            }
                                          } else {
                                            for (final item in selectableOnPage) {
                                              final t = pickString(item, ['value', 'jadwal', 'token'], '');
                                              _selectedTokens.remove(t);
                                            }
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Pilih Semua di Hal Ini',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                          ],
                          if (resultSummary.isNotEmpty)
                            Text(
                              resultSummary,
                              style: TextStyle(
                                fontSize: 11,
                                color: context.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),

                    // List of schedules
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                        itemCount: jadwalList.length,
                        itemBuilder: (context, i) {
                          return _buildJadwalItemCard(jadwalList[i]);
                        },
                      ),
                    ),

                    if (totalPages > 1)
                      _buildPaginationBar(currentPage, totalPages),
                  ],
                );
              },
            ),
          ),

          // Bottom bulk bar
          if (_selectedTokens.isNotEmpty) _buildBulkActionBar(),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ Header Section 03
  Widget _buildSectionHeader() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snap) {
        final data = snap.data ?? const <String, dynamic>{};
        final sectionNum = pickString(data, ['section_number'], '03');
        final sectionTitle = pickString(data, ['section_title'], 'Tambah KRS');
        final sectionDesc = pickString(
          data,
          ['section_desc'],
          'Pilih dan filter jadwal mata kuliah, lalu simpan pilihan Anda.',
        );
        final badgeCount = pickString(
          data,
          ['result_badge'],
          data['total_jadwal'] != null ? '${data['total_jadwal']} jadwal' : '',
        );

        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 16, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge 03
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      AppColors.upiYellowBright,
                      AppColors.upiYellowDeep,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.upiYellowDeep.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    sectionNum,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Title & Desc
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          sectionTitle,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (badgeCount.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.upiYellowDeep.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              badgeCount,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.upiYellowDeep,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sectionDesc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.textMuted,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),

              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close_rounded, size: 22, color: context.textMuted),
              ),
            ],
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------ Selection Summary Banner
  Widget _buildSelectionSummaryBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.upiYellowLight.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.upiYellowDeep.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              size: 16, color: AppColors.upiYellowDeep),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 11.5,
                  color: context.textPrimary,
                ),
                children: [
                  TextSpan(
                    text: '${_selectedTokens.length} ',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AppColors.upiYellowDeep,
                    ),
                  ),
                  const TextSpan(text: 'jadwal dipilih dari beberapa halaman.'),
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _selectedTokens.clear()),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: AppColors.red,
            ),
            child: const Text(
              'Hapus Pilihan',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ Filters
  Widget _buildFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          // Filter Dapat Dipilih
          FilterChip(
            selected: _hanyaDapatDipilih,
            showCheckmark: true,
            label: const Text('Bisa Diambil Saja',
                style: TextStyle(fontSize: 11.5)),
            selectedColor: AppColors.upiYellowLight,
            onSelected: (val) {
              setState(() => _hanyaDapatDipilih = val);
            },
          ),
          const SizedBox(width: 8),

          // Dropdown Hari
          _buildFilterDropdown(
            label: _selectedHari.isEmpty ? 'Semua Hari' : _selectedHari,
            icon: Icons.calendar_today_rounded,
            items: const [
              '',
              'Senin',
              'Selasa',
              'Rabu',
              'Kamis',
              'Jumat',
              'Sabtu'
            ],
            currentValue: _selectedHari,
            onChanged: (val) {
              setState(() {
                _selectedHari = val;
                _page = 1;
              });
              _refresh();
            },
          ),
          const SizedBox(width: 8),

          // Dropdown Semester
          _buildFilterDropdown(
            label: _selectedSemester.isEmpty
                ? 'Semua Semester'
                : 'Semester $_selectedSemester',
            icon: Icons.layers_rounded,
            items: const ['', '1', '2', '3', '4', '5', '6', '7', '8'],
            currentValue: _selectedSemester,
            onChanged: (val) {
              setState(() {
                _selectedSemester = val;
                _page = 1;
              });
              _refresh();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required IconData icon,
    required List<String> items,
    required String currentValue,
    required ValueChanged<String> onChanged,
  }) {
    return PopupMenuButton<String>(
      onSelected: onChanged,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => items.map((it) {
        final text = it.isEmpty
            ? (label.contains('Hari') ? 'Semua Hari' : 'Semua Semester')
            : (label.contains('Hari') ? it : 'Semester $it');
        return PopupMenuItem<String>(
          value: it,
          child: Text(text, style: const TextStyle(fontSize: 12.5)),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: currentValue.isNotEmpty
              ? AppColors.upiYellowDeep.withValues(alpha: 0.12)
              : context.card,
          border: Border.all(
            color: currentValue.isNotEmpty
                ? AppColors.upiYellowDeep
                : context.border,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 13,
                color: currentValue.isNotEmpty
                    ? AppColors.upiYellowDeep
                    : context.textMuted),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: currentValue.isNotEmpty
                    ? AppColors.upiYellowDeep
                    : context.textPrimary,
              ),
            ),
            const SizedBox(width: 3),
            Icon(Icons.arrow_drop_down_rounded,
                size: 16, color: context.textMuted),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------ Item Card
  Widget _buildJadwalItemCard(Map<String, dynamic> item) {
    final token = pickString(item, ['value', 'jadwal', 'token'], '');
    final kode = pickString(item, ['kode', 'kode_mk'], '');
    final nama = pickString(item, ['nama', 'nama_mk'], 'Mata Kuliah');
    final jenis = pickString(item, ['jenis', 'course_kind'], '');
    final sks = pickString(item, ['sks'], '0');
    final semester = pickString(item, ['semester', 'smt'], '');
    final kelas = pickString(item, ['kelas'], '');
    final ruang = pickString(item, ['ruang', 'ruangan'], '');
    final hari = pickString(item, ['hari'], '');
    final jam = pickString(item, ['jam', 'waktu'], '');
    final dosen = pickString(item, ['dosen'], '');
    final kapasitas = pickString(item, ['kapasitas'], '');
    final selectionHint = pickString(item, ['selection_hint'], '');

    final dapatDipilih = item['dapat_dipilih'] == true;
    final isBlocked = item['is_blocked'] == true;
    final blockReason = pickString(item, ['block_reason'], '');

    final isBusy = _busyTokens.contains(token);
    final isChecked = _selectedTokens.contains(token);

    final canCheck = token.isNotEmpty && dapatDipilih && !isBlocked;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isBlocked
              ? AppColors.red.withValues(alpha: 0.35)
              : (isChecked
                  ? AppColors.upiYellowDeep
                  : context.border),
          width: isChecked ? 1.8 : 1,
        ),
        boxShadow: isChecked
            ? [
                BoxShadow(
                  color: AppColors.upiYellowDeep.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Multi-select Checkbox
                if (canCheck)
                  Padding(
                    padding: const EdgeInsets.only(right: 10, top: 2),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: isChecked,
                        activeColor: AppColors.upiYellowDeep,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5)),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedTokens.add(token);
                            } else {
                              _selectedTokens.remove(token);
                            }
                          });
                        },
                      ),
                    ),
                  ),

                // Info Utama
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badges bar: Kode, SKS, Jenis (Wajib/Pilihan), Semester
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (kode.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: context.isDark
                                    ? Colors.white12
                                    : const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                kode,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: context.textMuted,
                                ),
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$sks SKS',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.upiYellowDeep,
                              ),
                            ),
                          ),
                          if (jenis.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: jenis.toLowerCase().contains('wajib')
                                    ? AppColors.blue.withValues(alpha: 0.12)
                                    : AppColors.green.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                jenis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: jenis.toLowerCase().contains('wajib')
                                      ? AppColors.blue
                                      : AppColors.green,
                                ),
                              ),
                            ),
                          if (semester.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: context.isDark
                                    ? Colors.white10
                                    : const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                semester.toLowerCase().contains('smt') ||
                                        semester.toLowerCase().contains('semester')
                                    ? semester
                                    : 'Smt $semester',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: context.textMuted,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Nama Mata Kuliah
                      Text(
                        nama,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: context.textPrimary,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Waktu, Kelas, Ruang, Kapasitas
                      Wrap(
                        spacing: 8,
                        runSpacing: 5,
                        children: [
                          if (hari.isNotEmpty || jam.isNotEmpty)
                            _badge(
                              Icons.access_time_filled_rounded,
                              [hari, jam].where((e) => e.isNotEmpty).join(', '),
                            ),
                          if (kelas.isNotEmpty)
                            _badge(Icons.groups_rounded, 'Kelas $kelas'),
                          if (ruang.isNotEmpty)
                            _badge(Icons.room_rounded, 'Ruang $ruang'),
                          if (kapasitas.isNotEmpty)
                            _badge(
                              Icons.chair_rounded,
                              kapasitas.contains('Terisi')
                                  ? kapasitas
                                  : '$kapasitas Terisi/Kuota',
                            ),
                        ],
                      ),

                      // Dosen Pengampu
                      if (dosen.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.person_rounded,
                                size: 13, color: context.textMuted),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                dosen,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: context.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Kolom Aksi / Status
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FilledButton(
                      onPressed: (!dapatDipilih || isBlocked || isBusy || token.isEmpty)
                          ? null
                          : () => _ambilSatu(item),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.upiYellowDeep,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: context.isDark
                            ? Colors.white10
                            : const Color(0xFFE5E7EB),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        minimumSize: const Size(0, 34),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: isBusy
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              isBlocked
                                  ? 'Bentrok'
                                  : (!dapatDipilih
                                      ? (selectionHint.isNotEmpty
                                          ? selectionHint
                                          : 'Penuh')
                                      : 'Ambil'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: (!dapatDipilih || isBlocked || token.isEmpty)
                                    ? context.textMuted
                                    : Colors.white,
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Banner Bentrok
          if (isBlocked && blockReason.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: 0.08),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(15)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 15, color: AppColors.red),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      blockReason,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.red,
                        fontWeight: FontWeight.w600,
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

  Widget _badge(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: context.textMuted),
        const SizedBox(width: 3.5),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: context.textMuted,
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------ Pagination
  Widget _buildPaginationBar(int currentPage, int totalPages) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: context.card,
        border: Border(top: BorderSide(color: context.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          OutlinedButton.icon(
            onPressed: currentPage > 1
                ? () {
                    setState(() => _page = currentPage - 1);
                    _refresh();
                  }
                : null,
            icon: const Icon(Icons.chevron_left_rounded, size: 16),
            label: const Text('Sebelumnya', style: TextStyle(fontSize: 12)),
          ),
          Text(
            'Hal $currentPage dari $totalPages',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: context.textPrimary),
          ),
          OutlinedButton.icon(
            onPressed: currentPage < totalPages
                ? () {
                    setState(() => _page = currentPage + 1);
                    _refresh();
                  }
                : null,
            icon: const Icon(Icons.chevron_right_rounded, size: 16),
            label: const Text('Selanjutnya', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ Bulk Action Bar
  Widget _buildBulkActionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: context.card,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_selectedTokens.length} Mata Kuliah Dipilih',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: context.textPrimary,
                    ),
                  ),
                  Text(
                    'Tekan tombol untuk mengambil sekaligus',
                    style: TextStyle(fontSize: 11, color: context.textMuted),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: _isSubmittingBulk ? null : _ambilBulk,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.upiYellowDeep,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: _isSubmittingBulk
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_rounded, size: 18),
              label: Text(
                _isSubmittingBulk
                    ? 'Menyimpan...'
                    : 'Simpan Pilihan (${_selectedTokens.length})',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
