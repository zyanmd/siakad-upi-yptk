import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'smart.dart';

/// Helper pembuat dokumen PDF Transkrip Nilai Akademik secara native & instan (<30ms).
/// Menggantikan konversi HTML berbasis headless browser yang lambat / freeze.
class TranskripPdfHelper {
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

  /// Membuat dokumen PDF vektor A4 resmi dari struktur data API /api/akademik/transkrip/cetak
  static Future<Uint8List> buildPdf(
    PdfPageFormat format,
    Map<String, dynamic> data,
  ) async {
    final doc = pw.Document(
      title: 'Transkrip Nilai Akademik',
      author: 'Universitas Putra Indonesia YPTK Padang',
    );

    // Ekstraksi identitas mahasiswa
    final mhs = asMap(data['mahasiswa']);
    final nama = pickString(mhs, ['nama'], '-');
    final nim = pickString(mhs, ['nim', 'nobp'], '-');
    final prodi = pickString(mhs, ['program_studi', 'prodi'], '-');
    final fakultas = pickString(mhs, ['fakultas'], 'Ilmu Komputer');
    final angkatan = pickString(mhs, ['angkatan'], '-');
    final program = pickString(mhs, ['program'], 'Reguler');

    // Ekstraksi ringkasan transkrip
    final summary = asMap(data['summary']);
    final ipk = pickString(summary, ['ipk'], '-');
    final totalSks = pickString(summary, ['total_sks'], '-');
    final totalMk = pickString(summary, ['total_mata_kuliah', 'total_courses'], '-');
    final mengulang = pickString(summary, ['mengulang', 'repeated_courses'], '0');

    final tglCetak = _formatCurrentDate();

    // Ekstraksi tanda tangan
    String mhsNama = nama;
    String mhsKet = 'NIM. $nim';
    String pimpinanNama = 'Ketua Program Studi / Pimpinan';
    String pimpinanKet = 'Sistem Informasi Akademik';

    if (data['signatures'] is List) {
      for (final s in (data['signatures'] as List)) {
        if (s is Map) {
          final sm = asMap(s);
          final jab = pickString(sm, ['jabatan', 'label', 'keterangan'], '').toLowerCase();
          final nm = pickString(sm, ['nama'], '');
          final ket = pickString(sm, ['keterangan', 'jabatan'], '');
          if (jab.contains('mahasiswa')) {
            if (nm.isNotEmpty) mhsNama = nm;
            if (ket.isNotEmpty) mhsKet = ket;
          } else if (jab.contains('ketua') || jab.contains('pimpinan') || jab.contains('mengetahui')) {
            if (nm.isNotEmpty) pimpinanNama = nm;
            if (ket.isNotEmpty) pimpinanKet = ket;
          }
        }
      }
    }

    // Ekstraksi periode & mata kuliah
    final rawPeriods = data['periode'];
    final List<Map<String, dynamic>> periods = [];
    if (rawPeriods is List) {
      for (final p in rawPeriods) {
        if (p is Map) {
          periods.add(asMap(p));
        }
      }
    }

    // Persiapan warna tema resmi UPI YPTK
    const navyColor = PdfColor.fromInt(0xFF263B62);
    const goldColor = PdfColor.fromInt(0xFFF4A315);
    const inkColor = PdfColor.fromInt(0xFF1D2430);
    const mutedColor = PdfColor.fromInt(0xFF667085);
    const lineColor = PdfColor.fromInt(0xFFCFD6DF);
    const headerBgColor = PdfColor.fromInt(0xFFEEF3F9);
    const altRowColor = PdfColor.fromInt(0xFFFAFBFC);
    const subtotalBgColor = PdfColor.fromInt(0xFFF8FAFC);

    // Font gaya bawaan PDF
    final fontRegular = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();
    final fontOblique = pw.Font.helveticaOblique();

    // Coba ambil logo header gambar secara asynchronous dengan timeout ketat (800ms)
    // agar preview selalu responsif seketika.
    pw.ImageProvider? headerImageProvider;
    if (_cachedHeaderBytes != null) {
      headerImageProvider = pw.MemoryImage(_cachedHeaderBytes!);
    } else {
      final headerImgMap = asMap(data['header_image']);
      final src = pickString(
        headerImgMap,
        ['src', 'url'],
        'https://sisfo.upiyptk.ac.id/assets/img/print-header-kartu-mahasiswa.png',
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
        } catch (_) {
          // Timeout atau offline, lanjut menggunakan header tipografi vektor resmi
        }
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
                    'FAKULTAS ILMU KOMPUTER • SISTEM INFORMASI AKADEMIK',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 10,
                      color: mutedColor,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 1),
                  pw.Text(
                    'Jl. Raya Lubuk Begalung, Padang, Sumatera Barat • Telp: (0751) 776666',
                    style: pw.TextStyle(
                      font: fontRegular,
                      fontSize: 8.5,
                      color: mutedColor,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              ),

            pw.SizedBox(height: 4),
            pw.Container(
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.black, width: 1.5),
                ),
              ),
            ),
            pw.SizedBox(height: 1),
            pw.Container(
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.black, width: 0.5),
                ),
              ),
            ),
            pw.SizedBox(height: 10),

            // 2. JUDUL DOKUMEN
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    pickString(data, ['judul'], 'TRANSKRIP NILAI AKADEMIK').toUpperCase(),
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 14,
                      color: navyColor,
                      letterSpacing: 0.8,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    pickString(data, ['subjudul'], 'Daftar Hasil Studi Mahasiswa Lintas Periode'),
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 9.5,
                      color: mutedColor,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),

            // 3. IDENTITAS MAHASISWA (2 KOLOM)
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: pw.BoxDecoration(
                color: subtotalBgColor,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                border: pw.Border.all(color: lineColor, width: 0.8),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildMetaRowPdf('NIM / No. BP', nim, fontRegular, fontBold, mutedColor, inkColor),
                        pw.SizedBox(height: 3),
                        _buildMetaRowPdf('Nama Mahasiswa', nama, fontRegular, fontBold, mutedColor, inkColor),
                        pw.SizedBox(height: 3),
                        _buildMetaRowPdf('Program Studi', prodi, fontRegular, fontBold, mutedColor, inkColor),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 14),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildMetaRowPdf('Fakultas', fakultas, fontRegular, fontBold, mutedColor, inkColor),
                        pw.SizedBox(height: 3),
                        _buildMetaRowPdf('Angkatan', angkatan, fontRegular, fontBold, mutedColor, inkColor),
                        pw.SizedBox(height: 3),
                        _buildMetaRowPdf('Program / Kelas', program, fontRegular, fontBold, mutedColor, inkColor),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // 4. TABEL PERIODE DAN MATA KULIAH
            if (periods.isNotEmpty)
              ...periods.map((p) => _buildPeriodBlockPdf(
                    p,
                    fontRegular,
                    fontBold,
                    fontOblique,
                    navyColor,
                    lineColor,
                    headerBgColor,
                    altRowColor,
                    subtotalBgColor,
                  ))
            else
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 24),
                child: pw.Center(
                  child: pw.Text(
                    'Belum ada riwayat nilai transkrip yang tercatat.',
                    style: pw.TextStyle(font: fontRegular, fontSize: 10, color: mutedColor),
                  ),
                ),
              ),

            pw.SizedBox(height: 8),

            // 5. KOTAK RINGKASAN KUMULATIF
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: pw.BoxDecoration(
                color: subtotalBgColor,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                border: pw.Border.all(color: lineColor, width: 0.8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryItemPdf('Total MK', totalMk, false, fontRegular, fontBold, mutedColor, navyColor, goldColor),
                  pw.Container(width: 0.8, height: 24, color: lineColor),
                  _buildSummaryItemPdf('Total SKS', totalSks, false, fontRegular, fontBold, mutedColor, navyColor, goldColor),
                  pw.Container(width: 0.8, height: 24, color: lineColor),
                  _buildSummaryItemPdf('MK Mengulang', mengulang, false, fontRegular, fontBold, mutedColor, navyColor, goldColor),
                  pw.Container(width: 0.8, height: 24, color: lineColor),
                  _buildSummaryItemPdf('IPK Kumulatif', ipk, true, fontRegular, fontBold, mutedColor, navyColor, goldColor),
                ],
              ),
            ),
            pw.SizedBox(height: 8),

            // 6. CATATAN RESMI
            pw.Text(
              pickString(
                data,
                ['catatan'],
                'Catatan: Apabila terdapat mata kuliah yang diulang (termasuk pada sistem kombinasi/siskom), nilai yang diperhitungkan dan dicantumkan pada transkrip adalah nilai tertinggi. Tanda (*) menunjukkan mata kuliah hasil pengulangan.',
              ),
              style: pw.TextStyle(
                font: fontRegular,
                fontSize: 7.5,
                color: mutedColor,
                lineSpacing: 1.2,
              ),
            ),
            pw.SizedBox(height: 18),

            // 7. TANDA TANGAN (MAHASISWA & PIMPINAN)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text('Mahasiswa,', style: pw.TextStyle(font: fontRegular, fontSize: 9.5)),
                    pw.SizedBox(height: 44),
                    pw.Container(
                      padding: const pw.EdgeInsets.only(top: 2),
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(top: pw.BorderSide(color: PdfColors.black, width: 0.8)),
                      ),
                      child: pw.Text(
                        mhsNama,
                        style: pw.TextStyle(font: fontBold, fontSize: 9.5),
                      ),
                    ),
                    pw.SizedBox(height: 1),
                    pw.Text(
                      mhsKet,
                      style: pw.TextStyle(font: fontRegular, fontSize: 8, color: mutedColor),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text('Mengetahui,', style: pw.TextStyle(font: fontRegular, fontSize: 9.5)),
                    pw.SizedBox(height: 44),
                    pw.Container(
                      padding: const pw.EdgeInsets.only(top: 2),
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(top: pw.BorderSide(color: PdfColors.black, width: 0.8)),
                      ),
                      child: pw.Text(
                        pimpinanNama,
                        style: pw.TextStyle(font: fontBold, fontSize: 9.5),
                      ),
                    ),
                    pw.SizedBox(height: 1),
                    pw.Text(
                      pimpinanKet,
                      style: pw.TextStyle(font: fontRegular, fontSize: 8, color: mutedColor),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),

            // 8. METADATA CETAK
            pw.Center(
              child: pw.Text(
                'Dicetak melalui SIAKAD pada $tglCetak • Dokumen ini sah dikeluarkan melalui Sistem Informasi Akademik UPI YPTK.',
                style: pw.TextStyle(font: fontRegular, fontSize: 7, color: mutedColor),
              ),
            ),
          ];
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _buildMetaRowPdf(
    String label,
    String value,
    pw.Font fontRegular,
    pw.Font fontBold,
    PdfColor labelColor,
    PdfColor valueColor,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 76,
          child: pw.Text(
            label,
            style: pw.TextStyle(font: fontRegular, fontSize: 8.5, color: labelColor),
          ),
        ),
        pw.Text(': ', style: pw.TextStyle(font: fontRegular, fontSize: 8.5, color: labelColor)),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: valueColor),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildPeriodBlockPdf(
    Map<String, dynamic> pm,
    pw.Font fontRegular,
    pw.Font fontBold,
    pw.Font fontOblique,
    PdfColor navyColor,
    PdfColor lineColor,
    PdfColor headerBgColor,
    PdfColor altRowColor,
    PdfColor subtotalBgColor,
  ) {
    final pNama = pickString(pm, ['periode'], 'Periode');
    final ips = pickString(pm, ['ips'], '-');
    final subtotal = asMap(pm['subtotal']);
    final subSks = pickString(subtotal, ['sks'], pickString(pm, ['total_sks'], '-'));
    final subMutu = pickString(subtotal, ['mutu'], '-');
    final mks = pm['mata_kuliah'];

    final courseRows = <pw.TableRow>[];

    // Table Header
    courseRows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: navyColor),
        children: [
          _buildThPdf('NO', 22, fontBold),
          _buildThPdf('KODE MK', 60, fontBold),
          _buildThPdf('MATA KULIAH', 0, fontBold, isLeft: true),
          _buildThPdf('SKS', 28, fontBold),
          _buildThPdf('GRADE', 34, fontBold),
          _buildThPdf('BOBOT', 34, fontBold),
          _buildThPdf('MUTU', 34, fontBold),
        ],
      ),
    );

    // Course data rows
    if (mks is List) {
      for (int i = 0; i < mks.length; i++) {
        final m = mks[i];
        if (m is Map) {
          final mm = asMap(m);
          final no = pickString(mm, ['no'], '${i + 1}');
          final kode = pickString(mm, ['kode'], '-');
          final nama = pickString(mm, ['nama'], '-');
          final namaEn = pickString(mm, ['nama_en'], '');
          final sks = pickString(mm, ['sks'], '0');
          final grade = pickString(mm, ['grade'], '-');
          final bobot = pickString(mm, ['bobot'], '-');
          final mutu = pickString(mm, ['mutu'], '-');

          final isEven = i % 2 == 0;
          courseRows.add(
            pw.TableRow(
              decoration: pw.BoxDecoration(
                color: isEven ? PdfColors.white : altRowColor,
              ),
              children: [
                _buildTdPdf(no, fontRegular, align: pw.TextAlign.center),
                _buildTdPdf(kode, fontBold, align: pw.TextAlign.center),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(nama, style: pw.TextStyle(font: fontBold, fontSize: 8)),
                      if (namaEn.isNotEmpty && namaEn != nama)
                        pw.Text(
                          namaEn,
                          style: pw.TextStyle(
                            font: fontOblique,
                            fontSize: 7,
                            color: const PdfColor.fromInt(0xFF667085),
                          ),
                        ),
                    ],
                  ),
                ),
                _buildTdPdf(sks, fontRegular, align: pw.TextAlign.center),
                _buildTdPdf(grade, fontBold, align: pw.TextAlign.center, color: navyColor),
                _buildTdPdf(bobot, fontRegular, align: pw.TextAlign.center),
                _buildTdPdf(mutu, fontRegular, align: pw.TextAlign.center),
              ],
            ),
          );
        }
      }
    }

    // Subtotal Row
    courseRows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(
          color: subtotalBgColor,
          border: const pw.Border(top: pw.BorderSide(color: PdfColor.fromInt(0xFFCFD6DF), width: 0.8)),
        ),
        children: [
          pw.Container(),
          pw.Container(),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: pw.Text(
              'SUBTOTAL $pNama',
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(font: fontBold, fontSize: 8, color: navyColor),
            ),
          ),
          _buildTdPdf(subSks, fontBold, align: pw.TextAlign.center, color: navyColor),
          pw.Container(),
          pw.Container(),
          _buildTdPdf(subMutu, fontBold, align: pw.TextAlign.center, color: navyColor),
        ],
      ),
    );

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: lineColor, width: 0.8),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Period Header Bar
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: pw.BoxDecoration(
              color: headerBgColor,
              borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(2.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  pNama,
                  style: pw.TextStyle(font: fontBold, fontSize: 9, color: navyColor),
                ),
                pw.Text(
                  'IPS: $ips',
                  style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: navyColor),
                ),
              ],
            ),
          ),
          // Table
          pw.Table(
            border: pw.TableBorder.all(color: lineColor, width: 0.5),
            columnWidths: const {
              0: pw.FixedColumnWidth(22),
              1: pw.FixedColumnWidth(60),
              2: pw.FlexColumnWidth(3),
              3: pw.FixedColumnWidth(28),
              4: pw.FixedColumnWidth(34),
              5: pw.FixedColumnWidth(34),
              6: pw.FixedColumnWidth(34),
            },
            children: courseRows,
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildThPdf(String label, double width, pw.Font fontBold, {bool isLeft = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3.5),
      child: pw.Text(
        label,
        textAlign: isLeft ? pw.TextAlign.left : pw.TextAlign.center,
        style: pw.TextStyle(font: fontBold, fontSize: 7.5, color: PdfColors.white),
      ),
    );
  }

  static pw.Widget _buildTdPdf(
    String text,
    pw.Font font, {
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          font: font,
          fontSize: 8,
          color: color ?? const PdfColor.fromInt(0xFF1D2430),
        ),
      ),
    );
  }

  static pw.Widget _buildSummaryItemPdf(
    String label,
    String value,
    bool isHighlight,
    pw.Font fontRegular,
    pw.Font fontBold,
    PdfColor mutedColor,
    PdfColor navyColor,
    PdfColor goldColor,
  ) {
    return pw.Column(
      children: [
        pw.Text(
          label.toUpperCase(),
          style: pw.TextStyle(font: fontRegular, fontSize: 7, color: mutedColor),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            font: fontBold,
            fontSize: isHighlight ? 11 : 9.5,
            color: isHighlight ? goldColor : navyColor,
          ),
        ),
      ],
    );
  }
}
