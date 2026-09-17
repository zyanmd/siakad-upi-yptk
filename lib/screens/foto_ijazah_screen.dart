import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/wisuda_service.dart';
import '../theme/app_theme.dart';
import '../utils/smart.dart';
import '../widgets/common.dart';

/// Layar Upload & Pengelolaan Foto Ijazah Wisuda Mahasiswa:
/// Menampilkan status foto resmi, panduan busana (jas/kebaya latar merah 3:4),
/// pengambilan/pemilihan foto dari galeri/kamera, validasi berkas,
/// dan pengunggahan langsung ke server SIAKAD.
class FotoIjazahScreen extends StatefulWidget {
  const FotoIjazahScreen({super.key});

  @override
  State<FotoIjazahScreen> createState() => _FotoIjazahScreenState();
}

class _FotoIjazahScreenState extends State<FotoIjazahScreen> {
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = true;
  bool _isUploading = false;
  bool _isLoadingPhoto = false;
  String? _error;

  Map<String, dynamic> _data = {};
  Uint8List? _savedPhotoBytes;

  Uint8List? _selectedBytes;
  String? _selectedFileName;
  int _selectedFileSize = 0;

  @override
  void initState() {
    super.initState();
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final srv = WisudaService(context.read<ApiClient>());
      final resp = await srv.getFotoIjazah();
      final map = asMap(resp);
      final data = asMap(map['data'] ?? map);

      _data = data;
      _isLoading = false;

      final bool hasPhoto = data['has_photo'] == true;
      if (hasPhoto) {
        _loadSavedPhoto();
      } else {
        setState(() {});
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSavedPhoto() async {
    if (!mounted) return;
    setState(() => _isLoadingPhoto = true);
    try {
      final srv = WisudaService(context.read<ApiClient>());
      final bytes = await srv.getPreviewFotoBytes();
      if (mounted) {
        setState(() {
          _savedPhotoBytes = Uint8List.fromList(bytes);
          _isLoadingPhoto = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingPhoto = false);
      }
    }
  }

  Future<void> _pilihSumberFoto() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: ctx.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: ctx.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Pilih Foto Ijazah',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: ctx.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Pastikan memakai pakaian formal resmi dan latar belakang merah polos (rasio 3:4).',
              style: TextStyle(fontSize: 12, color: ctx.textMuted, height: 1.3),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.upiYellowDeep.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.photo_library_rounded,
                    color: AppColors.upiYellowDeep),
              ),
              title: const Text('Buka Galeri Foto',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: const Text('Pilih berkas foto dari penyimpanan HP',
                  style: TextStyle(fontSize: 11.5)),
              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.camera_alt_rounded,
                    color: AppColors.blue),
              ),
              title: const Text('Gunakan Kamera',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: const Text('Ambil foto langsung dengan kamera',
                  style: TextStyle(fontSize: 11.5)),
              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 3000,
        maxHeight: 4000,
        imageQuality: 96,
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();
      final size = bytes.length;

      // Validasi batas ukuran 5 MB
      if (size > 5 * 1024 * 1024) {
        if (mounted) {
          appToast(
            context,
            'Ukuran foto terlalu besar (${(size / 1024 / 1024).toStringAsFixed(2)} MB). Maksimal 5 MB.',
            error: true,
          );
        }
        return;
      }

      setState(() {
        _selectedBytes = bytes;
        _selectedFileName = file.name.isNotEmpty ? file.name : 'foto_ijazah.jpg';
        _selectedFileSize = size;
      });
    } catch (e) {
      if (mounted) {
        appToast(context, 'Gagal memilih gambar: $e', error: true);
      }
    }
  }

  Future<void> _unggahFoto() async {
    if (_selectedBytes == null || _selectedBytes!.isEmpty) {
      appToast(context, 'Pilih foto terlebih dahulu', error: true);
      return;
    }

    setState(() => _isUploading = true);

    try {
      final srv = WisudaService(context.read<ApiClient>());
      final fileName = _selectedFileName ?? 'foto_ijazah.jpg';
      final isPng = fileName.toLowerCase().endsWith('.png');
      final contentType = isPng ? 'image/png' : 'image/jpeg';

      final resp = await srv.uploadFotoIjazahBytes(
        _selectedBytes!,
        fileName,
        contentType: contentType,
      );

      final map = asMap(resp);
      final msg = pickString(map, ['message', 'msg'], 'Foto ijazah berhasil diunggah!');

      if (mounted) {
        appToast(context, msg);
        setState(() {
          _selectedBytes = null;
          _selectedFileName = null;
          _selectedFileSize = 0;
          _isUploading = false;
        });
        // Segarkan data dan foto yang tersimpan
        _loadMetadata();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        appToast(context, 'Gagal mengunggah foto: $e', error: true);
      }
    }
  }

  void _lihatFotoPenuh(Uint8List bytes) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InteractiveViewer(
                child: Image.memory(
                  bytes,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mhs = asMap(_data['mahasiswa']);
    final nama = pickString(mhs, ['nama'], '-');
    final nim = pickString(mhs, ['nim'], '-');
    final prodi = pickString(mhs, ['prodi'], '-');
    final fakultas = pickString(mhs, ['fakultas'], '-');

    final bool hasPhoto = _data['has_photo'] == true;
    final photoState = pickString(_data, ['photo_state'], hasPhoto ? 'Sudah Diunggah' : 'Belum diunggah');

    final pers = asMap(_data['persyaratan']);
    final petunjukList = asList(_data['petunjuk']).map((e) => asMap(e)).toList();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 1. Sliver AppBar Emas UPI YPTK
          SliverAppBar(
            pinned: true,
            expandedHeight: 120,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: AppColors.headerGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const FlexibleSpaceBar(
                titlePadding: EdgeInsets.only(left: 56, bottom: 16),
                title: Text(
                  'Foto Ijazah Wisuda',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Segarkan',
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                onPressed: () {
                  _loadMetadata();
                },
              ),
            ],
          ),

          // 2. Konten Layar
          SliverToBoxAdapter(
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(
                      child: LoadingView(label: 'Memuat data foto ijazah...'),
                    ),
                  )
                : _error != null
                    ? Padding(
                        padding: const EdgeInsets.all(20),
                        child: ErrorRetry(
                          message: _error!,
                          onRetry: _loadMetadata,
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Kartu Data Mahasiswa
                            _buildMahasiswaCard(
                              nama: nama,
                              nim: nim,
                              prodi: prodi,
                              fakultas: fakultas,
                            ),
                            const SizedBox(height: 16),

                            // Kartu Pratinjau / Status Foto
                            _buildStatusFotoCard(
                              hasPhoto: hasPhoto,
                              photoState: photoState,
                            ),
                            const SizedBox(height: 16),

                            // Kartu Upload Foto Terpilih (Jika ada gambar dipilih)
                            if (_selectedBytes != null) ...[
                              _buildSelectedImageCard(),
                              const SizedBox(height: 16),
                            ],

                            // Persyaratan Foto
                            if (pers.isNotEmpty) ...[
                              const SectionTitle('Persyaratan Foto Ijazah'),
                              const SizedBox(height: 10),
                              _buildPersyaratanGrid(pers),
                              const SizedBox(height: 20),
                            ],

                            // Panduan & Tata Cara Foto
                            if (petunjukList.isNotEmpty) ...[
                              const SectionTitle('Petunjuk & Ketentuan Resmi'),
                              const SizedBox(height: 10),
                              for (var i = 0; i < petunjukList.length; i++)
                                _buildPetunjukCard(petunjukList[i], i + 1),
                              const SizedBox(height: 20),
                            ],

                            const SizedBox(height: 30),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------- Mahasiswa Card
  Widget _buildMahasiswaCard({
    required String nama,
    required String nim,
    required String prodi,
    required String fakultas,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.indigo950, AppColors.indigo900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.indigo950.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.upiYellowDeep.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.upiYellowDeep.withValues(alpha: 0.4),
                  ),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: AppColors.amberLight,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nama,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'NIM: $nim',
                      style: const TextStyle(
                        color: AppColors.amberLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Program Studi:\n$prodi',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 11.5,
                    height: 1.3,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'Fakultas:\n$fakultas',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 11.5,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------- Status Foto Card
  Widget _buildStatusFotoCard({
    required bool hasPhoto,
    required String photoState,
  }) {
    final statusColor = hasPhoto ? AppColors.green : AppColors.orange;

    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
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
              Row(
                children: [
                  Icon(
                    hasPhoto ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                    color: statusColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Status Foto Ijazah',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  photoState,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tampilan Foto (Jika sudah ada vs Belum ada)
          if (hasPhoto) ...[
            Center(
              child: Column(
                children: [
                  Container(
                    width: 150,
                    height: 200, // Rasio 3:4
                    decoration: BoxDecoration(
                      color: Colors.red.shade900,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(
                        color: AppColors.upiYellowDeep,
                        width: 2.5,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _isLoadingPhoto
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : _savedPhotoBytes != null
                            ? InkWell(
                                onTap: () => _lihatFotoPenuh(_savedPhotoBytes!),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.memory(
                                      _savedPhotoBytes!,
                                      fit: BoxFit.cover,
                                    ),
                                    Positioned(
                                      bottom: 6,
                                      right: 6,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Icon(
                                          Icons.fullscreen_rounded,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : const Center(
                                child: Icon(
                                  Icons.account_box_rounded,
                                  size: 48,
                                  color: Colors.white70,
                                ),
                              ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Foto Ijazah Resmi Tersimpan (Rasio 3:4)',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: context.textMuted,
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _pilihSumberFoto,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.photo_camera_rounded, size: 16),
                    label: const Text('Ganti / Perbarui Foto', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Belum unggah foto placeholder
            InkWell(
              onTap: _pilihSumberFoto,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                decoration: BoxDecoration(
                  color: context.softFill,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.upiYellowDeep.withValues(alpha: 0.5),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: AppColors.upiYellowDeep.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add_a_photo_rounded,
                        color: AppColors.upiYellowDeep,
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Pilih atau Ambil Foto Ijazah',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Format JPG/PNG • Maks. 5 MB • Latar Belakang Merah Polos',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: context.textMuted,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: _pilihSumberFoto,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.upiYellowDeep,
                        foregroundColor: AppColors.indigo950,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.upload_file_rounded, size: 16),
                      label: const Text(
                        'Pilih Berkas Foto',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --------------------------------------------- Selected Image Preview Card
  Widget _buildSelectedImageCard() {
    final sizeMb = (_selectedFileSize / 1024 / 1024).toStringAsFixed(2);

    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.upiYellowDeep, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.upiYellowDeep.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.photo_size_select_actual_rounded,
                  color: AppColors.upiYellowDeep, size: 20),
              const SizedBox(width: 8),
              Text(
                'Pratinjau Foto Baru',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () {
                  setState(() {
                    _selectedBytes = null;
                    _selectedFileName = null;
                    _selectedFileSize = 0;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: Column(
              children: [
                // Bingkai Rasio 3:4
                Container(
                  width: 165,
                  height: 220,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade700, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.memory(
                    _selectedBytes!,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _selectedFileName ?? 'foto_ijazah.jpg',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Ukuran: $sizeMb MB (Memenuhi syarat < 5 MB)',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.green,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // Tombol Aksi Upload
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isUploading ? null : _pilihSumberFoto,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Ganti Foto'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _isUploading ? null : _unggahFoto,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.upiYellowDeep,
                    foregroundColor: AppColors.indigo950,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: _isUploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.indigo950,
                          ),
                        )
                      : const Icon(Icons.cloud_upload_rounded, size: 18),
                  label: Text(
                    _isUploading ? 'Mengunggah...' : 'Unggah Foto Ijazah',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------- Persyaratan Grid
  Widget _buildPersyaratanGrid(Map<String, dynamic> pers) {
    final format = pickString(pers, ['format'], 'JPG / PNG');
    final maxSize = pickString(pers, ['max_size'], 'Maks. 5 MB');
    final rasio = pickString(pers, ['rasio'], '3:4');
    final resolusi = pickString(pers, ['resolusi_hasil'], '900 × 1200 px');

    final items = [
      (label: 'Format Berkas', value: format, icon: Icons.image_rounded, color: AppColors.blue),
      (label: 'Rasio Foto', value: rasio, icon: Icons.aspect_ratio_rounded, color: AppColors.upiYellowDeep),
      (label: 'Ukuran Maksimal', value: maxSize, icon: Icons.data_usage_rounded, color: AppColors.green),
      (label: 'Rekomendasi Hasil', value: resolusi, icon: Icons.high_quality_rounded, color: AppColors.orange),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.3,
      children: [
        for (final it in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: it.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(it.icon, size: 18, color: it.color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        it.label,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: context.textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        it.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: context.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // -------------------------------------------------------- Petunjuk Card
  Widget _buildPetunjukCard(Map<String, dynamic> petunjuk, int index) {
    final judul = pickString(petunjuk, ['judul'], 'Petunjuk $index');
    final deskripsi = pickString(petunjuk, ['deskripsi'], '');

    final icons = [
      Icons.checkroom_rounded,
      Icons.palette_rounded,
      Icons.accessibility_new_rounded,
      Icons.crop_original_rounded,
    ];
    final icon = icons[(index - 1) % icons.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.upiYellowDeep.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.upiYellowDeep),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  judul,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary,
                  ),
                ),
                if (deskripsi.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    deskripsi,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: context.textMuted,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

