import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../services/akademik_service.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../utils/smart.dart';
import '../widgets/common.dart';

/// Layar Penampil & Pengunduh Dokumen di Aplikasi (In-App Document Viewer):
/// Mengunduh binary berkas secara instan lewat proxy backend SIAKAD,
/// merender pratinjau dokumen PDF langsung di dalam aplikasi,
/// dan menyediakan tombol simpan/unduh, cetak, dan bagikan.
class DokumenViewerScreen extends StatefulWidget {
  const DokumenViewerScreen({
    super.key,
    required this.doc,
  });

  final Map<String, dynamic> doc;

  @override
  State<DokumenViewerScreen> createState() => _DokumenViewerScreenState();
}

class _DokumenViewerScreenState extends State<DokumenViewerScreen> {
  late Future<List<int>> _future;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _future = _fetchBytes();
  }

  String get _fileId {
    String id = pickString(widget.doc, ['file_id', 'id'], '');
    if (id.isEmpty) {
      final url = pickString(widget.doc, ['url', 'link'], '');
      if (url.isNotEmpty) {
        final uri = Uri.tryParse(url);
        if (uri != null && uri.pathSegments.isNotEmpty) {
          id = uri.pathSegments.last;
        }
      }
    } else if (id.contains('/')) {
      final parts = id.split('/');
      if (parts.isNotEmpty) id = parts.last;
    }
    return id;
  }

  String get _judul =>
      pickString(widget.doc, ['judul', 'nama'], 'Dokumen Mahasiswa');

  String get _kategori =>
      pickString(widget.doc, ['kategori'], 'Panduan Akademik');

  String get _ukuran => pickString(widget.doc, ['ukuran'], '');

  String get _directUrl => pickString(widget.doc, ['url', 'link'], '');

  String get _format =>
      pickString(widget.doc, ['format'], 'pdf').toLowerCase();

  String get _fileName {
    final safeName = _judul.replaceAll(RegExp(r'[^a-zA-Z0-9_\- ]'), '_').trim();
    final ext = _format.contains('pdf') ? 'pdf' : (_format.isNotEmpty ? _format : 'pdf');
    return '$safeName.$ext';
  }

  Future<List<int>> _fetchBytes() async {
    final service = AkademikService(context.read<ApiClient>());
    final targetId = _fileId;

    if (targetId.isNotEmpty) {
      try {
        final bytes = await service.downloadFileBytes(targetId);
        if (bytes.isNotEmpty) return bytes;
      } catch (e) {
        // Coba fallback ambil URL dari API
        try {
          final uResp = await service.downloadUrl(targetId);
          final uData = asMap(asMap(uResp)['data'] ?? uResp);
          final url = pickString(uData, ['url'], _directUrl);
          if (url.isNotEmpty && url.startsWith('http')) {
            // Jika ada URL tapi stream gagal, lempar pesan ramah
            throw 'Gagal memuat stream berkas dari server ($e).';
          }
        } catch (_) {}
        rethrow;
      }
    }

    throw 'ID dokumen atau tautan unduhan tidak ditemukan.';
  }

  Future<void> _simpanKePerangkat(List<int> bytes) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await Printing.sharePdf(
        bytes: Uint8List.fromList(bytes),
        filename: _fileName,
      );
      if (mounted) {
        appToast(context, 'Dokumen siap disimpan / dibagikan');
      }
    } catch (e) {
      if (mounted) {
        appToast(context, 'Gagal menyimpan berkas: $e', error: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  bool _isPdf(List<int> bytes) {
    // Header PDF: %PDF (0x25, 0x50, 0x44, 0x46)
    if (bytes.length >= 4) {
      if (bytes[0] == 0x25 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x44 &&
          bytes[3] == 0x46) {
        return true;
      }
    }
    return _format.contains('pdf');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.indigo950,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _judul,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$_kategori ${_ukuran.isNotEmpty ? '• $_ukuran' : ''}',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.amberLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Salin Tautan Dokumen',
            icon: const Icon(Icons.link_rounded),
            onPressed: () {
              if (_directUrl.isNotEmpty) {
                copyText(context, _directUrl);
              } else {
                appToast(context, 'Tautan tidak tersedia');
              }
            },
          ),
          if (_directUrl.isNotEmpty)
            IconButton(
              tooltip: 'Buka di Browser Luar',
              icon: const Icon(Icons.open_in_browser_rounded),
              onPressed: () => openExternal(context, _directUrl),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: FutureBuilder<List<int>>(
        future: _future,
        builder: (context, snapshot) {
          // 1. Sedang Mengunduh ke Aplikasi
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.upiYellowDeep.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.upiYellowDeep,
                          strokeWidth: 3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Mengunduh dokumen ke aplikasi...',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _fileName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: context.textMuted,
                      ),
                    ),
                    if (_ukuran.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Ukuran: $_ukuran',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.upiYellowDeep,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }

          // 2. Gagal Mengunduh
          if (snapshot.hasError) {
            final err = snapshot.error.toString();
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.error_outline_rounded,
                        color: AppColors.red,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Gagal Membuka Dokumen',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      err,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: context.textMuted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _future = _fetchBytes();
                            });
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Coba Lagi'),
                        ),
                        if (_directUrl.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.upiYellowDeep,
                              foregroundColor: AppColors.indigo950,
                            ),
                            onPressed: () => openExternal(context, _directUrl),
                            icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                            label: const Text(
                              'Buka di Browser',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            );
          }

          final bytes = snapshot.data ?? <int>[];
          if (bytes.isEmpty) {
            return const Center(
              child: EmptyView(message: 'Berkas dokumen kosong.'),
            );
          }

          // 3. Dokumen Bukan PDF (mis. docx, zip, xls)
          if (!_isPdf(bytes)) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.blue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.description_rounded,
                        color: AppColors.blue,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _judul,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Format: ${_format.toUpperCase()} • $_ukuran',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: context.textMuted,
                      ),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.upiYellowDeep,
                        foregroundColor: AppColors.indigo950,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => _simpanKePerangkat(bytes),
                      icon: const Icon(Icons.download_rounded, size: 20),
                      label: const Text(
                        'Simpan / Buka di Aplikasi Lain',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // 4. Pratinjau PDF Lengkap Langsung di Aplikasi
          return Stack(
            children: [
              PdfPreview(
                build: (format) async => Uint8List.fromList(bytes),
                allowPrinting: true,
                allowSharing: true,
                canChangeOrientation: false,
                canChangePageFormat: false,
                pdfFileName: _fileName,
                previewPageMargin: const EdgeInsets.all(12),
                loadingWidget: const Center(
                  child: LoadingView(label: 'Menyiapkan halaman dokumen...'),
                ),
                actions: [
                  PdfPreviewAction(
                    icon: const Icon(Icons.save_alt_rounded),
                    onPressed: (context, build, pageFormat) async {
                      await _simpanKePerangkat(bytes);
                    },
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

