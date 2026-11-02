import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../services/akademik_service.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../utils/smart.dart';
import '../widgets/common.dart';
import '../widgets/gradient_header.dart';

/// Halaman tampilan resmi lembar cetak Kartu Hasil Studi (KHS)
/// yang menampilkan dokumen cetak resmi secara langsung di dalam aplikasi
/// dan menyediakan tombol Cetak PDF resmi (melalui printer / simpan PDF native).
class KhsCetakScreen extends StatefulWidget {
  const KhsCetakScreen({super.key, required this.periode});

  final String periode;

  @override
  State<KhsCetakScreen> createState() => _KhsCetakScreenState();
}

class _KhsCetakScreenState extends State<KhsCetakScreen> {
  late Future<Map<String, dynamic>> _future;
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  Future<Map<String, dynamic>> _loadData() async {
    final api = context.read<ApiClient>();
    final srv = AkademikService(api);

    // 1. Panggil endpoint resmi GET /api/akademik/khs/cetak (paling lengkap)
    try {
      final cetakResp = await srv.khsCetak(widget.periode);
      final map = asMap(cetakResp);
      final data = asMap(map['data'] ?? map);
      final rawHtml = pickString(data, ['html', 'raw_html'], '');
      final mks = data['mata_kuliah'] ?? data['nilai'];
      if (rawHtml.isNotEmpty || (mks is List && mks.isNotEmpty)) {
        return data;
      }
    } catch (_) {}

    // 2. Fallback: panggil /api/akademik/khs/data (endpoint AJAX dengan rows & student)
    try {
      final dataResp = await srv.khsData(widget.periode);
      final dMap = asMap(dataResp);
      final dData = asMap(dMap['data'] ?? dMap);
      final inner = asMap(dData['data'] ?? dData);
      final rows = inner['rows'];
      if (rows is List && rows.isNotEmpty) {
        final student = asMap(inner['student']);
        final summary = asMap(inner['summary']);
        final periodInfo = asMap(inner['period']);

        final normalizedMk = <Map<String, dynamic>>[];
        for (int i = 0; i < rows.length; i++) {
          final r = asMap(rows[i]);
          normalizedMk.add({
            'no': (i + 1).toString(),
            'kode': pickString(r, ['kode_mk'], ''),
            'nama': pickString(r, ['nama_mk'], ''),
            'nama_en': pickString(r, ['nama_english'], ''),
            'sks': pickString(r, ['sks'], '0'),
            'nilai_angka': pickString(r, ['nilai_akhir'], '-'),
            'grade': pickString(r, ['grade'], '-'),
            'bobot': pickString(r, ['bobot'], '-'),
            'mutu': pickString(r, ['mutu'], '-'),
            'status': (r['lulus'] == true) ? 'Lulus' : 'Tidak Lulus',
          });
        }

        return {
          'judul': 'KARTU HASIL STUDI (KHS)',
          'periode':
              pickString(periodInfo, ['label', 'periode'], widget.periode),
          'mahasiswa': {
            'nama': pickString(student, ['nama'], ''),
            'nim': pickString(student, ['nim'], ''),
            'program_studi': pickString(student, ['program_studi'], ''),
            'fakultas': pickString(student, ['fakultas'], ''),
            'program_kelas':
                '${pickString(student, ['program'], '')} / ${pickString(student, ['kelas'], '')}'
                    .trim(),
            'dosen_pa': pickString(student, ['dosen_pa'], ''),
            'angkatan': pickString(student, ['angkatan'], ''),
          },
          'mata_kuliah': normalizedMk,
          'summary': {
            'ips': pickString(summary, ['ips'], '0,00'),
            'total_sks':
                pickString(summary, ['total_sks', 'passed_sks'], '0'),
            'total_mutu': pickString(summary, ['total_mutu'], '0'),
          },
          'signatures': [
            if (pickString(student, ['dosen_pa'], '').isNotEmpty)
              {
                'label': 'Dosen Pembimbing Akademik,',
                'nama': pickString(student, ['dosen_pa'], ''),
                'keterangan': 'Dosen Pembimbing Akademik',
              },
            {
              'label': 'Mahasiswa,',
              'nama': pickString(student, ['nama'], ''),
              'keterangan': 'NIM. ${pickString(student, ['nim'], '')}',
            },
          ],
        };
      }
    } catch (_) {}

    // 3. Fallback terakhir: /api/akademik/khs
    try {
      final khsResp = await srv.khs(widget.periode);
      final kMap = asMap(khsResp);
      return asMap(kMap['data'] ?? kMap);
    } catch (_) {
      return {};
    }
  }

  String _cleanHtmlText(String raw) {
    return raw
        .replaceAll(RegExp(r'<br\s*\/?>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<_KhsRow> _extractRows(Map<String, dynamic> data) {
    final rows = <_KhsRow>[];
    final list = data['mata_kuliah'] ?? data['nilai'];

    if (list is List && list.isNotEmpty) {
      int idx = 1;
      for (final item in list) {
        if (item is Map) {
          final m = asMap(item);
          final no = pickString(m, ['no'], '${idx++}');
          final kode = pickString(m, ['kode', 'kode_mk', 'kd_mk'], '-');
          final nama = pickString(
              m, ['nama', 'nama_mk', 'matkul', 'mata_kuliah'], 'Mata Kuliah');
          final sks = pickString(m, ['sks'], '0');
          final grade = pickString(m, ['grade', 'nilai', 'nilai_huruf'], '-');
          final bobot = pickString(m, ['bobot', 'angka', 'nilai_angka'], '-');
          final mutu = pickString(m, ['mutu', 'total_mutu'], '-');

          rows.add(_KhsRow(
            no: no,
            kode: kode,
            nama: nama,
            sks: sks,
            grade: grade,
            bobot: bobot,
            mutu: mutu,
          ));
        }
      }
    }

    // Fallback parsing jika html mentah tersedia
    if (rows.isEmpty) {
      final html = pickString(data, ['html', 'raw_html'], '');
      if (html.isNotEmpty) {
        final tbodyMatch =
            RegExp(r'<tbody>(.*?)<\/tbody>', dotAll: true).firstMatch(html);
        final content = tbodyMatch != null ? tbodyMatch.group(1)! : html;
        final trMatches =
            RegExp(r'<tr[^>]*>(.*?)<\/tr>', dotAll: true).allMatches(content);

        for (final tr in trMatches) {
          final trHtml = tr.group(1)!;
          final tdMatches = RegExp(r'<td[^>]*>(.*?)<\/td>', dotAll: true)
              .allMatches(trHtml)
              .toList();
          if (tdMatches.length >= 6) {
            final no = _cleanHtmlText(tdMatches[0].group(1)!);
            final kode = _cleanHtmlText(tdMatches[1].group(1)!);
            final nama = _cleanHtmlText(tdMatches[2].group(1)!);
            final sks = _cleanHtmlText(tdMatches[3].group(1)!);
            final grade = _cleanHtmlText(tdMatches[4].group(1)!);
            final mutu = _cleanHtmlText(tdMatches[5].group(1)!);

            if (no.isNotEmpty && no != '-' && int.tryParse(no) != null) {
              rows.add(_KhsRow(
                no: no,
                kode: kode,
                nama: nama,
                sks: sks,
                grade: grade,
                bobot: '-',
                mutu: mutu,
              ));
            }
          }
        }
      }
    }

    return rows;
  }

  Future<void> _cetakPdf(String htmlContent) async {
    if (_isPrinting) return;
    setState(() => _isPrinting = true);
    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async {
          // Buat halaman PDF dari HTML
          // ignore: deprecated_member_use
          return await Printing.convertHtml(
            format: format,
            html: htmlContent,
          );
        },
        name: 'KHS_${widget.periode}.pdf',
      );
    } catch (e) {
      if (mounted) {
        appToast(context, 'Gagal membuka layanan cetak: $e', error: true);
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  void _salinRincian(Map<String, dynamic> data) {
    final mhs = asMap(data['mahasiswa']);
    final nama = pickString(mhs, ['nama'], '-');
    final nim = pickString(mhs, ['nim', 'nobp'], '-');
    final prodi = pickString(mhs, ['prodi'], '-');
    final periode = pickString(data, ['periode', 'periode_terpilih'], widget.periode);
    final summary = asMap(data['summary']);
    final ips = pickString(summary, ['ips', 'ip'], '-');
    final ipk = pickString(summary, ['ipk'], '-');
    final totalSks = pickString(summary, ['total_sks', 'sks'], '-');
    final rows = _extractRows(data);

    final buffer = StringBuffer();
    buffer.writeln('KARTU HASIL STUDI (KHS)');
    buffer.writeln('UNIVERSITAS PUTRA INDONESIA YPTK PADANG');
    buffer.writeln('Periode: $periode');
    buffer.writeln('----------------------------------------');
    buffer.writeln('Nama Mahasiswa : $nama');
    buffer.writeln('NIM / No. BP   : $nim');
    buffer.writeln('Program Studi  : $prodi');
    buffer.writeln('IPS / IPK      : $ips / $ipk');
    buffer.writeln('Total SKS      : $totalSks SKS');
    buffer.writeln('----------------------------------------');
    buffer.writeln('Daftar Nilai:');
    for (final r in rows) {
      buffer.writeln('${r.no}. [${r.kode}] ${r.nama} (${r.sks} SKS) - Nilai: ${r.grade} (Mutu: ${r.mutu})');
    }
    buffer.writeln('----------------------------------------');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    appToast(context, 'Rincian lembar KHS berhasil disalin ke clipboard.');
  }

  String _formatCurrentDate() {
    final now = DateTime.now();
    final months = [
      '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return '${now.day} ${months[now.month]} ${now.year}';
  }

  String _buildPrintableHtml(Map<String, dynamic> data, List<_KhsRow> rows) {
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
    final semester = pickString(mhs, ['semester'], '-');
    final kelas = pickString(mhs, ['kelas'], '-');
    final periode = pickString(data, ['periode', 'periode_terpilih'], widget.periode);

    final summary = asMap(data['summary']);
    final total = asMap(data['total']);
    final totalSks = pickString(total, ['sks'], pickString(summary, ['total_sks'], '-'));
    final totalMutu = pickString(total, ['mutu'], pickString(summary, ['total_mutu'], '-'));
    final ips = pickString(summary, ['ips', 'ip'], '-');
    final ipk = pickString(summary, ['ipk'], '-');
    final maksSks = pickString(summary, ['maks_sks'], '24');

    final tglCetak = _formatCurrentDate();

    // Ekstrak Tanda Tangan
    String dosenPa = 'Dosen Pembimbing Akademik';
    String mhsNama = nama;
    if (data['signatures'] is List) {
      for (final s in (data['signatures'] as List)) {
        if (s is Map) {
          final sm = asMap(s);
          final jab = pickString(sm, ['jabatan'], '').toLowerCase();
          final nm = pickString(sm, ['nama'], '');
          if (jab.contains('dosen') || jab.contains('pembimbing') || jab.contains('pa')) {
            if (nm.isNotEmpty) dosenPa = nm;
          } else if (jab.contains('mahasiswa')) {
            if (nm.isNotEmpty) mhsNama = nm;
          }
        }
      }
    }

    final tableRows = rows.map((r) => '''
      <tr>
        <td style="text-align: center;">${r.no}</td>
        <td style="text-align: center; font-family: monospace; font-weight: bold;">${r.kode}</td>
        <td>${r.nama}</td>
        <td style="text-align: center;">${r.sks}</td>
        <td style="text-align: center; font-weight: bold;">${r.grade}</td>
        <td style="text-align: center;">${r.bobot != '-' ? r.bobot : ''}</td>
        <td style="text-align: center;">${r.mutu}</td>
      </tr>
    ''').join('');

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>KHS - $nama ($nim)</title>
  <style>
    @page { size: A4 portrait; margin: 15mm; }
    body {
      font-family: 'Times New Roman', Times, serif;
      font-size: 11pt;
      line-height: 1.35;
      color: #000;
      margin: 0;
      padding: 10px;
    }
    .header-table { width: 100%; border-collapse: collapse; margin-bottom: 12px; }
    .header-table td { vertical-align: middle; }
    .univ-title { font-size: 14pt; font-weight: bold; text-align: center; text-transform: uppercase; margin: 0; }
    .sub-title { font-size: 10pt; text-align: center; margin: 2px 0; }
    .doc-title {
      font-size: 13pt;
      font-weight: bold;
      text-align: center;
      text-decoration: underline;
      margin-top: 10px;
      margin-bottom: 4px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .periode-title { font-size: 11pt; text-align: center; font-weight: bold; margin-bottom: 15px; }
    .info-table { width: 100%; border-collapse: collapse; margin-bottom: 14px; font-size: 10pt; }
    .info-table td { padding: 3px 4px; vertical-align: top; }
    .data-table { width: 100%; border-collapse: collapse; margin-bottom: 14px; font-size: 9.5pt; }
    .data-table th, .data-table td { border: 1px solid #000; padding: 5px 6px; }
    .data-table th { background-color: #f2f2f2; text-align: center; font-weight: bold; }
    .summary-box {
      width: 100%;
      border: 1px solid #000;
      margin-bottom: 20px;
      padding: 6px 10px;
      font-size: 10pt;
      background: #fafafa;
    }
    .sig-table { width: 100%; border-collapse: collapse; margin-top: 25px; font-size: 10.5pt; }
    .sig-table td { text-align: center; vertical-align: top; width: 50%; padding: 0 15px; }
    .sig-space { height: 60px; }
    .sig-name { font-weight: bold; text-decoration: underline; }
  </style>
</head>
<body>
  <table class="header-table">
    <tr>
      <td width="70" style="text-align: center;">
        <img src="https://sisfo.upiyptk.ac.id/assets/img/print-header-kartu-mahasiswa.png" width="65" alt="Logo" style="display: block; margin: auto;">
      </td>
      <td>
        <div class="univ-title">UNIVERSITAS PUTRA INDONESIA "YPTK" PADANG</div>
        <div class="sub-title">Fakultas $fakultas • Program Studi $prodi</div>
        <div class="sub-title" style="font-size: 8.5pt; color: #444;">Jl. Raya Lubuk Begalung, Padang, Sumatera Barat • Telp. (0751) 776666</div>
      </td>
    </tr>
  </table>
  <hr style="border: 0; border-top: 2px solid #000; margin-bottom: 1px;">
  <hr style="border: 0; border-top: 1px solid #000; margin-bottom: 10px;">

  <div class="doc-title">KARTU HASIL STUDI (KHS)</div>
  <div class="periode-title">$periode</div>

  <table class="info-table">
    <tr>
      <td width="15%"><strong>NIM / No. BP</strong></td>
      <td width="2%">:</td>
      <td width="38%">$nim</td>
      <td width="15%"><strong>Fakultas</strong></td>
      <td width="2%">:</td>
      <td width="28%">$fakultas</td>
    </tr>
    <tr>
      <td><strong>Nama Lengkap</strong></td>
      <td>:</td>
      <td><strong>$nama</strong></td>
      <td><strong>Program Studi</strong></td>
      <td>:</td>
      <td>$prodi</td>
    </tr>
    <tr>
      <td><strong>Semester</strong></td>
      <td>:</td>
      <td>$semester</td>
      <td><strong>Kelas</strong></td>
      <td>:</td>
      <td>$kelas</td>
    </tr>
  </table>

  <table class="data-table">
    <thead>
      <tr>
        <th width="5%">NO</th>
        <th width="15%">KODE MK</th>
        <th>NAMA MATA KULIAH</th>
        <th width="8%">SKS</th>
        <th width="10%">NILAI</th>
        <th width="10%">BOBOT</th>
        <th width="10%">MUTU</th>
      </tr>
    </thead>
    <tbody>
      $tableRows
      <tr style="font-weight: bold; background: #f9f9f9;">
        <td colspan="3" style="text-align: right; padding-right: 12px;">JUMLAH / TOTAL</td>
        <td style="text-align: center;">$totalSks</td>
        <td colspan="2"></td>
        <td style="text-align: center;">$totalMutu</td>
      </tr>
    </tbody>
  </table>

  <div class="summary-box">
    <table width="100%" style="border-collapse: collapse;">
      <tr>
        <td width="30%"><strong>Indeks Prestasi Semester (IPS)</strong></td>
        <td width="2%">:</td>
        <td width="18%"><strong>$ips</strong></td>
        <td width="30%"><strong>Total SKS Dicapai</strong></td>
        <td width="2%">:</td>
        <td width="18%"><strong>$totalSks SKS</strong></td>
      </tr>
      <tr>
        <td><strong>Indeks Prestasi Kumulatif (IPK)</strong></td>
        <td>:</td>
        <td><strong>$ipk</strong></td>
        <td><strong>Maksimal Beban SKS Semester Depan</strong></td>
        <td>:</td>
        <td><strong>$maksSks SKS</strong></td>
      </tr>
    </table>
  </div>

  <table class="sig-table">
    <tr>
      <td></td>
      <td>Padang, $tglCetak</td>
    </tr>
    <tr>
      <td>
        Mengetahui,<br>
        Dosen Pembimbing Akademik
        <div class="sig-space"></div>
        <span class="sig-name">$dosenPa</span>
      </td>
      <td>
        Mahasiswa Yang Bersangkutan
        <div class="sig-space"></div>
        <span class="sig-name">$mhsNama</span><br>
        <span>NIM: $nim</span>
      </td>
    </tr>
  </table>
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
            title: 'Lembar Cetak KHS',
            subtitle: 'Periode ${widget.periode} • Dokumen Resmi Akademik',
            leading: Navigator.of(context).canPop() ? const HeaderBackButton() : null,
            actions: [
              HeaderActionButton(
                icon: Icons.copy_rounded,
                tooltip: 'Salin Ringkasan KHS',
                onPressed: () async {
                  final data = await _future;
                  if (mounted) _salinRincian(data);
                },
              ),
              HeaderActionButton(
                icon: Icons.public_rounded,
                tooltip: 'Buka di Browser',
                onPressed: () async {
                  final data = await _future;
                  final url = pickString(data, ['url', 'print_url'], '');
                  if (url.isNotEmpty && context.mounted) {
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
                  return const Center(child: LoadingView(label: 'Memuat lembar cetak KHS...'));
                }
                if (snapshot.hasError) {
                  return ErrorRetry(
                    message: 'Gagal memuat dokumen: ${snapshot.error}',
                    onRetry: () => setState(() => _future = _loadData()),
                  );
                }

                final data = snapshot.data ?? {};
                final rows = _extractRows(data);
                final htmlContent = _buildPrintableHtml(data, rows);

                return Column(
                  children: [
                    // Banner Tombol Aksi Cetak Utama
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: context.card,
                        border: Border(bottom: BorderSide(color: context.border, width: 0.5)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Pratinjau Resmi KHS Universitas',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: context.textMuted,
                              ),
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: _isPrinting ? null : () => _cetakPdf(htmlContent),
                            icon: _isPrinting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1C1917)),
                                    ),
                                  )
                                : const Icon(Icons.print_rounded, size: 18),
                            label: Text(
                              _isPrinting ? 'Mencetak...' : 'Cetak / Simpan PDF',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primaryYellow,
                              foregroundColor: const Color(0xFF1C1917),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    ),

              // Lembar Kertas Preview
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: _buildPaperSheet(context, data, rows),
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

  Widget _buildPaperSheet(
    BuildContext context,
    Map<String, dynamic> data,
    List<_KhsRow> rows,
  ) {
    final mhs = asMap(data['mahasiswa']);
    final nama = pickString(mhs, ['nama'], '-');
    final nim = pickString(mhs, ['nim', 'nobp'], '-');
    final prodi = pickString(mhs, ['prodi'], '-');
    final fakultas = pickString(mhs, ['fakultas'], 'Ilmu Komputer');
    final semester = pickString(mhs, ['semester'], '-');
    final kelas = pickString(mhs, ['kelas'], '-');
    final periode = pickString(data, ['periode', 'periode_terpilih'], widget.periode);

    final summary = asMap(data['summary']);
    final total = asMap(data['total']);
    final totalSks = pickString(total, ['sks'], pickString(summary, ['total_sks'], '-'));
    final totalMutu = pickString(total, ['mutu'], pickString(summary, ['total_mutu'], '-'));
    final ips = pickString(summary, ['ips', 'ip'], '-');
    final ipk = pickString(summary, ['ipk'], '-');
    final maksSks = pickString(summary, ['maks_sks'], '24');

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD1D5DB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x15000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Kop Surat Universitas
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.network(
                'https://sisfo.upiyptk.ac.id/assets/img/print-header-kartu-mahasiswa.png',
                width: 60,
                height: 60,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.account_balance_rounded,
                  size: 50,
                  color: AppColors.upiYellowDeep,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'UNIVERSITAS PUTRA INDONESIA "YPTK" PADANG',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        fontFamily: 'Serif',
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Jl. Raya Lubuk Begalung, Padang, Sumatera Barat • Telp. (0751) 776666',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: Color(0xFF4B5563)),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(thickness: 2, color: Colors.black),
          const SizedBox(height: 12),

          // Judul Dokumen
          const Center(
            child: Text(
              'KARTU HASIL STUDI (KHS)',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Colors.black,
                decoration: TextDecoration.underline,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Center(
            child: Text(
              periode,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Tabel Identitas Mahasiswa
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(8),
              color: const Color(0xFFF9FAFB),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _paperRow('NIM / No. BP', nim),
                      const SizedBox(height: 4),
                      _paperRow('Nama Mahasiswa', nama, bold: true),
                      const SizedBox(height: 4),
                      _paperRow('Semester', semester),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      _paperRow('Fakultas', fakultas),
                      const SizedBox(height: 4),
                      _paperRow('Program Studi', prodi),
                      const SizedBox(height: 4),
                      _paperRow('Kelas', kelas),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Tabel Mata Kuliah & Nilai
          Table(
            border: TableBorder.all(color: const Color(0xFF9CA3AF)),
            columnWidths: const {
              0: FixedColumnWidth(34),
              1: FixedColumnWidth(85),
              2: FlexColumnWidth(4),
              3: FixedColumnWidth(44),
              4: FixedColumnWidth(52),
              5: FixedColumnWidth(52),
              6: FixedColumnWidth(52),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              // Header Table
              TableRow(
                decoration: const BoxDecoration(color: Color(0xFFF3F4F6)),
                children: [
                  _th('NO'),
                  _th('KODE'),
                  _th('MATA KULIAH', align: TextAlign.left),
                  _th('SKS'),
                  _th('NILAI'),
                  _th('BOBOT'),
                  _th('MUTU'),
                ],
              ),
              // Data Rows
              for (final r in rows)
                TableRow(
                  children: [
                    _td(r.no, align: TextAlign.center),
                    _td(r.kode, align: TextAlign.center, bold: true),
                    _td(r.nama, align: TextAlign.left),
                    _td(r.sks, align: TextAlign.center),
                    _td(r.grade, align: TextAlign.center, bold: true, color: _gradeColorText(r.grade)),
                    _td(r.bobot != '-' ? r.bobot : '', align: TextAlign.center),
                    _td(r.mutu, align: TextAlign.center),
                  ],
                ),
              // Total Row
              TableRow(
                decoration: const BoxDecoration(color: Color(0xFFF9FAFB)),
                children: [
                  const SizedBox.shrink(),
                  const SizedBox.shrink(),
                  _td('TOTAL / JUMLAH', bold: true, align: TextAlign.right),
                  _td(totalSks, align: TextAlign.center, bold: true),
                  const SizedBox.shrink(),
                  const SizedBox.shrink(),
                  _td(totalMutu, align: TextAlign.center, bold: true),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Summary Indeks Prestasi Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _summaryLine('Indeks Prestasi Semester (IPS)', ips, highlight: true),
                      const SizedBox(height: 4),
                      _summaryLine('Indeks Prestasi Kumulatif (IPK)', ipk),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _summaryLine('Total SKS Dicapai', '$totalSks SKS'),
                      const SizedBox(height: 4),
                      _summaryLine('Maks SKS Semester Depan', '$maksSks SKS'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Area Tanda Tangan
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  children: [
                    const Text('Mengetahui,', style: TextStyle(fontSize: 11, color: Colors.black)),
                    const Text('Dosen Pembimbing Akademik',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
                    const SizedBox(height: 55),
                    Container(
                      height: 1,
                      width: 160,
                      color: Colors.black,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text('Padang, ${_formatCurrentDate()}',
                        style: const TextStyle(fontSize: 11, color: Colors.black)),
                    const Text('Mahasiswa Yang Bersangkutan',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
                    const SizedBox(height: 55),
                    Text(
                      nama,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    Text('NIM: $nim', style: const TextStyle(fontSize: 10, color: Color(0xFF4B5563))),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          Center(
            child: Text(
              'Dokumen ini dicetak langsung secara elektronik melalui SIAKAD UPI YPTK Mobile.',
              style: TextStyle(
                fontSize: 9,
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryLine(String label, String val, {bool highlight = false}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF374151)),
          ),
        ),
        Text(
          val,
          style: TextStyle(
            fontSize: highlight ? 13 : 12,
            fontWeight: FontWeight.w800,
            color: highlight ? const Color(0xFF15803D) : const Color(0xFF111827),
          ),
        ),
      ],
    );
  }

  Color _gradeColorText(String grade) {
    final g = grade.toUpperCase();
    if (g.startsWith('A')) return const Color(0xFF16A34A);
    if (g.startsWith('B')) return const Color(0xFF2563EB);
    if (g.startsWith('C')) return const Color(0xFFD97706);
    return const Color(0xFFDC2626);
  }

  Widget _paperRow(String label, String value, {bool bold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 95,
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
          ),
        ),
        const Text(': ', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: Colors.black,
            ),
          ),
        ),
      ],
    );
  }

  Widget _th(String label, {TextAlign align = TextAlign.center}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Text(
        label,
        textAlign: align,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _td(String label,
      {TextAlign align = TextAlign.left, bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
      child: Text(
        label,
        textAlign: align,
        style: TextStyle(
          fontSize: 10,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: color ?? Colors.black,
        ),
      ),
    );
  }
}

class _KhsRow {
  final String no;
  final String kode;
  final String nama;
  final String sks;
  final String grade;
  final String bobot;
  final String mutu;

  const _KhsRow({
    required this.no,
    required this.kode,
    required this.nama,
    required this.sks,
    required this.grade,
    required this.bobot,
    required this.mutu,
  });
}

