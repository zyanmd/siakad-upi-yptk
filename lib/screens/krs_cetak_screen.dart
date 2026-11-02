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

/// Halaman tampilan resmi lembar Kartu Rencana Studi (KRS)
/// yang menampilkan dokumen cetak resmi secara langsung di dalam aplikasi
/// dan menyediakan tombol Cetak PDF resmi (melalui printer / simpan PDF native).
class KrsCetakScreen extends StatefulWidget {
  const KrsCetakScreen({super.key, required this.periode});

  final String periode;

  @override
  State<KrsCetakScreen> createState() => _KrsCetakScreenState();
}

class _KrsCetakScreenState extends State<KrsCetakScreen> {
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

    // 1. Coba endpoint khusus cetak dari backend
    try {
      final cetakResp = await srv.krsCetak(widget.periode);
      final map = asMap(cetakResp);
      final data = asMap(map['data'] ?? map);
      final rawHtml = pickString(data, ['html', 'raw_html'], '');
      final mk = asList(data['mata_kuliah']);
      if (rawHtml.isNotEmpty || mk.isNotEmpty) {
        if (rawHtml.isEmpty) {
          data['html'] = _generateHtmlFallback(data);
          data['raw_html'] = data['html'];
        }
        return data;
      }
    } catch (_) {
      // Fallback lanjut ke bawah
    }

    // 2. Fallback: ambil KRS + profil akademik secara paralel
    final results = await Future.wait<dynamic>([
      srv.krs(widget.periode),
      srv.profil(),
    ]);

    final krsMap = asMap(results[0]);
    final krsData = asMap(krsMap['data'] ?? krsMap);

    final profMap = asMap(results[1]);
    final profData = asMap(profMap['data'] ?? profMap);

    final identitas = asMap(profData['identitas'] ?? profData['biodata'] ?? profData);
    final akademik = asMap(profData['akademik'] ?? profData);
    final pa = asMap(profData['pa'] ?? profData);

    final nama = pickString(identitas, ['nama', 'nama_lengkap', 'nm_mhs'], 'Mahasiswa');
    final nim = pickString(identitas, ['nim', 'nobp', 'no_bp', 'bp'], widget.periode);
    final prodi = pickString(akademik, ['program_studi', 'prodi', 'jurusan'], '-');
    final fakultas = pickString(akademik, ['fakultas', 'fak'], '-');
    final dosenPa = pickString(pa, ['nama', 'dosen_pa', 'pembimbing'], '-');

    List<Map<String, dynamic>> mkList = [];
    if (krsData['mata_kuliah'] is List) {
      mkList = (krsData['mata_kuliah'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } else {
      mkList = findMapList(krsData);
    }

    final totalSks = pickString(krsData, ['total_sks', 'jumlah_sks'], '');
    final maksSks = pickString(krsData, ['maks_sks', 'max_sks'], '');
    final periodeLabel = pickString(krsData, ['periode', 'nama_periode'], 'Periode ${widget.periode}');

    final mergedData = {
      'judul': 'KARTU RENCANA STUDI (KRS)',
      'universitas': 'UNIVERSITAS PUTRA INDONESIA YPTK PADANG',
      'periode': periodeLabel,
      'periode_kode': widget.periode,
      'total_sks': totalSks,
      'maks_sks': maksSks,
      'mahasiswa': {
        'nama': nama,
        'nobp': nim,
        'prodi': prodi,
        'fakultas': fakultas,
        'pembimbing': dosenPa,
      },
      'mata_kuliah': mkList,
      'tanggal_cetak': _formatCurrentDate(),
    };

    final generatedHtml = _generateHtmlFallback(mergedData);
    mergedData['html'] = generatedHtml;
    mergedData['raw_html'] = generatedHtml;

    return mergedData;
  }

  String _formatCurrentDate() {
    final now = DateTime.now();
    const months = [
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
      'Desember',
    ];
    return '${now.day} ${months[now.month]} ${now.year}';
  }

  String _generateHtmlFallback(Map<String, dynamic> data) {
    final mhs = asMap(data['mahasiswa']);
    final nama = pickString(mhs, ['nama'], '-');
    final nobp = pickString(mhs, ['nobp', 'nim'], '-');
    final prodi = pickString(mhs, ['prodi'], '-');
    final fakultas = pickString(mhs, ['fakultas'], '-');
    final dosenPa = pickString(mhs, ['pembimbing'], '-');
    final periode = pickString(data, ['periode'], widget.periode);
    final totalSks = pickString(data, ['total_sks'], '0');
    final maksSks = pickString(data, ['maks_sks'], '');
    final tglCetak = pickString(data, ['tanggal_cetak'], _formatCurrentDate());

    final mkList = asList(data['mata_kuliah'])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final rowsBuffer = StringBuffer();
    for (int i = 0; i < mkList.length; i++) {
      final mk = mkList[i];
      final kode = pickString(mk, ['kode', 'kode_mk', 'kd_mk'], '-');
      final namaMk = pickString(mk, ['nama', 'nama_mk', 'mata_kuliah'], '-');
      final sks = pickString(mk, ['sks'], '-');
      final kelas = pickString(mk, ['kelas', 'nama_kelas'], '-');
      final hari = pickString(mk, ['hari', 'hari_kuliah'], '');
      final jam = pickString(mk, ['jam', 'jam_kuliah', 'waktu'], '');
      final ruang = pickString(mk, ['ruang', 'kd_ruang', 'nama_ruang'], '-');
      final dosen = pickString(mk, ['dosen', 'nama_dosen', 'pengajar'], '-');
      final jadwalStr = hari.isNotEmpty && jam.isNotEmpty
          ? '$hari, $jam'
          : (hari.isNotEmpty ? hari : (jam.isNotEmpty ? jam : '-'));

      rowsBuffer.writeln('''
      <tr>
        <td style="text-align:center; padding: 6px 4px; border: 1px solid #cbd5e1;">${i + 1}</td>
        <td style="text-align:center; font-weight: bold; padding: 6px 4px; border: 1px solid #cbd5e1;">$kode</td>
        <td style="padding: 6px 8px; border: 1px solid #cbd5e1; font-weight: 600;">$namaMk</td>
        <td style="text-align:center; padding: 6px 4px; border: 1px solid #cbd5e1;">$sks</td>
        <td style="text-align:center; padding: 6px 4px; border: 1px solid #cbd5e1;">$kelas</td>
        <td style="text-align:center; padding: 6px 4px; border: 1px solid #cbd5e1;">$jadwalStr</td>
        <td style="text-align:center; padding: 6px 4px; border: 1px solid #cbd5e1;">$ruang</td>
        <td style="padding: 6px 8px; border: 1px solid #cbd5e1;">$dosen</td>
      </tr>
      ''');
    }

    final sksKet = maksSks.isNotEmpty ? '$totalSks SKS (Beban Maksimal: $maksSks SKS)' : '$totalSks SKS';

    return '''
<!DOCTYPE html>
<html lang="id">
<head>
  <meta charset="UTF-8">
  <title>KRS - $nobp - $nama</title>
  <style>
    @page { size: A4 portrait; margin: 12mm 15mm; }
    body {
      font-family: Arial, Helvetica, sans-serif;
      font-size: 11px;
      color: #1e293b;
      line-height: 1.35;
      background: #ffffff;
      margin: 0;
      padding: 0;
    }
    .kop {
      width: 100%;
      border-bottom: 2px solid #0f172a;
      padding-bottom: 8px;
      margin-bottom: 12px;
    }
    .kop h1 {
      margin: 0;
      font-size: 14px;
      font-weight: 900;
      color: #0f172a;
    }
    .kop h2 {
      margin: 2px 0 0 0;
      font-size: 11px;
      font-weight: 700;
      color: #b45309;
    }
    .kop p {
      margin: 2px 0 0 0;
      font-size: 9.5px;
      color: #64748b;
    }
    .title-doc {
      text-align: center;
      margin-bottom: 14px;
    }
    .title-doc h3 {
      margin: 0;
      font-size: 14px;
      font-weight: 900;
      color: #0f172a;
      text-decoration: underline;
    }
    .title-doc p {
      margin: 2px 0 0 0;
      font-size: 11px;
      font-weight: 700;
      color: #475569;
    }
    .info-table {
      width: 100%;
      margin-bottom: 14px;
      border-collapse: collapse;
    }
    .info-table td {
      padding: 3px 4px;
      font-size: 11px;
      vertical-align: top;
    }
    .krs-table {
      width: 100%;
      border-collapse: collapse;
      margin-bottom: 16px;
    }
    .krs-table th {
      background: #f1f5f9;
      color: #0f172a;
      font-weight: 800;
      font-size: 10px;
      text-align: center;
      padding: 7px 4px;
      border: 1px solid #cbd5e1;
    }
    .krs-table td {
      border: 1px solid #cbd5e1;
      padding: 6px 5px;
      font-size: 10.5px;
    }
    .signatures {
      width: 100%;
      margin-top: 24px;
      border-collapse: collapse;
    }
    .signatures td {
      width: 50%;
      text-align: center;
      vertical-align: top;
      font-size: 11px;
    }
    .sig-name {
      font-weight: 800;
      text-decoration: underline;
      color: #0f172a;
    }
    .notice {
      margin-top: 20px;
      padding: 8px 12px;
      background: #f8fafc;
      border: 1px solid #e2e8f0;
      border-radius: 6px;
      font-size: 9.5px;
      color: #64748b;
      text-align: center;
    }
  </style>
</head>
<body>
  <div class="kop">
    <h1>UNIVERSITAS PUTRA INDONESIA "YPTK" PADANG</h1>
    <h2>SISTEM INFORMASI AKADEMIK (SIAKAD)</h2>
    <p>Jl. Raya Lubuk Begalung, Padang, Sumatera Barat &bull; Telp: (0751) 776666 &bull; Web: https://upiyptk.ac.id</p>
  </div>

  <div class="title-doc">
    <h3>KARTU RENCANA STUDI (KRS)</h3>
    <p>${periode.toUpperCase()}</p>
  </div>

  <table class="info-table">
    <tr>
      <td style="width: 130px; font-weight: 600; color: #475569;">Nama Mahasiswa</td>
      <td style="width: 10px;">:</td>
      <td style="font-weight: 700; color: #0f172a;">$nama</td>
      <td style="width: 110px; font-weight: 600; color: #475569;">No. BP / NIM</td>
      <td style="width: 10px;">:</td>
      <td style="font-weight: 700; color: #0f172a;">$nobp</td>
    </tr>
    <tr>
      <td style="font-weight: 600; color: #475569;">Program Studi</td>
      <td>:</td>
      <td style="font-weight: 700; color: #0f172a;">$prodi</td>
      <td style="font-weight: 600; color: #475569;">Fakultas</td>
      <td>:</td>
      <td style="font-weight: 700; color: #0f172a;">$fakultas</td>
    </tr>
    <tr>
      <td style="font-weight: 600; color: #475569;">Dosen Pembimbing PA</td>
      <td>:</td>
      <td style="font-weight: 700; color: #0f172a;">$dosenPa</td>
      <td style="font-weight: 600; color: #475569;">Total Beban SKS</td>
      <td>:</td>
      <td style="font-weight: 700; color: #0f172a;">$sksKet</td>
    </tr>
  </table>

  <table class="krs-table">
    <thead>
      <tr>
        <th style="width: 26px;">NO</th>
        <th style="width: 75px;">KODE</th>
        <th>MATA KULIAH</th>
        <th style="width: 35px;">SKS</th>
        <th style="width: 45px;">KELAS</th>
        <th style="width: 110px;">JADWAL</th>
        <th style="width: 60px;">RUANG</th>
        <th style="width: 130px;">DOSEN PENGAMPU</th>
      </tr>
    </thead>
    <tbody>
      ${rowsBuffer.toString()}
      <tr style="background: #fef3c7; font-weight: 800; color: #78350f;">
        <td style="text-align: center; padding: 7px 4px; border: 1px solid #cbd5e1;">-</td>
        <td style="text-align: center; padding: 7px 4px; border: 1px solid #cbd5e1;">TOTAL</td>
        <td style="padding: 7px 8px; border: 1px solid #cbd5e1;">Jumlah SKS yang diambil</td>
        <td style="text-align: center; padding: 7px 4px; border: 1px solid #cbd5e1; font-size: 11.5px;">$totalSks</td>
        <td style="border: 1px solid #cbd5e1;"></td>
        <td style="border: 1px solid #cbd5e1;"></td>
        <td style="border: 1px solid #cbd5e1;"></td>
        <td style="border: 1px solid #cbd5e1;"></td>
      </tr>
    </tbody>
  </table>

  <table class="signatures">
    <tr>
      <td>
        Mengetahui,<br>
        <strong>Mahasiswa Yang Bersangkutan</strong>
        <div style="height: 55px;"></div>
        <span class="sig-name">$nama</span><br>
        <span style="color: #64748b;">BP: $nobp</span>
      </td>
      <td>
        Padang, $tglCetak<br>
        <strong>Pembimbing Akademik (PA)</strong>
        <div style="height: 55px;"></div>
        <span class="sig-name">$dosenPa</span><br>
        <span style="color: #64748b;">Dosen Pembimbing</span>
      </td>
    </tr>
  </table>

  <div class="notice">
    Dokumen sah Kartu Rencana Studi (KRS) dicetak langsung melalui SIAKAD Mobile UPI YPTK Padang pada $tglCetak.
  </div>
</body>
</html>
''';
  }

  Future<void> _cetakPdf(String htmlContent) async {
    if (_isPrinting) return;
    setState(() => _isPrinting = true);
    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async {
          // ignore: deprecated_member_use
          return await Printing.convertHtml(
            format: format,
            html: htmlContent,
          );
        },
        name: 'KRS_${widget.periode}.pdf',
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
    final nobp = pickString(mhs, ['nobp', 'nim'], '-');
    final prodi = pickString(mhs, ['prodi'], '-');
    final periode = pickString(data, ['periode'], widget.periode);
    final totalSks = pickString(data, ['total_sks'], '-');
    final mkList = asList(data['mata_kuliah']);

    final buffer = StringBuffer();
    buffer.writeln('KARTU RENCANA STUDI (KRS)');
    buffer.writeln('UNIVERSITAS PUTRA INDONESIA YPTK PADANG');
    buffer.writeln('Periode: $periode');
    buffer.writeln('----------------------------------------');
    buffer.writeln('Nama Mahasiswa : $nama');
    buffer.writeln('No. BP / NIM   : $nobp');
    buffer.writeln('Program Studi  : $prodi');
    buffer.writeln('Total SKS      : $totalSks SKS');
    buffer.writeln('----------------------------------------');
    buffer.writeln('Daftar Mata Kuliah:');
    for (int i = 0; i < mkList.length; i++) {
      final item = asMap(mkList[i]);
      final kode = pickString(item, ['kode', 'kode_mk', 'kd_mk'], '');
      final namaMk = pickString(item, ['nama', 'nama_mk', 'mata_kuliah'], 'MK');
      final sks = pickString(item, ['sks'], '0');
      final kls = pickString(item, ['kelas'], '');
      final jadwal = pickString(item, ['hari', 'jam'], '');
      buffer.writeln('${i + 1}. [$kode] $namaMk ($sks SKS) - Kls: $kls - $jadwal');
    }
    buffer.writeln('----------------------------------------');
    buffer.writeln('Dicetak pada: ${pickString(data, ['tanggal_cetak'], _formatCurrentDate())}');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    appToast(context, 'Rincian lembar KRS berhasil disalin ke clipboard.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      body: Column(
        children: [
          GradientHeader(
            title: 'Lembar Cetak KRS',
            subtitle: 'Periode ${widget.periode} • Dokumen Resmi Akademik',
            leading: Navigator.of(context).canPop() ? const HeaderBackButton() : null,
            actions: [
              HeaderActionButton(
                icon: Icons.copy_rounded,
                tooltip: 'Salin Teks KRS',
                onPressed: () async {
                  try {
                    final d = await _future;
                    if (mounted) _salinRincian(d);
                  } catch (_) {}
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
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: LoadingView(label: 'Menyiapkan lembar cetak KRS...'),
                  );
                }

                if (snap.hasError) {
                  return ErrorRetry(
                    message: errorText(snap.error ?? 'Terjadi kesalahan tidak dikenal.'),
                    onRetry: () => setState(() => _future = _loadData()),
                  );
                }

                final data = snap.data ?? const <String, dynamic>{};
                return _buildPaperSheet(context, data);
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          final data = snap.data ?? const <String, dynamic>{};
          final htmlContent = pickString(data, ['html', 'raw_html'], '');
          if (htmlContent.isEmpty) return const SizedBox.shrink();

          return Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: context.card,
              border: Border(top: BorderSide(color: context.border, width: 0.5)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'KRS Periode ${widget.periode}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: context.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Siap dicetak atau disimpan ke PDF',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: context.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _isPrinting ? null : () => _cetakPdf(htmlContent),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryYellow,
                      foregroundColor: const Color(0xFF1C1917),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
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
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPaperSheet(BuildContext context, Map<String, dynamic> data) {
    final mhs = asMap(data['mahasiswa']);
    final nama = pickString(mhs, ['nama'], '-');
    final nobp = pickString(mhs, ['nobp', 'nim'], '-');
    final prodi = pickString(mhs, ['prodi'], '-');
    final fakultas = pickString(mhs, ['fakultas'], '-');
    final dosenPa = pickString(mhs, ['pembimbing'], '-');

    final periode = pickString(data, ['periode'], widget.periode);
    final totalSks = pickString(data, ['total_sks'], '-');
    final maksSks = pickString(data, ['maks_sks'], '');
    final tglCetak = pickString(data, ['tanggal_cetak'], _formatCurrentDate());

    final List<Map<String, dynamic>> mkList = asList(data['mata_kuliah'])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // KOP SURAT UPI YPTK
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppColors.upiYellowBright,
                            AppColors.upiYellowDeep,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'YPTK',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'UNIVERSITAS PUTRA INDONESIA "YPTK" PADANG',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1E293B),
                              height: 1.2,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'SISTEM INFORMASI AKADEMIK (SIAKAD)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.upiYellowDeep,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 1),
                          Text(
                            'Jl. Raya Lubuk Begalung, Padang, Sumatera Barat - Telp: (0751) 776666',
                            style: TextStyle(
                              fontSize: 9.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(thickness: 2, height: 2, color: Color(0xFF1E293B)),
                const SizedBox(height: 2),
                const Divider(thickness: 0.8, height: 0.8, color: Color(0xFF1E293B)),

                const SizedBox(height: 16),

                // JUDUL DOKUMEN
                Center(
                  child: Column(
                    children: [
                      const Text(
                        'KARTU RENCANA STUDI (KRS)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                          letterSpacing: 0.8,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        periode.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // IDENTITAS MAHASISWA
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      _infoRow('Nama Mahasiswa', nama, 'No. BP / NIM', nobp),
                      const SizedBox(height: 6),
                      _infoRow('Program Studi', prodi, 'Fakultas', fakultas),
                      const SizedBox(height: 6),
                      _infoRow(
                        'Pembimbing Akademik',
                        dosenPa,
                        'Beban SKS',
                        maksSks.isNotEmpty ? '$totalSks SKS (Maks: $maksSks)' : '$totalSks SKS',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // TABEL MATA KULIAH
                const Text(
                  'DAFTAR MATA KULIAH YANG DIAMBIL',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF334155),
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 8),

                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Table(
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    columnWidths: const {
                      0: FixedColumnWidth(34),  // No
                      1: FixedColumnWidth(90),  // Kode
                      2: FixedColumnWidth(210), // Nama MK
                      3: FixedColumnWidth(46),  // SKS
                      4: FixedColumnWidth(55),  // Kelas
                      5: FixedColumnWidth(110), // Jadwal
                      6: FixedColumnWidth(70),  // Ruang
                      7: FixedColumnWidth(170), // Dosen
                    },
                    border: TableBorder.all(
                      color: const Color(0xFFCBD5E1),
                      width: 1,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    children: [
                      // Header
                      TableRow(
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9),
                        ),
                        children: [
                          _th('NO'),
                          _th('KODE'),
                          _th('MATA KULIAH'),
                          _th('SKS'),
                          _th('KLS'),
                          _th('HARI / JAM'),
                          _th('RUANG'),
                          _th('DOSEN PENGAMPU'),
                        ],
                      ),
                      // Data
                      for (int i = 0; i < mkList.length; i++) ...[
                        _buildTableRow(i + 1, mkList[i]),
                      ],
                      // Footer Total
                      TableRow(
                        decoration: const BoxDecoration(
                          color: Color(0xFFFEF3C7),
                        ),
                        children: [
                          const TableCell(child: SizedBox()),
                          const TableCell(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                              child: Text(
                                'TOTAL',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                  color: Color(0xFF78350F),
                                ),
                              ),
                            ),
                          ),
                          const TableCell(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                              child: Text(
                                'Jumlah SKS yang diambil',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                  color: Color(0xFF78350F),
                                ),
                              ),
                            ),
                          ),
                          TableCell(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                              child: Text(
                                totalSks.isNotEmpty ? totalSks : '-',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                  color: Color(0xFF78350F),
                                ),
                              ),
                            ),
                          ),
                          const TableCell(child: SizedBox()),
                          const TableCell(child: SizedBox()),
                          const TableCell(child: SizedBox()),
                          const TableCell(child: SizedBox()),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // PENGESAHAN / TANDA TANGAN
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Kolom Mahasiswa
                    Expanded(
                      child: Column(
                        children: [
                          const Text(
                            'Mengetahui,',
                            style: TextStyle(fontSize: 11, color: Color(0xFF475569)),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Mahasiswa Yang Bersangkutan',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 56),
                          Text(
                            nama,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          Text(
                            'BP: $nobp',
                            style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 24),

                    // Kolom Dosen Pembimbing
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'Padang, $tglCetak',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Pembimbing Akademik (PA)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 56),
                          Text(
                            dosenPa,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          const Text(
                            'Dosen Pembimbing',
                            style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // FOOTER CATATAN RESMI
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_rounded,
                          size: 16, color: AppColors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Dokumen sah dicetak langsung melalui SIAKAD Mobile UPI YPTK Padang pada $tglCetak.',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label1, String val1, String label2, String val2) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 130,
                child: Text(
                  label1,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
              const Text(': ',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              Expanded(
                child: Text(
                  val1,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  label2,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
              const Text(': ',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              Expanded(
                child: Text(
                  val2,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _th(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: Color(0xFF1E293B),
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  TableRow _buildTableRow(int index, Map<String, dynamic> item) {
    final kode = pickString(item, ['kode', 'kode_mk', 'kd_mk'], '-');
    final nama = pickString(item, ['nama', 'nama_mk', 'mata_kuliah'], '-');
    final sks = pickString(item, ['sks'], '-');
    final kelas = pickString(item, ['kelas', 'nama_kelas'], '-');
    final hari = pickString(item, ['hari', 'hari_kuliah'], '');
    final jam = pickString(item, ['jam', 'jam_kuliah', 'waktu'], '');
    final ruang = pickString(item, ['ruang', 'kd_ruang', 'nama_ruang'], '-');
    final dosen = pickString(item, ['dosen', 'nama_dosen', 'pengajar'], '-');

    final jadwalStr = hari.isNotEmpty && jam.isNotEmpty
        ? '$hari\n$jam'
        : (hari.isNotEmpty ? hari : (jam.isNotEmpty ? jam : '-'));

    final isEven = index % 2 == 0;
    return TableRow(
      decoration: BoxDecoration(
        color: isEven ? const Color(0xFFF8FAFC) : Colors.white,
      ),
      children: [
        _td('$index', align: TextAlign.center),
        _td(kode, align: TextAlign.center, isBold: true),
        _td(nama, isBold: true),
        _td(sks, align: TextAlign.center),
        _td(kelas, align: TextAlign.center),
        _td(jadwalStr, align: TextAlign.center),
        _td(ruang, align: TextAlign.center),
        _td(dosen),
      ],
    );
  }

  Widget _td(String text, {TextAlign align = TextAlign.left, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
          color: const Color(0xFF1E293B),
          height: 1.25,
        ),
      ),
    );
  }
}
