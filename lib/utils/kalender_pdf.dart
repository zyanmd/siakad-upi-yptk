import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'smart.dart';

/// Helper pembuat dokumen PDF Kalender Akademik resmi secara native & instan (<30ms).
class KalenderPdfHelper {
  static Uint8List? _cachedHeaderBytes;

  static String _formatCurrentDate() {
    final now = DateTime.now();
    final months = [
      '',
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember'
    ];
    return '${now.day} ${months[now.month]} ${now.year}';
  }

  /// Membuat dokumen PDF vektor A4 resmi dari struktur data API kalender akademik
  static Future<Uint8List> buildPdf(
    PdfPageFormat format,
    Map<String, dynamic> data,
  ) async {
    final doc = pw.Document(
      title: 'Kalender Akademik',
      author: 'Universitas Putra Indonesia YPTK Padang',
    );

    final judul = pickString(
      data,
      ['judul'],
      'KALENDER AKADEMIK UNIVERSITAS',
    );
    final periode = pickString(
      data,
      ['periode'],
      'Tahun Akademik • Sistem Informasi Akademik',
    );
    final printMeta = pickString(
      data,
      ['print_meta'],
      'Dicetak melalui SIAKAD pada ${_formatCurrentDate()} • Informasi bersumber dari kalender akademik resmi.',
    );

    // Ambil list kegiatan
    final rawKegiatan = data['kegiatan'];
    final List<Map<String, dynamic>> items = [];
    if (rawKegiatan is List) {
      for (final k in rawKegiatan) {
        if (k is Map) items.add(asMap(k));
      }
    }

    // Kelompokkan kegiatan berdasarkan grup/semester
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final it in items) {
      final rawGrup = pickString(it, ['grup'], '').trim();
      final grupKey = rawGrup.isEmpty
          ? 'Kalender Akademik | Semester Ganjil'
          : rawGrup.replaceAll('Kalender Akademik UPI-YPTK | ', '');
      grouped.putIfAbsent(grupKey, () => []).add(it);
    }

    // Warna resmi UPI YPTK
    const navyColor = PdfColor.fromInt(0xFF263B62);
    const mutedColor = PdfColor.fromInt(0xFF667085);
    const lineColor = PdfColor.fromInt(0xFFCFD6DF);
    const headerBgColor = PdfColor.fromInt(0xFFEEF3F9);
    const altRowColor = PdfColor.fromInt(0xFFFAFBFC);
    const subtotalBgColor = PdfColor.fromInt(0xFFF8FAFC);

    final fontRegular = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();
    final fontOblique = pw.Font.helveticaOblique();

    // Coba ambil logo header gambar secara asynchronous (timeout 800ms)
    pw.ImageProvider? headerImageProvider;
    if (_cachedHeaderBytes != null) {
      headerImageProvider = pw.MemoryImage(_cachedHeaderBytes!);
    } else {
      final headerImgMap = asMap(data['header_image']);
      final src = pickString(
        headerImgMap,
        ['src', 'url'],
        'https://sisfo.upiyptk.ac.id/assets/img/print-header-upi-yptk.png',
      );
      if (src.startsWith('http')) {
        try {
          final dio = Dio(
            BaseOptions(
              connectTimeout: const Duration(milliseconds: 800),
              receiveTimeout: const Duration(milliseconds: 800),
              responseType: ResponseType.bytes,
            ),
          );
          final res = await dio.get<List<int>>(src);
          if (res.statusCode == 200 && res.data != null && res.data!.isNotEmpty) {
            final bytes = Uint8List.fromList(res.data!);
            _cachedHeaderBytes = bytes;
            headerImageProvider = pw.MemoryImage(bytes);
          }
        } catch (_) {}
      }
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        build: (pw.Context context) {
          return [
            // 1. KOP SURAT UNIVERSITAS
            if (headerImageProvider != null)
              pw.Container(
                alignment: pw.Alignment.center,
                margin: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Image(headerImageProvider, height: 48, fit: pw.BoxFit.contain),
              )
            else
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'UNIVERSITAS PUTRA INDONESIA YPTK PADANG',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 14,
                      color: navyColor,
                      letterSpacing: 0.5,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'SISTEM INFORMASI AKADEMIK • KALENDER AKADEMIK RESMI',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 9.5,
                      color: mutedColor,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 1),
                  pw.Text(
                    'Jl. Raya Lubuk Begalung, Padang, Sumatera Barat • Telp: (0751) 776666',
                    style: pw.TextStyle(
                      font: fontRegular,
                      fontSize: 8,
                      color: mutedColor,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              ),

            pw.SizedBox(height: 4),
            pw.Container(
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 1.5)),
              ),
            ),
            pw.SizedBox(height: 1),
            pw.Container(
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5)),
              ),
            ),
            pw.SizedBox(height: 10),

            // 2. JUDUL DOKUMEN & PERIODE
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    judul.toUpperCase(),
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 13.5,
                      color: navyColor,
                      letterSpacing: 0.8,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    periode,
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 9,
                      color: mutedColor,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // 3. TABEL KEGIATAN PER KELOMPOK
            if (grouped.isNotEmpty)
              ...grouped.entries.map((entry) {
                return _buildGroupTablePdf(
                  entry.key,
                  entry.value,
                  fontRegular,
                  fontBold,
                  fontOblique,
                  navyColor,
                  lineColor,
                  headerBgColor,
                  altRowColor,
                  subtotalBgColor,
                );
              })
            else
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 30),
                child: pw.Center(
                  child: pw.Text(
                    'Tidak ada agenda kegiatan yang tercatat.',
                    style: pw.TextStyle(font: fontRegular, fontSize: 10, color: mutedColor),
                  ),
                ),
              ),

            pw.SizedBox(height: 12),

            // 4. FOOTER CETAK
            pw.Center(
              child: pw.Text(
                printMeta,
                style: pw.TextStyle(font: fontRegular, fontSize: 7.5, color: mutedColor),
                textAlign: pw.TextAlign.center,
              ),
            ),
          ];
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _buildGroupTablePdf(
    String groupTitle,
    List<Map<String, dynamic>> list,
    pw.Font fontRegular,
    pw.Font fontBold,
    pw.Font fontOblique,
    PdfColor navyColor,
    PdfColor lineColor,
    PdfColor headerBgColor,
    PdfColor altRowColor,
    PdfColor subtotalBgColor,
  ) {
    final rows = <pw.TableRow>[];

    // Table Header
    rows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: navyColor),
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: pw.Text(
              'NO',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColors.white),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: pw.Text(
              'KEGIATAN AKADEMIK',
              style: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColors.white),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: pw.Text(
              'JADWAL / WAKTU',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColors.white),
            ),
          ),
        ],
      ),
    );

    for (int i = 0; i < list.length; i++) {
      final item = list[i];
      final no = pickString(item, ['no'], '').trim();
      final kegiatan = pickString(item, ['kegiatan'], '-');
      final jadwal = pickString(item, ['jadwal'], '-');

      final isSubItem = no.isEmpty;
      final isMajor = kegiatan.toUpperCase() == kegiatan && kegiatan.length > 5;
      final isEven = i % 2 == 0;

      rows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: isEven ? PdfColors.white : altRowColor,
          ),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
              child: pw.Text(
                no.isNotEmpty ? no : '•',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 7.5,
                  color: isSubItem ? const PdfColor.fromInt(0xFF98A2B3) : navyColor,
                ),
              ),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.only(
                left: isSubItem ? 18 : 6,
                right: 6,
                top: 3.5,
                bottom: 3.5,
              ),
              child: pw.Text(
                kegiatan,
                style: pw.TextStyle(
                  font: (isMajor || no.isNotEmpty) ? fontBold : fontRegular,
                  fontSize: 7.8,
                  color: isMajor ? navyColor : const PdfColor.fromInt(0xFF1D2430),
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
              child: pw.Text(
                jadwal,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  font: isMajor ? fontBold : fontRegular,
                  fontSize: 7.5,
                  color: const PdfColor.fromInt(0xFF263B62),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: lineColor, width: 0.8),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Header Judul Grup
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
            decoration: pw.BoxDecoration(
              color: headerBgColor,
              borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(2.5)),
            ),
            child: pw.Text(
              groupTitle.toUpperCase(),
              style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: navyColor),
            ),
          ),
          pw.Table(
            border: pw.TableBorder.all(color: lineColor, width: 0.5),
            columnWidths: const {
              0: pw.FixedColumnWidth(26),
              1: pw.FlexColumnWidth(3),
              2: pw.FixedColumnWidth(140),
            },
            children: rows,
          ),
        ],
      ),
    );
  }
}

