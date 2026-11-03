import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../services/akademik_service.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../utils/smart.dart';
import '../widgets/common.dart';
import 'dokumen_viewer_screen.dart';

// ── UPI YPTK Golden Yellow Gradient (header lekukan) ──
const _yellowHeaderGradient = [
  Color(0xFFE5A620), // Bright Academic Gold
  Color(0xFFD48B08), // UPI Yellow
  Color(0xFFB87500), // Deep Academic Gold
];

/// Layar Download Dokumen Mahasiswa:
/// Menampilkan formulir, panduan akademik, dan dokumen resmi universitas
/// dengan pencarian real-time, filter kategori, unduh langsung via stream proxy,
/// dan opsi buka tautan asli SISFO.
class DownloadScreen extends StatefulWidget {
  const DownloadScreen({super.key});

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _data;

  String _searchQuery = '';
  String _selectedKategori = '';
  int _currentPage = 1;
  String? _downloadingId;

  List<Map<String, dynamic>> _kategoriList = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = AkademikService(context.read<ApiClient>());
      dynamic resp;
      try {
        resp = await service.download(
          q: _searchQuery.isNotEmpty ? _searchQuery : null,
          kategori: _selectedKategori.isNotEmpty ? _selectedKategori : null,
          page: _currentPage > 1 ? _currentPage : null,
        );
      } catch (_) {
        // Fallback ke endpoint data jika endpoint utama mengalami kendala
        resp = await service.downloadData(
          q: _searchQuery.isNotEmpty ? _searchQuery : null,
          kategori: _selectedKategori.isNotEmpty ? _selectedKategori : null,
          page: _currentPage > 1 ? _currentPage : null,
        );
      }

      final raw = asMap(resp);
      final mapData = asMap(raw['data'] ?? raw);

      // Ekstraksi kategori tersedia
      final cats = asList(mapData['kategori_tersedia']);
      if (cats.isNotEmpty) {
        _kategoriList = cats.map((e) => asMap(e)).toList();
      } else if (_kategoriList.isEmpty) {
        try {
          final kResp = await service.downloadKategori();
          final kData = asMap(asMap(kResp)['data'] ?? kResp);
          final kList = asList(kData['kategori']);
          if (kList.isNotEmpty) {
            _kategoriList = kList.map((e) => asMap(e)).toList();
          }
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _data = mapData;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onSearchSubmit(String query) {
    final q = query.trim();
    if (q == _searchQuery) return;
    setState(() {
      _searchQuery = q;
      _currentPage = 1;
    });
    _loadData();
  }

  void _onSelectKategori(String val) {
    if (val == _selectedKategori) return;
    setState(() {
      _selectedKategori = val;
      _currentPage = 1;
    });
    _loadData();
  }

  Future<void> _unduhBerkas(Map<String, dynamic> doc) async {
    final fileId = pickString(doc, ['file_id', 'id'], '');
    final judul = pickString(doc, ['judul', 'nama'], 'Dokumen_Mahasiswa');
    final directUrl = pickString(doc, ['url', 'link'], '');
    final format = pickString(doc, ['format'], 'pdf').toLowerCase();

    final targetId = fileId.isNotEmpty ? fileId : directUrl;
    if (targetId.isEmpty) {
      appToast(context, 'Tautan atau ID dokumen tidak ditemukan', error: true);
      return;
    }

    setState(() {
      _downloadingId = targetId;
    });

    try {
      final service = AkademikService(context.read<ApiClient>());
      List<int> bytes = [];

      if (fileId.isNotEmpty) {
        try {
          bytes = await service.downloadFileBytes(fileId);
        } catch (e) {
          // Fallback mencoba ambil url download resmi
          try {
            final uResp = await service.downloadUrl(fileId);
            final uData = asMap(asMap(uResp)['data'] ?? uResp);
            final fallbackUrl = pickString(uData, ['url'], directUrl);
            if (fallbackUrl.isNotEmpty) {
              if (mounted) {
                appToast(context, 'Mengalihkan ke browser...');
                await openExternal(context, fallbackUrl);
              }
              return;
            }
          } catch (_) {}
          rethrow;
        }
      }

      if (bytes.isNotEmpty) {
        final safeName = judul.replaceAll(RegExp(r'[^a-zA-Z0-9_\- ]'), '_').trim();
        final ext = format.contains('pdf') ? 'pdf' : (format.isNotEmpty ? format : 'pdf');
        final fileName = '$safeName.$ext';

        // Bagikan / Simpan dokumen langsung ke perangkat pengguna via native share sheet
        await Printing.sharePdf(
          bytes: Uint8List.fromList(bytes),
          filename: fileName,
        );

        if (mounted) {
          appToast(context, 'Berkas berhasil diproses!');
        }
      } else if (directUrl.isNotEmpty) {
        if (mounted) {
          appToast(context, 'Membuka dokumen di browser...');
          await openExternal(context, directUrl);
        }
      } else {
        throw 'Berkas kosong atau tidak dapat diunduh.';
      }
    } catch (e) {
      if (mounted) {
        if (directUrl.isNotEmpty) {
          appToast(context, 'Mengunduh lewat browser...');
          await openExternal(context, directUrl);
        } else {
          appToast(context, 'Gagal mengunduh: $e', error: true);
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _downloadingId = null;
        });
      }
    }
  }

  void _bukaDiAplikasi(Map<String, dynamic> doc) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DokumenViewerScreen(doc: doc),
      ),
    );
  }

  void _showDetailModal(Map<String, dynamic> doc) {
    final judul = pickString(doc, ['judul', 'nama'], 'Dokumen');
    final deskripsi = pickString(doc, ['deskripsi', 'keterangan'], '-');
    final kategori = pickString(doc, ['kategori'], '-');
    final ukuran = pickString(doc, ['ukuran'], '-');
    final tanggal = pickString(doc, ['tanggal'], '-');
    final format = pickString(doc, ['format'], 'PDF');
    final directUrl = pickString(doc, ['url'], '');
    final fileId = pickString(doc, ['file_id'], '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: ctx.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ctx.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.upiYellowDeep.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.description_rounded,
                      color: AppColors.upiYellowDeep,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          judul,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: ctx.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          kategori,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.upiYellowDeep,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),
              KeyValueRow(label: 'Format File', value: format),
              KeyValueRow(label: 'Ukuran', value: ukuran),
              KeyValueRow(label: 'Tanggal Rilis', value: tanggal),
              if (deskripsi.isNotEmpty && deskripsi != '-')
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Deskripsi:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: ctx.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        deskripsi,
                        style: TextStyle(
                          fontSize: 13,
                          color: ctx.textPrimary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              if (fileId.isNotEmpty)
                KeyValueRow(
                  label: 'ID Berkas',
                  value: fileId.length > 20 ? '${fileId.substring(0, 18)}...' : fileId,
                ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.upiYellowDeep,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.chrome_reader_mode_rounded, size: 18),
                  label: const Text(
                    'Buka & Unduh di Aplikasi',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _bukaDiAplikasi(doc);
                  },
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (directUrl.isNotEmpty) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.copy_rounded, size: 17),
                        label: const Text('Salin Link', style: TextStyle(fontSize: 12.5)),
                        onPressed: () {
                          Navigator.pop(ctx);
                          copyText(context, directUrl);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.download_rounded, size: 17),
                      label: const Text(
                        'Unduh Berkas',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _unduhBerkas(doc);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  IconData _getFileIcon(String format, String judul, String kategori) {
    final f = '$format $judul $kategori'.toLowerCase();
    if (f.contains('pdf')) return Icons.picture_as_pdf_rounded;
    if (f.contains('doc') || f.contains('word') || f.contains('formulir')) {
      return Icons.description_rounded;
    }
    if (f.contains('xls') || f.contains('excel') || f.contains('sheet')) {
      return Icons.table_chart_rounded;
    }
    if (f.contains('ppt') || f.contains('slide')) {
      return Icons.slideshow_rounded;
    }
    if (f.contains('zip') || f.contains('rar')) {
      return Icons.folder_zip_rounded;
    }
    if (f.contains('panduan') || f.contains('buku')) {
      return Icons.menu_book_rounded;
    }
    return Icons.insert_drive_file_rounded;
  }

  Color _getFileColor(String format, String judul, String kategori) {
    final f = '$format $judul $kategori'.toLowerCase();
    if (f.contains('pdf')) return AppColors.red;
    if (f.contains('doc') || f.contains('word')) return AppColors.blue;
    if (f.contains('xls') || f.contains('excel')) return AppColors.green;
    if (f.contains('ppt')) return AppColors.orange;
    if (f.contains('zip') || f.contains('rar')) return Colors.purple;
    return AppColors.upiYellowDeep;
  }

  @override
  Widget build(BuildContext context) {
    final mapData = _data ?? <String, dynamic>{};
    final judul = pickString(mapData, ['judul'], 'Download');
    final eyebrow = pickString(mapData, ['eyebrow'], 'Dokumen Mahasiswa');
    final deskripsi = pickString(
      mapData,
      ['deskripsi'],
      'Unduh formulir, panduan, dan dokumen resmi yang disediakan untuk mahasiswa.',
    );
    final total = pickString(mapData, ['total'], '0');
    final totalLabel = pickString(mapData, ['total_label'], 'file tersedia');
    final securityNote = pickString(
      mapData,
      ['security_note'],
      'File dilindungi akses akun SISFO',
    );

    final dokumenList = asList(mapData['dokumen']).map((e) => asMap(e)).toList();

    return Scaffold(
      backgroundColor: context.bg,
      body: Column(
        children: [
          _buildCurvedYellowHeader(
            judul: judul.isNotEmpty ? judul : 'Download Dokumen',
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
              children: [
                // Hero Header Card
                _buildHeroCard(
                  eyebrow: eyebrow,
                  judul: judul,
                  deskripsi: deskripsi,
                  total: total,
                  totalLabel: totalLabel,
                  securityNote: securityNote,
                ),
                const SizedBox(height: 16),

                // Kotak Pencarian
                _buildSearchBar(),
                const SizedBox(height: 12),

                // Filter Kategori
                if (_kategoriList.isNotEmpty) ...[
                  _buildKategoriFilter(),
                  const SizedBox(height: 14),
                ],

                // Indikator Loading / Error / Konten
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.upiYellowDeep,
                      ),
                    ),
                  )
                else if (_error != null)
                  ErrorRetry(
                    message: _error!,
                    onRetry: _loadData,
                  )
                else if (dokumenList.isEmpty)
                  EmptyView(
                    message: _searchQuery.isNotEmpty || _selectedKategori.isNotEmpty
                        ? 'Tidak ada dokumen yang cocok dengan filter yang dipilih.'
                        : 'Belum ada dokumen yang tersedia untuk diunduh.',
                  )
                else ...[
                  SectionTitle('Daftar Dokumen ($total $totalLabel)'),
                  const SizedBox(height: 10),
                  for (final doc in dokumenList)
                    _buildDokumenCard(doc),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────── HEADER KUNING DENGAN LEKUKAN
  Widget _buildCurvedYellowHeader({required String judul}) {
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
                // Baris Atas: Back Button + Judul + Tombol Segarkan
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
                          'Download Dokumen',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ],
                    ),
                    IosBounceTap(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _loadData();
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
                        child: const Icon(Icons.refresh_rounded,
                            size: 20, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Baris Info: Lingkaran Ikon + Judul Dokumen
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
                      child: const Center(
                        child: Icon(
                          Icons.file_download_rounded,
                          size: 27,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            judul,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text(
                                'Formulir, panduan & dokumen resmi',
                                style: TextStyle(
                                  color: Color(0xE6FFFFFF),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.2,
                                ),
                              ),
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
                            ],
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

  // ------------------------------------------------------------- Hero Card
  Widget _buildHeroCard({
    required String eyebrow,
    required String judul,
    required String deskripsi,
    required String total,
    required String totalLabel,
    required String securityNote,
  }) {
    final isDark = context.isDark;
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                decoration: BoxDecoration(
                  color: AppColors.upiYellowDeep.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.upiYellowDeep.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  eyebrow.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.upiYellowDeep,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                decoration: BoxDecoration(
                  color: context.softFill,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.folder_shared_rounded,
                      color: AppColors.upiYellowDeep,
                      size: 13,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$total $totalLabel',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Unduh Dokumen & Panduan',
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            deskripsi,
            style: TextStyle(
              color: context.textMuted,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          if (securityNote.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: context.softFill,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    color: AppColors.upiYellowDeep,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      securityNote,
                      style: TextStyle(
                        color: context.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
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

  // ----------------------------------------------------------- Search Bar
  Widget _buildSearchBar() {
    final isDark = context.isDark;
    return Container(
      decoration: BoxDecoration(
        color: context.card,
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
      child: TextField(
        controller: _searchCtrl,
        onSubmitted: _onSearchSubmit,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Cari judul, kata kunci, atau kategori...',
          hintStyle: TextStyle(fontSize: 13, color: context.textMuted),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.upiYellowDeep,
            size: 20,
          ),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    _onSearchSubmit('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        ),
      ),
    );
  }

  // ------------------------------------------------------ Kategori Filter
  Widget _buildKategoriFilter() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _kategoriList.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final cat = _kategoriList[i];
          final label = pickString(cat, ['label', 'nama'], 'Semua');
          final value = pickString(cat, ['value', 'val'], '');
          final isSelected = value == _selectedKategori;

          return FilterChip(
            label: Text(label),
            selected: isSelected,
            onSelected: (_) => _onSelectKategori(value),
            selectedColor: AppColors.primaryYellow,
            backgroundColor: context.softFill,
            checkmarkColor: const Color(0xFF1C1917),
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? const Color(0xFF1C1917) : ctx.textPrimary,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: isSelected ? AppColors.primaryYellow : context.border,
                width: 0.5,
              ),
            ),
          );
        },
      ),
    );
  }

  // --------------------------------------------------------- Dokumen Card
  Widget _buildDokumenCard(Map<String, dynamic> doc) {
    final judul = pickString(doc, ['judul', 'nama'], 'Dokumen Mahasiswa');
    final deskripsi = pickString(doc, ['deskripsi', 'keterangan'], '');
    final kategori = pickString(doc, ['kategori'], 'Umum');
    final ukuran = pickString(doc, ['ukuran'], '');
    final tanggal = pickString(doc, ['tanggal'], '');
    final format = pickString(doc, ['format'], 'PDF').toUpperCase();
    final fileId = pickString(doc, ['file_id'], '');
    final directUrl = pickString(doc, ['url'], '');

    final targetId = fileId.isNotEmpty ? fileId : directUrl;
    final isDownloading = _downloadingId == targetId;

    final fileIcon = _getFileIcon(format, judul, kategori);
    final fileColor = _getFileColor(format, judul, kategori);

    final isDark = context.isDark;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(18),
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _bukaDiAplikasi(doc),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon Berkas
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: fileColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(fileIcon, color: fileColor, size: 22),
                    ),
                    const SizedBox(width: 12),

                    // Judul & Kategori
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: fileColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  kategori,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: fileColor,
                                  ),
                                ),
                              ),
                              if (format.isNotEmpty && format != '-') ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.softFill,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: context.border),
                                  ),
                                  child: Text(
                                    format,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: context.textMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            judul,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: context.textPrimary,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Menu Opsi
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert_rounded, size: 20, color: context.textMuted),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onSelected: (val) {
                        switch (val) {
                          case 'buka':
                            _bukaDiAplikasi(doc);
                            break;
                          case 'unduh':
                            _unduhBerkas(doc);
                            break;
                          case 'salin':
                            if (directUrl.isNotEmpty) copyText(context, directUrl);
                            break;
                          case 'web':
                            if (directUrl.isNotEmpty) openExternal(context, directUrl);
                            break;
                          case 'info':
                            _showDetailModal(doc);
                            break;
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'buka',
                          child: Row(
                            children: [
                              Icon(Icons.chrome_reader_mode_rounded, size: 18, color: AppColors.upiYellowDeep),
                              SizedBox(width: 10),
                              Text('Buka di Aplikasi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'unduh',
                          child: Row(
                            children: [
                              Icon(Icons.download_rounded, size: 18),
                              SizedBox(width: 10),
                              Text('Unduh Berkas', style: TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                        if (directUrl.isNotEmpty) ...[
                          const PopupMenuItem(
                            value: 'salin',
                            child: Row(
                              children: [
                                Icon(Icons.copy_rounded, size: 18),
                                SizedBox(width: 10),
                                Text('Salin Tautan', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'web',
                            child: Row(
                              children: [
                                Icon(Icons.open_in_browser_rounded, size: 18),
                                SizedBox(width: 10),
                                Text('Buka di Web', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'info',
                          child: Row(
                            children: [
                              Icon(Icons.info_outline_rounded, size: 18),
                              SizedBox(width: 10),
                              Text('Detail Informasi', style: TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                if (deskripsi.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    deskripsi,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textMuted,
                      height: 1.35,
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),

                // Baris Metadata & Tombol Aksi
                Row(
                  children: [
                    if (ukuran.isNotEmpty) ...[
                      Icon(
                        Icons.data_usage_rounded,
                        size: 13,
                        color: context.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        ukuran,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: context.textMuted,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    if (tanggal.isNotEmpty) ...[
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 13,
                        color: context.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        tanggal,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: context.textMuted,
                        ),
                      ),
                    ],
                    const Spacer(),

                    // Tombol Unduh Cepat
                    IconButton(
                      tooltip: 'Unduh Langsung ke Perangkat',
                      icon: isDownloading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.upiYellowDeep,
                              ),
                            )
                          : const Icon(
                              Icons.download_for_offline_outlined,
                              color: AppColors.upiYellowDeep,
                              size: 22,
                            ),
                      onPressed: isDownloading ? null : () => _unduhBerkas(doc),
                    ),
                    const SizedBox(width: 4),

                    // Tombol Buka & Unduh Utama di Aplikasi
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.upiYellowDeep,
                        foregroundColor: AppColors.indigo950,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.chrome_reader_mode_rounded, size: 16),
                      label: const Text(
                        'Buka di Aplikasi',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      onPressed: () => _bukaDiAplikasi(doc),
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
}

