import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../services/akademik_service.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../utils/smart.dart';
import '../utils/transkrip_pdf.dart';
import '../widgets/common.dart';
import '../widgets/gradient_header.dart';

/// Halaman tampilan resmi lembar cetak Transkrip Nilai Akademik
/// yang menampilkan dokumen cetak resmi lintas periode di dalam aplikasi
/// dan menyediakan fungsi Cetak PDF langsung (native print / save as PDF).
class TranskripCetakScreen extends StatefulWidget {
  const TranskripCetakScreen({super.key});

  @override
  State<TranskripCetakScreen> createState() => _TranskripCetakScreenState();
}

class _TranskripCetakScreenState extends State<TranskripCetakScreen> {
  late Future<Map<String, dynamic>> _future;
  bool _isPrinting = false;
  int _viewMode = 1; // 1: Pratinjau PDF Vektor Instan (default), 0: Lembar Kertas UI

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  Future<Map<String, dynamic>> _loadData() async {
    final api = context.read<ApiClient>();
    final srv = AkademikService(api);

    Map<String, dynamic> result = {};

    // 1. Panggil endpoint resmi GET /api/akademik/transkrip/cetak
    try {
      final cetakResp = await srv.transkripCetak();
      final map = asMap(cetakResp);
      final data = asMap(map['data'] ?? map);
      if (data.isNotEmpty) {
        result = data;
      }
    } catch (_) {}

    // 2. Jika cetak kosong, fallback ke /api/akademik/transkrip/data
    if (result.isEmpty || result['periode'] == null) {
      try {
        final dataResp = await srv.transkripData();
        final dMap = asMap(dataResp);
        final dData = asMap(dMap['data'] ?? dMap);
        final inner = asMap(dData['data'] ?? dData);
        final grouped = inner['grouped_periods'];
        final student = asMap(inner['student']);
        final summary = asMap(inner['summary']);

        if (grouped is List && grouped.isNotEmpty) {
          final normalizedPeriods = <Map<String, dynamic>>[];
          int courseNo = 1;

          for (final gp in grouped) {
            if (gp is Map) {
              final gMap = asMap(gp);
              final courses = gMap['courses'];
              final mkList = <Map<String, dynamic>>[];

              if (courses is List) {
                for (final c in courses) {
                  if (c is Map) {
                    final cm = asMap(c);
                    mkList.add({
                      'no': '${courseNo++}',
                      'kode': pickString(cm, ['kode_mk'], '-'),
                      'nama': pickString(cm, ['nama_mk'], 'Mata Kuliah'),
                      'nama_en': pickString(cm, ['nama_english'], ''),
                      'sks': pickString(cm, ['sks'], '0'),
                      'grade': pickString(cm, ['grade'], '-'),
                      'bobot': pickString(cm, ['bobot'], '-'),
                      'mutu': pickString(cm, ['mutu'], '-'),
                    });
                  }
                }
              }

              normalizedPeriods.add({
                'periode': pickString(gMap, ['label', 'periode'], 'Periode'),
                'ips': pickString(gMap, ['ips'], '0,00'),
                'jumlah_mata_kuliah': '${mkList.length} Mata Kuliah',
                'total_sks': '${pickString(gMap, ['total_sks'], '0')} SKS',
                'subtotal': {
                  'sks': pickString(gMap, ['total_sks'], '0'),
                  'mutu': pickString(gMap, ['total_mutu'], '0'),
                },
                'mata_kuliah': mkList,
              });
            }
          }

          result = {
            'judul': 'TRANSKRIP NILAI AKADEMIK',
            'subjudul': 'Daftar Hasil Studi Mahasiswa Lintas Periode',
            'mahasiswa': {
              'nama': pickString(student, ['nama'], ''),
              'nim': pickString(student, ['nim'], ''),
              'program_studi': pickString(student, ['program_studi'], ''),
              'fakultas': pickString(student, ['fakultas'], ''),
              'angkatan': pickString(student, ['angkatan'], ''),
              'program': pickString(student, ['program'], 'Reguler'),
            },
            'periode': normalizedPeriods,
            'summary': {
              'ipk': pickString(summary, ['ipk'], '0,00'),
              'total_sks': '${pickString(summary, ['total_sks', 'passed_sks'], '0')} SKS',
              'total_mata_kuliah': pickString(summary, ['total_courses'], '0'),
              'mengulang': pickString(summary, ['repeated_courses'], '0'),
            },
            'signatures': [
              {
                'label': 'Mahasiswa,',
                'nama': pickString(student, ['nama'], ''),
                'keterangan': 'NIM. ${pickString(student, ['nim'], '')}',
              },
              {
                'label': 'Mengetahui,',
                'nama': 'Ketua Program Studi / Pimpinan',
                'keterangan': 'Sistem Informasi Akademik',
              },
            ],
          };
        }
      } catch (_) {}
    }

    return result;
  }

  Future<void> _cetakPdf(Map<String, dynamic> data) async {
    if (_isPrinting) return;
    setState(() => _isPrinting = true);
    try {
      final nim = pickString(asMap(data['mahasiswa']), ['nim', 'nobp'], 'UPI');
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async {
          return await TranskripPdfHelper.buildPdf(format, data);
        },
        name: 'Transkrip_Nilai_$nim.pdf',
      );
    } catch (e) {
      if (mounted) {
        appToast(context, 'Gagal mencetak dokumen: $e', error: true);
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  void _salinRincian(Map<String, dynamic> data) {
    final mhs = asMap(data['mahasiswa']);
    final nama = pickString(mhs, ['nama'], '-');
    final nim = pickString(mhs, ['nim', 'nobp'], '-');
    final prodi = pickString(mhs, ['program_studi', 'prodi'], '-');
    final summary = asMap(data['summary']);
    final ipk = pickString(summary, ['ipk'], '-');
    final totalSks = pickString(summary, ['total_sks'], '-');
    final totalMk = pickString(summary, ['total_mata_kuliah'], '-');

    final buffer = StringBuffer();
    buffer.writeln('TRANSKRIP NILAI AKADEMIK');
    buffer.writeln('UNIVERSITAS PUTRA INDONESIA YPTK PADANG');
    buffer.writeln('----------------------------------------');
    buffer.writeln('Nama Mahasiswa : $nama');
    buffer.writeln('NIM / No. BP   : $nim');
    buffer.writeln('Program Studi  : $prodi');
    buffer.writeln('IPK            : $ipk');
    buffer.writeln('Total SKS      : $totalSks');
    buffer.writeln('Total Mata Kuliah: $totalMk');
    buffer.writeln('----------------------------------------');

    final periods = data['periode'];
    if (periods is List) {
      for (final p in periods) {
        if (p is Map) {
          final pm = asMap(p);
          final pNama = pickString(pm, ['periode'], '-');
          final ips = pickString(pm, ['ips'], '-');
          buffer.writeln('\n[ $pNama ] - IPS: $ips');
          final mks = pm['mata_kuliah'];
          if (mks is List) {
            for (final m in mks) {
              if (m is Map) {
                final mm = asMap(m);
                final no = pickString(mm, ['no'], '-');
                final kode = pickString(mm, ['kode'], '-');
                final matkul = pickString(mm, ['nama'], '-');
                final sks = pickString(mm, ['sks'], '0');
                final grade = pickString(mm, ['grade'], '-');
                final mutu = pickString(mm, ['mutu'], '-');
                buffer.writeln('$no. [$kode] $matkul ($sks SKS) - Grade: $grade (Mutu: $mutu)');
              }
            }
          }
        }
      }
    }
    buffer.writeln('----------------------------------------');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    appToast(context, 'Rincian transkrip berhasil disalin ke clipboard.');
  }

  String _formatCurrentDate() {
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

  // ignore: unused_element
  String _buildPrintableHtml(Map<String, dynamic> data) {
    final existingHtml = pickString(data, ['html', 'raw_html'], '');
    if (existingHtml.isNotEmpty &&
        existingHtml.contains('<html') &&
        existingHtml.contains('sheet')) {
      return existingHtml;
    }

    final mhs = asMap(data['mahasiswa']);
    final nama = pickString(mhs, ['nama'], '-');
    final nim = pickString(mhs, ['nim', 'nobp'], '-');
    final prodi = pickString(mhs, ['program_studi', 'prodi'], '-');
    final fakultas = pickString(mhs, ['fakultas'], 'Ilmu Komputer');
    final angkatan = pickString(mhs, ['angkatan'], '-');
    final program = pickString(mhs, ['program'], 'Reguler');

    final summary = asMap(data['summary']);
    final ipk = pickString(summary, ['ipk'], '-');
    final totalSks = pickString(summary, ['total_sks'], '-');
    final totalMk = pickString(summary, ['total_mata_kuliah'], '-');
    final mengulang = pickString(summary, ['mengulang'], '0');

    final tglCetak = _formatCurrentDate();

    // Tanda tangan
    String mhsNama = nama;
    String pimpinanNama = 'Ketua Program Studi / Pimpinan';
    if (data['signatures'] is List) {
      for (final s in (data['signatures'] as List)) {
        if (s is Map) {
          final sm = asMap(s);
          final jab = pickString(sm, ['jabatan', 'label', 'keterangan'], '').toLowerCase();
          final nm = pickString(sm, ['nama'], '');
          if (jab.contains('mahasiswa')) {
            if (nm.isNotEmpty) mhsNama = nm;
          } else if (jab.contains('ketua') || jab.contains('pimpinan') || jab.contains('mengetahui')) {
            if (nm.isNotEmpty) pimpinanNama = nm;
          }
        }
      }
    }

    final periods = data['periode'];
    final bufferPeriods = StringBuffer();

    if (periods is List) {
      for (final p in periods) {
        if (p is Map) {
          final pm = asMap(p);
          final pNama = pickString(pm, ['periode'], '-');
          final ips = pickString(pm, ['ips'], '-');
          final subtotal = asMap(pm['subtotal']);
          final subSks = pickString(subtotal, ['sks'], pickString(pm, ['total_sks'], '-'));
          final subMutu = pickString(subtotal, ['mutu'], '-');
          final mks = pm['mata_kuliah'];

          bufferPeriods.writeln('''
          <div class="period-block">
            <div class="period-header">
              <span>$pNama</span>
              <span class="badge-info">IPS: $ips</span>
            </div>
            <table>
              <thead>
                <tr>
                  <th style="width: 5%">No</th>
                  <th style="width: 14%">Kode MK</th>
                  <th style="width: 45%">Mata Kuliah</th>
                  <th style="width: 8%">SKS</th>
                  <th style="width: 8%">Grade</th>
                  <th style="width: 10%">Bobot</th>
                  <th style="width: 10%">Mutu</th>
                </tr>
              </thead>
              <tbody>
          ''');

          if (mks is List) {
            for (final m in mks) {
              if (m is Map) {
                final mm = asMap(m);
                final no = pickString(mm, ['no'], '-');
                final kode = pickString(mm, ['kode'], '-');
                final matkul = pickString(mm, ['nama'], 'Mata Kuliah');
                final matkulEn = pickString(mm, ['nama_en'], '');
                final sks = pickString(mm, ['sks'], '0');
                final grade = pickString(mm, ['grade'], '-');
                final bobot = pickString(mm, ['bobot'], '-');
                final mutu = pickString(mm, ['mutu'], '-');

                bufferPeriods.writeln('''
                <tr>
                  <td class="center">$no</td>
                  <td class="center"><strong>$kode</strong></td>
                  <td class="course">
                    <strong>$matkul</strong>
                    ${matkulEn.isNotEmpty ? '<span>$matkulEn</span>' : ''}
                  </td>
                  <td class="center">$sks</td>
                  <td class="center"><strong>$grade</strong></td>
                  <td class="center">$bobot</td>
                  <td class="center">$mutu</td>
                </tr>
                ''');
              }
            }
          }

          bufferPeriods.writeln('''
              </tbody>
              <tfoot>
                <tr>
                  <td colspan="3" style="text-align: right"><strong>SUBTOTAL $pNama</strong></td>
                  <td class="center"><strong>$subSks</strong></td>
                  <td colspan="2"></td>
                  <td class="center"><strong>$subMutu</strong></td>
                </tr>
              </tfoot>
            </table>
          </div>
          ''');
        }
      }
    }

    return '''
<!doctype html>
<html lang="id">
<head>
  <meta charset="utf-8">
  <title>Transkrip Nilai - $nim</title>
  <style>
    :root { --navy: #263b62; --gold: #f4a315; --ink: #1d2430; --muted: #667085; --line: #cfd6df; }
    * { box-sizing: border-box; }
    body { margin: 0; background: #edf0f4; color: var(--ink); font: 12px/1.45 Arial, Helvetica, sans-serif; }
    .sheet { width: 210mm; min-height: 297mm; margin: 18px auto; padding: 14mm 13mm; background: #fff; box-shadow: 0 12px 32px rgba(15,23,42,.14); }
    .institution-head { padding: 0 0 8px; border-bottom: 2px solid #111; }
    .institution-head img { display: block; width: 100%; height: auto; }
    .document-title { margin: 17px 0 15px; text-align: center; }
    .document-title h1 { margin: 0; color: var(--navy); font-size: 19px; letter-spacing: .08em; }
    .document-title p { margin: 4px 0 0; color: var(--muted); font-size: 12px; font-weight: 700; }
    .student-data { display: grid; grid-template-columns: 1fr 1fr; gap: 6px 28px; margin-bottom: 16px; padding: 12px 14px; border: 1px solid var(--line); border-left: 4px solid var(--gold); border-radius: 6px; }
    .data-row { display: grid; grid-template-columns: 110px 8px 1fr; gap: 2px; font-size: 11.5px; }
    .data-row span { color: var(--muted); }
    .data-row strong { font-weight: 700; }
    
    .period-block { margin-bottom: 16px; break-inside: avoid; }
    .period-header { display: flex; align-items: center; justify-content: space-between; padding: 6px 10px; background: #eef3f9; border: 1px solid var(--line); border-bottom: 0; border-radius: 6px 6px 0 0; font-size: 11.5px; font-weight: 800; color: var(--navy); }
    .period-header span.badge-info { font-size: 10.5px; font-weight: 600; color: var(--muted); }

    table { width: 100%; border-collapse: collapse; margin-bottom: 2px; }
    th, td { padding: 6px 7px; border: 1px solid var(--line); vertical-align: middle; }
    th { background: var(--navy); color: #fff; font-size: 11px; letter-spacing: .03em; text-align: center; text-transform: uppercase; font-weight: 700; }
    td { font-size: 11px; }
    td.center { text-align: center; }
    td.course strong { display: block; font-size: 11.5px; color: #1a2233; }
    td.course span { display: block; margin-top: 1px; color: var(--muted); font-size: 10px; }
    tfoot td { background: #f8fafc; font-weight: 800; font-size: 11px; }

    .summary-box { display: grid; grid-template-columns: repeat(4, 1fr); gap: 10px; margin-top: 16px; }
    .summary-item { padding: 8px 12px; border: 1px solid var(--line); border-radius: 6px; background: #f8fafc; font-size: 11.5px; text-align: center; }
    .summary-item span { display: block; color: var(--muted); font-size: 10px; text-transform: uppercase; }
    .summary-item strong { display: block; margin-top: 2px; color: var(--navy); font-size: 14px; }
    
    .notes { margin-top: 14px; color: var(--muted); font-size: 10px; line-height: 1.5; }
    .signatures { display: grid; grid-template-columns: 1fr 1fr; gap: 80px; margin-top: 36px; text-align: center; break-inside: avoid; }
    .signature-space { height: 60px; }
    .signature-name { display: inline-block; min-width: 200px; padding-top: 4px; border-top: 1px solid #333; font-size: 12px; font-weight: 700; }
    .signature-id { display: block; color: var(--muted); font-size: 10.5px; margin-top: 2px; }
    .print-meta { margin-top: 26px; padding-top: 8px; border-top: 1px dashed var(--line); color: #7b8491; font-size: 9px; text-align: center; }
    @page { size: A4 portrait; margin: 10mm; }
    @media print {
      body { background: #fff; }
      .sheet { width: auto; min-height: auto; margin: 0; padding: 0; box-shadow: none; }
      .institution-head, .period-block, .student-data, .signatures { break-inside: avoid; }
    }
  </style>
</head>
<body>
  <main class="sheet">
    <header class="institution-head">
      <img src="https://sisfo.upiyptk.ac.id/assets/img/print-header-kartu-mahasiswa.png" alt="Universitas Putra Indonesia YPTK">
    </header>

    <section class="document-title">
      <h1>TRANSKRIP NILAI AKADEMIK</h1>
      <p>Daftar Hasil Studi Mahasiswa Lintas Periode</p>
    </section>

    <section class="student-data">
      <div>
        <div class="data-row"><span>NIM</span><b>:</b><strong>$nim</strong></div>
        <div class="data-row"><span>Nama</span><b>:</b><strong>$nama</strong></div>
        <div class="data-row"><span>Program Studi</span><b>:</b><strong>$prodi</strong></div>
      </div>
      <div>
        <div class="data-row"><span>Fakultas</span><b>:</b><strong>$fakultas</strong></div>
        <div class="data-row"><span>Angkatan</span><b>:</b><strong>$angkatan</strong></div>
        <div class="data-row"><span>Program</span><b>:</b><strong>$program</strong></div>
      </div>
    </section>

    $bufferPeriods

    <div class="summary-box">
      <div class="summary-item">
        <span>Total Mata Kuliah</span>
        <strong>$totalMk</strong>
      </div>
      <div class="summary-item">
        <span>Total SKS Ditempuh</span>
        <strong>$totalSks</strong>
      </div>
      <div class="summary-item">
        <span>Mata Kuliah Mengulang</span>
        <strong>$mengulang</strong>
      </div>
      <div class="summary-item">
        <span>IPK Kumulatif</span>
        <strong>$ipk</strong>
      </div>
    </div>

    <p class="notes">Catatan: Apabila terdapat mata kuliah yang diulang (termasuk pada periode sistem kombinasi/siskom), nilai yang diperhitungkan dan dicantumkan pada transkrip adalah nilai tertinggi. Tanda (*) menunjukkan mata kuliah hasil pengulangan.</p>

    <section class="signatures">
      <div>
        <span>Mahasiswa,</span>
        <div class="signature-space"></div>
        <strong class="signature-name">$mhsNama</strong>
        <span class="signature-id">NIM. $nim</span>
      </div>
      <div>
        <span>Mengetahui,</span>
        <div class="signature-space"></div>
        <strong class="signature-name">$pimpinanNama</strong>
        <span class="signature-id">Sistem Informasi Akademik</span>
      </div>
    </section>

    <footer class="print-meta">Dicetak melalui SIAKAD pada $tglCetak • Dokumen ini sah dikeluarkan melalui Sistem Informasi Akademik.</footer>
  </main>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      body: Column(
        children: [
          GradientHeader(
            title: 'Lembar Cetak Transkrip',
            subtitle: 'Transkrip Nilai Akademik Resmi Lintas Periode',
            leading: Navigator.of(context).canPop() ? const HeaderBackButton() : null,
            actions: [
              HeaderActionButton(
                icon: Icons.copy_rounded,
                tooltip: 'Salin Ringkasan Transkrip',
                onPressed: () async {
                  final data = await _future;
                  if (mounted && data.isNotEmpty) _salinRincian(data);
                },
              ),
              HeaderActionButton(
                icon: Icons.public_rounded,
                tooltip: 'Buka di Web SIAKAD',
                onPressed: () async {
                  final data = await _future;
                  final url = pickString(data, ['url'], '');
                  if (url.isNotEmpty && url.startsWith('http') && context.mounted) {
                    await openExternal(context, url);
                  }
                },
              ),
              HeaderActionButton(
                icon: Icons.refresh_rounded,
                tooltip: 'Muat Ulang',
                onPressed: () => setState(() => _future = _loadData()),
              ),
            ],
          ),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _future,
              builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: LoadingView(label: 'Memuat lembar cetak transkrip...'));
          }
          if (snapshot.hasError) {
            return ErrorRetry(
              message: 'Gagal memuat dokumen: ${snapshot.error}',
              onRetry: () => setState(() => _future = _loadData()),
            );
          }

          final data = snapshot.data ?? {};
          final toolbar = asMap(data['toolbar']);
          final labelCetak = pickString(toolbar, ['cetak'], 'Cetak / Simpan PDF');
          final labelTutup = pickString(toolbar, ['tutup'], 'Tutup');

          return Column(
            children: [
              // Toolbar resmi dari respon API & kontrol pratinjau instan
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.upiYellowDeep.withValues(alpha: 0.10),
                  border: Border(bottom: BorderSide(color: context.border)),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    // Tombol Tutup & Indikator
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).maybePop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: const Size(0, 34),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.arrow_back_rounded, size: 15),
                          label: Text(labelTutup, style: const TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                        // Mode Switcher: Dokumen UI vs PDF Preview
                        SegmentedButton<int>(
                          segments: const [
                            ButtonSegment(
                              value: 1,
                              icon: Icon(Icons.picture_as_pdf_rounded, size: 14),
                              label: Text('Pratinjau PDF', style: TextStyle(fontSize: 11.5)),
                            ),
                            ButtonSegment(
                              value: 0,
                              icon: Icon(Icons.article_outlined, size: 14),
                              label: Text('Lembar Kertas', style: TextStyle(fontSize: 11.5)),
                            ),
                          ],
                          selected: {_viewMode},
                          onSelectionChanged: (set) {
                            if (set.isNotEmpty) {
                              setState(() => _viewMode = set.first);
                            }
                          },
                          style: ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: WidgetStateProperty.all(
                              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Aksi Cetak PDF Instan
                    FilledButton.icon(
                      onPressed: _isPrinting ? null : () => _cetakPdf(data),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.upiYellowDeep,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        minimumSize: const Size(0, 36),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: _isPrinting
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.print_rounded, size: 16),
                      label: Text(
                        _isPrinting ? 'Menyiapkan...' : labelCetak,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

              // Konten Sesuai Mode: PDF Preview Instan vs Lembar Kertas
              Expanded(
                child: _viewMode == 1
                    ? PdfPreview(
                        build: (format) => TranskripPdfHelper.buildPdf(format, data),
                        allowPrinting: true,
                        allowSharing: true,
                        canChangeOrientation: false,
                        canChangePageFormat: false,
                        canDebug: false,
                        initialPageFormat: PdfPageFormat.a4,
                        pdfFileName:
                            'Transkrip_Nilai_${pickString(asMap(data['mahasiswa']), ['nim', 'nobp'], 'UPI')}.pdf',
                        previewPageMargin:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        loadingWidget: const Center(
                          child: LoadingView(label: 'Merender pratinjau PDF instan...'),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 16),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 850),
                            child: _TranskripPaperSheet(data: data),
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    ),
  ],
),
);
  }
}

class _TranskripPaperSheet extends StatelessWidget {
  const _TranskripPaperSheet({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final mhs = asMap(data['mahasiswa']);
    final nama = pickString(mhs, ['nama'], '-');
    final nim = pickString(mhs, ['nim', 'nobp'], '-');
    final prodi = pickString(mhs, ['program_studi', 'prodi'], '-');
    final fakultas = pickString(mhs, ['fakultas'], 'Ilmu Komputer');
    final angkatan = pickString(mhs, ['angkatan'], '-');
    final program = pickString(mhs, ['program'], 'Reguler');

    final summary = asMap(data['summary']);
    final ipk = pickString(summary, ['ipk'], '-');
    final totalSks = pickString(summary, ['total_sks'], '-');
    final totalMk = pickString(summary, ['total_mata_kuliah'], '-');
    final mengulang = pickString(summary, ['mengulang'], '0');

    final periods = data['periode'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: const Color(0xFFCFD6DF)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Kop Surat & Logo
          Center(
            child: Image.network(
              'https://sisfo.upiyptk.ac.id/assets/img/print-header-kartu-mahasiswa.png',
              height: 60,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Column(
                children: [
                  Text(
                    'UNIVERSITAS PUTRA INDONESIA YPTK PADANG',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF263B62),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Jl. Raya Lubuk Begalung, Padang, Sumatera Barat',
                    style: TextStyle(fontSize: 10, color: Color(0xFF667085)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(thickness: 2, color: Colors.black),
          const SizedBox(height: 12),

          // Judul Dokumen
          Center(
            child: Column(
              children: [
                const Text(
                  'TRANSKRIP NILAI AKADEMIK',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    color: Color(0xFF263B62),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  pickString(data, ['subjudul'], 'Daftar Hasil Studi Mahasiswa Lintas Periode'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF667085),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Identitas Mahasiswa Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFBFC),
              border: Border.all(color: const Color(0xFFCFD6DF)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          _buildMetaRow('NIM', nim),
                          const SizedBox(height: 4),
                          _buildMetaRow('Nama', nama),
                          const SizedBox(height: 4),
                          _buildMetaRow('Program Studi', prodi),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        children: [
                          _buildMetaRow('Fakultas', fakultas),
                          const SizedBox(height: 4),
                          _buildMetaRow('Angkatan', angkatan),
                          const SizedBox(height: 4),
                          _buildMetaRow('Program', program),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Daftar Periode & Nilai
          if (periods is List && periods.isNotEmpty) ...[
            for (final p in periods)
              if (p is Map) ...[
                _buildPeriodSection(asMap(p)),
                const SizedBox(height: 16),
              ],
          ] else ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: Text('Belum ada riwayat nilai yang tercatat.'),
              ),
            ),
          ],

          // Box Ringkasan Kumulatif
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFCFD6DF)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryBoxItem('Total MK', totalMk),
                Container(width: 1, height: 32, color: const Color(0xFFCFD6DF)),
                _buildSummaryBoxItem('Total SKS', totalSks),
                Container(width: 1, height: 32, color: const Color(0xFFCFD6DF)),
                _buildSummaryBoxItem('Mengulang', mengulang),
                Container(width: 1, height: 32, color: const Color(0xFFCFD6DF)),
                _buildSummaryBoxItem('IPK Kumulatif', ipk, isHighlight: true),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Catatan resmi
          Text(
            pickString(
              data,
              ['catatan'],
              'Catatan: Apabila terdapat mata kuliah yang diulang, nilai yang diperhitungkan dan dicantumkan pada transkrip adalah nilai tertinggi. Tanda (*) menunjukkan mata kuliah hasil pengulangan.',
            ),
            style: const TextStyle(
              fontSize: 9.5,
              color: Color(0xFF667085),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 36),

          // Tanda Tangan
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSignCol('Mahasiswa,', nama, 'NIM. $nim'),
              _buildSignCol('Mengetahui,', 'Ketua Program Studi / Pimpinan', 'Sistem Informasi Akademik'),
            ],
          ),
          const SizedBox(height: 24),

          // Footer Cetak Meta
          const Center(
            child: Text(
              'Dokumen ini sah dikeluarkan melalui Sistem Informasi Akademik Universitas Putra Indonesia YPTK Padang.',
              style: TextStyle(fontSize: 8.5, color: Color(0xFF98A2B3)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSection(Map<String, dynamic> pm) {
    final pNama = pickString(pm, ['periode'], 'Periode');
    final ips = pickString(pm, ['ips'], '-');
    final subtotal = asMap(pm['subtotal']);
    final subSks = pickString(subtotal, ['sks'], pickString(pm, ['total_sks'], '-'));
    final subMutu = pickString(subtotal, ['mutu'], '-');
    final mks = pm['mata_kuliah'];

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFCFD6DF)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Periode
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: const BoxDecoration(
              color: Color(0xFFEEF3F9),
              borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  pNama,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF263B62),
                  ),
                ),
                Text(
                  'IPS: $ips',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF263B62),
                  ),
                ),
              ],
            ),
          ),

          // Table Header
          Container(
            color: const Color(0xFF263B62),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: const Row(
              children: [
                SizedBox(width: 24, child: Text('No', style: _thStyle, textAlign: TextAlign.center)),
                SizedBox(width: 80, child: Text('Kode MK', style: _thStyle, textAlign: TextAlign.center)),
                Expanded(child: Text('Mata Kuliah', style: _thStyle)),
                SizedBox(width: 36, child: Text('SKS', style: _thStyle, textAlign: TextAlign.center)),
                SizedBox(width: 44, child: Text('Grade', style: _thStyle, textAlign: TextAlign.center)),
                SizedBox(width: 44, child: Text('Bobot', style: _thStyle, textAlign: TextAlign.center)),
                SizedBox(width: 46, child: Text('Mutu', style: _thStyle, textAlign: TextAlign.center)),
              ],
            ),
          ),

          // Table Rows
          if (mks is List)
            for (int i = 0; i < mks.length; i++)
              if (mks[i] is Map)
                _buildCourseRow(asMap(mks[i]), isEven: i % 2 == 0),

          // Subtotal Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(top: BorderSide(color: Color(0xFFCFD6DF))),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(5)),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'SUBTOTAL',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF263B62),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 36,
                  child: Text(
                    subSks,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF263B62),
                    ),
                  ),
                ),
                const SizedBox(width: 88),
                SizedBox(
                  width: 46,
                  child: Text(
                    subMutu,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF263B62),
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

  Widget _buildCourseRow(Map<String, dynamic> mm, {required bool isEven}) {
    final no = pickString(mm, ['no'], '-');
    final kode = pickString(mm, ['kode'], '-');
    final nama = pickString(mm, ['nama'], '-');
    final namaEn = pickString(mm, ['nama_en'], '');
    final sks = pickString(mm, ['sks'], '0');
    final grade = pickString(mm, ['grade'], '-');
    final bobot = pickString(mm, ['bobot'], '-');
    final mutu = pickString(mm, ['mutu'], '-');

    return Container(
      color: isEven ? Colors.white : const Color(0xFFFAFBFC),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: 24, child: Text(no, style: _tdStyle, textAlign: TextAlign.center)),
          SizedBox(
            width: 80,
            child: Text(
              kode,
              style: _tdStyle.copyWith(fontWeight: FontWeight.w700, fontFamily: 'monospace'),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nama, style: _tdStyle.copyWith(fontWeight: FontWeight.w600, color: const Color(0xFF1A2233))),
                if (namaEn.isNotEmpty && namaEn != nama)
                  Text(namaEn, style: const TextStyle(fontSize: 9.5, fontStyle: FontStyle.italic, color: Color(0xFF667085))),
              ],
            ),
          ),
          SizedBox(width: 36, child: Text(sks, style: _tdStyle, textAlign: TextAlign.center)),
          SizedBox(
            width: 44,
            child: Text(
              grade,
              style: _tdStyle.copyWith(fontWeight: FontWeight.w800, color: const Color(0xFF263B62)),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(width: 44, child: Text(bobot, style: _tdStyle, textAlign: TextAlign.center)),
          SizedBox(width: 46, child: Text(mutu, style: _tdStyle, textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  Widget _buildSummaryBoxItem(String title, String val, {bool isHighlight = false}) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 9.5, color: Color(0xFF667085), fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          val,
          style: TextStyle(
            fontSize: isHighlight ? 15 : 13,
            fontWeight: FontWeight.w900,
            color: isHighlight ? AppColors.upiYellowDeep : const Color(0xFF263B62),
          ),
        ),
      ],
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 86,
          child: Text(
            label,
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF667085)),
          ),
        ),
        const Text(': ', style: TextStyle(fontSize: 10.5, color: Color(0xFF667085))),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF1D2430)),
          ),
        ),
      ],
    );
  }

  Widget _buildSignCol(String label, String name, String sub) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF1D2430))),
        const SizedBox(height: 52),
        Text(
          name,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1D2430),
            decoration: TextDecoration.underline,
          ),
        ),
        const SizedBox(height: 2),
        Text(sub, style: const TextStyle(fontSize: 9.5, color: Color(0xFF667085))),
      ],
    );
  }

  static const TextStyle _thStyle = TextStyle(
    color: Colors.white,
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.3,
  );

  static const TextStyle _tdStyle = TextStyle(
    fontSize: 10.5,
    color: Color(0xFF1D2430),
  );
}
