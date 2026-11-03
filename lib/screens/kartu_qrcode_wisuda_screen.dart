import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/wisuda_service.dart';
import '../theme/app_theme.dart';
import '../utils/smart.dart';
import '../widgets/common.dart';
import 'foto_ijazah_screen.dart';

// ── UPI YPTK Golden Yellow Gradient (konsisten dengan Dashboard & Profil) ──
const _yellowHeaderGradient = [
  Color(0xFFE5A620), // Bright Academic Gold
  Color(0xFFD48B08), // UPI Yellow
  Color(0xFFB87500), // Deep Academic Gold
];

/// Layar Resmi Kartu QR Code Wisudawan (Kokarde Presensi Wisuda UPI YPTK Padang).
/// Menampilkan informasi wisudawan, QR Code presensi resmi, kartu kokarde,
/// serta panduan pelaksanaan wisuda dengan tata letak adaptif mobile.
class KartuQrCodeWisudaScreen extends StatefulWidget {
  const KartuQrCodeWisudaScreen({super.key});

  @override
  State<KartuQrCodeWisudaScreen> createState() => _KartuQrCodeWisudaScreenState();
}

class _KartuQrCodeWisudaScreenState extends State<KartuQrCodeWisudaScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic> _data = {};
  Uint8List? _qrBytes;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final srv = WisudaService(context.read<ApiClient>());
      final resp = await srv.getKartuQrCode();
      final map = asMap(resp);
      final data = asMap(map['data'] ?? map);

      Uint8List? bytes;
      // 1. Coba decode dari base64 qrcode.image_src
      final qrInfo = asMap(data['qrcode']);
      final imgSrc = pickString(qrInfo, ['image_src', 'src'], '');
      if (imgSrc.contains('base64,')) {
        try {
          final b64 = imgSrc.split('base64,').last.trim();
          bytes = base64Decode(b64);
        } catch (_) {}
      }

      // 2. Jika belum ada dari base64, coba fetch binary dari endpoint image
      if (bytes == null || bytes.isEmpty) {
        try {
          final rawBytes = await srv.getKartuQrCodeImageBytes();
          if (rawBytes.isNotEmpty) {
            bytes = Uint8List.fromList(rawBytes);
          }
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _data = data;
        _qrBytes = bytes;
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

  // ────────────────────────────────────────────────── CETAK / SIMPAN PDF KOKARDE
  Future<void> _cetakKartuPdf() async {
    try {
      HapticFeedback.lightImpact();
      final pdf = pw.Document();

      final mhs = asMap(_data['mahasiswa']);
      final kokarde = asMap(_data['kokarde']);
      final nama = pickString(kokarde, ['nama'], pickString(mhs, ['nama'], 'WISUDAWAN'));
      final nim = pickString(kokarde, ['nim'], pickString(mhs, ['nim'], '-'));
      final prodi = pickString(kokarde, ['program_studi'], pickString(mhs, ['program_studi'], '-'));
      final fakultas = pickString(kokarde, ['fakultas'], pickString(mhs, ['fakultas'], '-'));
      final periode = pickString(kokarde, ['periode'], pickString(mhs, ['periode_wisuda'], 'WISUDA PERIODE 1'));
      final tahun = pickString(kokarde, ['tahun'], pickString(mhs, ['tahun_akademik'], ''));

      pw.ImageProvider? qrImage;
      if (_qrBytes != null) {
        qrImage = pw.MemoryImage(_qrBytes!);
      }

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context ctx) {
            return pw.Center(
              child: pw.Container(
                width: 320,
                padding: const pw.EdgeInsets.all(24),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.amber800, width: 2),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(16)),
                ),
                child: pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Text(
                      'UNIVERSITAS PUTRA INDONESIA YPTK PADANG',
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.amber900,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'KARTU PRESENSI WISUDAWAN',
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey900,
                      ),
                    ),
                    if (periode.isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        '$periode $tahun'.trim(),
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                    pw.SizedBox(height: 16),
                    if (qrImage != null)
                      pw.Container(
                        width: 170,
                        height: 170,
                        padding: const pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey400, width: 1),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                        ),
                        child: pw.Image(qrImage),
                      )
                    else
                      pw.Container(
                        width: 170,
                        height: 170,
                        alignment: pw.Alignment.center,
                        child: pw.Text('QR Code Belum Tersedia'),
                      ),
                    pw.SizedBox(height: 16),
                    pw.Text(
                      nama,
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey900,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'NIM: $nim',
                      style: const pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.amber900,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      prodi,
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
                    ),
                    pw.Text(
                      fakultas,
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700),
                    ),
                    pw.SizedBox(height: 14),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.green50,
                        borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                      ),
                      child: pw.Text(
                        'STATUS: DATA VALID UNTUK PRESENSI',
                        style: const pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Kartu_Wisudawan_$nim.pdf',
      );
    } catch (e) {
      if (mounted) {
        appToast(context, 'Gagal mencetak dokumen: $e');
      }
    }
  }

  // ────────────────────────────────────────────────── ZOOM QR DIALOG ADAPTIF MOBILE
  void _zoomQrDialog() {
    if (_qrBytes == null) return;
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (ctx) {
        final screenWidth = MediaQuery.sizeOf(ctx).width;
        final dialogQrSize = (screenWidth * 0.62).clamp(170.0, 240.0);

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'QR Code Presensi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: Colors.grey),
                      onPressed: () => Navigator.of(ctx).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200, width: 1.5),
                  ),
                  child: Image.memory(
                    _qrBytes!,
                    width: dialogQrSize,
                    height: dialogQrSize,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Tunjukkan kode QR ini ke panitia untuk presensi saat pelaksanaan wisuda.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121214) : const Color(0xFFF8FAFC),
      body: _isLoading
          ? _buildLoadingSkeleton()
          : _error != null
              ? _buildErrorView()
              : _buildMainContent(),
    );
  }

  // ────────────────────────────────────────────────── MAIN CONTENT
  Widget _buildMainContent() {
    final mhs = asMap(_data['mahasiswa']);
    final kokarde = asMap(_data['kokarde']);
    final panduan = (_data['panduan'] as List?)?.map((e) => e.toString()).toList() ?? [];

    final nama = pickString(kokarde, ['nama'], pickString(mhs, ['nama'], 'WISUDAWAN'));
    final nim = pickString(kokarde, ['nim'], pickString(mhs, ['nim'], '-'));
    final prodi = pickString(kokarde, ['program_studi'], pickString(mhs, ['program_studi'], '-'));
    final fakultas = pickString(kokarde, ['fakultas'], pickString(mhs, ['fakultas'], '-'));
    final periode = pickString(kokarde, ['periode'], pickString(mhs, ['periode_wisuda'], 'WISUDA PERIODE 1'));
    final tahun = pickString(kokarde, ['tahun'], pickString(mhs, ['tahun_akademik'], ''));
    final statusValidasi = pickString(_data, ['status_validasi'], 'Data Valid');
    final isValid = _data['is_valid'] == true || statusValidasi.toLowerCase().contains('valid');

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.upiYellowDeep,
      child: ListView(
        padding: EdgeInsets.zero,
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        children: [
          // ── Header Lekukan Gelombang Kuning Khas SIAKAD ──
          _buildCurvedYellowHeader(nama, nim),

          // ── Floating Status Pill (Responsif Mobile) ──
          Transform.translate(
            offset: const Offset(0, -20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildFloatingStatusPill(statusValidasi, isValid),
            ),
          ),

          // ── Isi Konten Halaman Terpusat & Responsif ──
          ResponsiveCenter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 60),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. KOKARDE WISUDA PASS CARD
                  _buildKokardeCard(
                    context,
                    nama: nama,
                    nim: nim,
                    prodi: prodi,
                    fakultas: fakultas,
                    periode: periode,
                    tahun: tahun,
                    isValid: isValid,
                  ),
                  const SizedBox(height: 18),

                  // 2. TOMBOL AKSI CETAK & UNDUH
                  Row(
                    children: [
                      Expanded(
                        child: IosBounceTap(
                          onTap: _cetakKartuPdf,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: _yellowHeaderGradient,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.upiYellowDeep.withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.print_rounded, size: 18, color: Colors.white),
                                SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Cetak / Simpan PDF',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IosBounceTap(
                        onTap: () {
                          copyText(context, nim);
                          HapticFeedback.lightImpact();
                          appToast(context, 'NIM berhasil disalin: $nim');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: context.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: context.isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.copy_rounded,
                            size: 19,
                            color: context.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 3. TAUTAN KE FOTO IJAZAH
                  _buildFotoIjazahBanner(),
                  const SizedBox(height: 22),

                  // 4. RINCIAN IDENTITAS WISUDAWAN
                  const SectionTitle('Rincian Identitas Wisudawan'),
                  const SizedBox(height: 10),
                  _buildNeuCard(
                    child: Column(
                      children: [
                        _buildInfoTile(
                          icon: Icons.person_outline_rounded,
                          iconColor: AppColors.blue,
                          label: 'Nama Wisudawan',
                          value: nama,
                        ),
                        _buildInfoTile(
                          icon: Icons.badge_outlined,
                          iconColor: AppColors.upiYellowDeep,
                          label: 'Nomor Induk Mahasiswa (NIM)',
                          value: nim,
                          onCopy: () => copyText(context, nim),
                        ),
                        _buildInfoTile(
                          icon: Icons.school_outlined,
                          iconColor: const Color(0xFF8B5CF6),
                          label: 'Program Studi',
                          value: prodi,
                        ),
                        _buildInfoTile(
                          icon: Icons.apartment_rounded,
                          iconColor: Colors.teal,
                          label: 'Fakultas',
                          value: fakultas,
                        ),
                        _buildInfoTile(
                          icon: Icons.event_available_rounded,
                          iconColor: Colors.deepOrange,
                          label: 'Periode Wisuda',
                          value: '$periode $tahun'.trim(),
                        ),
                        _buildInfoTile(
                          icon: Icons.verified_user_outlined,
                          iconColor: isValid ? AppColors.green : Colors.amber,
                          label: 'Status Validasi Data',
                          value: statusValidasi,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // 5. PANDUAN PELAKSANAAN WISUDA
                  if (panduan.isNotEmpty) ...[
                    const SectionTitle('Panduan Cetak & Presensi'),
                    const SizedBox(height: 10),
                    _buildPanduanCard(panduan),
                    const SizedBox(height: 22),
                  ],

                  // Footer
                  Center(
                    child: Text(
                      'Sistem Informasi Akademik • UPI YPTK Padang',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.textMuted,
                        fontWeight: FontWeight.w600,
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

  // ────────────────────────────────────────────────── KOKARDE PASS CARD ADAPTIF
  Widget _buildKokardeCard(
    BuildContext context, {
    required String nama,
    required String nim,
    required String prodi,
    required String fakultas,
    required String periode,
    required String tahun,
    required bool isValid,
  }) {
    final isDark = context.isDark;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final qrBoxSize = (screenWidth * 0.46).clamp(145.0, 190.0);

    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.upiYellowDeep.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.upiYellowDeep.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Lanyard Clip Hole (Aksen Gantungan Kartu)
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 44,
            height: 7,
            decoration: BoxDecoration(
              color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(8),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
            child: Column(
              children: [
                // Header Institusi Kokarde
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: AppColors.amber.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.school_rounded,
                        size: 20,
                        color: AppColors.upiYellowDeep,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'UNIVERSITAS PUTRA INDONESIA YPTK',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                              color: AppColors.upiYellowDeep,
                            ),
                          ),
                          Text(
                            'KARTU PRESENSI RESMI WISUDAWAN',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: context.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(height: 1, color: isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
                const SizedBox(height: 14),

                // Frame Gambar QR Code Presensi
                GestureDetector(
                  onTap: _zoomQrDialog,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppColors.upiYellowDeep.withValues(alpha: 0.35),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        if (_qrBytes != null)
                          Image.memory(
                            _qrBytes!,
                            width: qrBoxSize,
                            height: qrBoxSize,
                            fit: BoxFit.contain,
                          )
                        else
                          Container(
                            width: qrBoxSize,
                            height: qrBoxSize,
                            color: const Color(0xFFF8FAFC),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.qr_code_2_rounded, size: 48, color: Colors.grey),
                                const SizedBox(height: 6),
                                Text(
                                  isValid ? 'Menyiapkan QR Code...' : 'QR Belum Tersedia',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.zoom_in_rounded, size: 15, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              'Ketuk untuk perbesar',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Nama & NIM
                Text(
                  nama,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w900,
                    color: context.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.upiYellowDeep.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'NIM: $nim',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.upiYellowDeep,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Prodi & Fakultas
                Text(
                  prodi,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  fakultas,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: context.textMuted,
                  ),
                ),
                const SizedBox(height: 12),

                // Footer Periode Wisuda
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        periode.toUpperCase(),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.upiYellowDeep,
                        ),
                      ),
                      if (tahun.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          tahun.toUpperCase(),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: context.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────── HEADER KUNING LEKUKAN
  Widget _buildCurvedYellowHeader(String nama, String nim) {
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
            padding: const EdgeInsets.fromLTRB(20, 12, 20, kCurvedHeaderBottomPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Baris Navigasi & Reload
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          if (canPop) ...[
                            IconButton(
                              onPressed: () {
                                Navigator.of(context).maybePop();
                              },
                              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 8),
                          ],
                          const Expanded(
                            child: Text(
                              'QR Code Wisudawan',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IosBounceTap(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _loadData();
                        appToast(context, 'Memuat ulang data...');
                      },
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          shape: BoxShape.circle,
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
                const SizedBox(height: 14),

                // Baris Profil Wisudawan (Avatar Ring + Nama + NIM)
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.90),
                          width: 2.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _initials(nama),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
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
                            nama.isNotEmpty ? nama : 'Mahasiswa Wisudawan',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            nim.isNotEmpty ? 'NIM $nim' : '-',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xE6FFFFFF),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.2,
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

  // ────────────────────────────────────────────────── FLOATING STATUS PILL
  Widget _buildFloatingStatusPill(String statusValidasi, bool isValid) {
    final isDark = context.isDark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isValid ? AppColors.green : Colors.amber,
              boxShadow: [
                BoxShadow(
                  color: (isValid ? AppColors.green : Colors.amber).withValues(alpha: 0.45),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Status Kelulusan / Wisuda',
                  style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600),
                ),
                Text(
                  statusValidasi,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isValid ? AppColors.green : Colors.amber.shade800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (isValid ? AppColors.green : Colors.amber).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isValid ? Icons.check_circle_rounded : Icons.info_rounded,
                  size: 13,
                  color: isValid ? AppColors.green : Colors.amber.shade800,
                ),
                const SizedBox(width: 4),
                Text(
                  isValid ? 'Terverifikasi' : 'Proses',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isValid ? AppColors.green : Colors.amber.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────── BANNER FOTO IJAZAH
  Widget _buildFotoIjazahBanner() {
    return IosBounceTap(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FotoIjazahScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.blue.withValues(alpha: 0.12),
              AppColors.upiYellowDeep.withValues(alpha: 0.12),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.blue.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.blue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.account_box_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Kelola Foto Ijazah Wisuda',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Pastikan pas foto resmi jas/kebaya telah diunggah dan disetujui.',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: context.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────── PANDUAN WISUDA CARD
  Widget _buildPanduanCard(List<String> panduan) {
    return _buildNeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < panduan.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppColors.upiYellowDeep.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.upiYellowDeep,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      panduan[i],
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: context.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (i < panduan.length - 1)
              Divider(height: 12, color: context.isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
          ],
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────── NEU CARD & INFO TILE HELPERS
  Widget _buildNeuCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(18),
  }) {
    final isDark = context.isDark;
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.35)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: padding,
      child: child,
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    VoidCallback? onCopy,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: context.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (onCopy != null)
            IconButton(
              icon: Icon(
                Icons.copy_rounded,
                size: 16,
                color: context.textMuted,
              ),
              tooltip: 'Salin',
              onPressed: onCopy,
              splashRadius: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────── LOADING SKELETON
  Widget _buildLoadingSkeleton() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppColors.upiYellowDeep),
          ),
          const SizedBox(height: 16),
          Text(
            'Memuat Kartu QR Code Wisudawan...',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────── ERROR VIEW
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, color: AppColors.red, size: 36),
            ),
            const SizedBox(height: 18),
            const Text(
              'Gagal Memuat Kartu Wisuda',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Terjadi kesalahan sistem.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: context.textMuted),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.upiYellowDeep,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String nama) {
    final parts = nama.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return 'W';
    return parts.first.substring(0, 1).toUpperCase();
  }
}
