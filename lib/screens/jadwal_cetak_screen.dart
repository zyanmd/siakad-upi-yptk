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

/// Halaman tampilan resmi lembar cetak Jadwal Perkuliahan
/// yang menampilkan dokumen cetak resmi secara langsung di dalam aplikasi
/// dan menyediakan tombol Cetak PDF resmi (melalui printer / simpan PDF native).
class JadwalCetakScreen extends StatefulWidget {
  const JadwalCetakScreen({super.key, required this.periode});

  final String periode;

  @override
  State<JadwalCetakScreen> createState() => _JadwalCetakScreenState();
}

class _JadwalCetakScreenState extends State<JadwalCetakScreen> {
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

    // 1. Panggil endpoint resmi GET /api/akademik/jadwal/cetak
    try {
      final cetakResp = await srv.jadwalCetak(widget.periode);
      final map = asMap(cetakResp);
      final data = asMap(map['data'] ?? map);
      final rawHtml = pickString(data, ['html', 'raw_html'], '');
      if (rawHtml.isNotEmpty || data.containsKey('mata_kuliah')) {
        return data;
      }
    } catch (_) {
      // Fallback lanjut ke bawah jika endpoint gagal
    }

    // 2. Fallback: ambil dari /api/akademik/jadwal
    final jadwalResp = await srv.jadwal(widget.periode);
    final jMap = asMap(jadwalResp);
    final jData = asMap(jMap['data'] ?? jMap);
    return jData;
  }

  String _cleanHtmlText(String raw) {
    return raw
        .replaceAll(RegExp(r'<br\s*\/?>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<_ParsedJadwalRow> _extractRows(Map<String, dynamic> data) {
    final html = pickString(data, ['html', 'raw_html'], '');
    final rows = <_ParsedJadwalRow>[];

    if (html.isNotEmpty) {
      final tbodyMatch = RegExp(r'<tbody>(.*?)<\/tbody>', dotAll: true).firstMatch(html);
      final content = tbodyMatch != null ? tbodyMatch.group(1)! : html;
      final trMatches = RegExp(r'<tr[^>]*>(.*?)<\/tr>', dotAll: true).allMatches(content);

      for (final tr in trMatches) {
        final trHtml = tr.group(1)!;
        final tdMatches = RegExp(r'<td[^>]*>(.*?)<\/td>', dotAll: true).allMatches(trHtml).toList();
        if (tdMatches.length >= 9) {
          final no = _cleanHtmlText(tdMatches[0].group(1)!);
          final hari = _cleanHtmlText(tdMatches[1].group(1)!);
          final jam = _cleanHtmlText(tdMatches[2].group(1)!);
          final kode = _cleanHtmlText(tdMatches[3].group(1)!);
          final rawMk = tdMatches[4].group(1)!;
          final mkName = _cleanHtmlText(RegExp(r'<strong>(.*?)<\/strong>').firstMatch(rawMk)?.group(1) ?? rawMk);
          final mkSem = _cleanHtmlText(RegExp(r'<span>(.*?)<\/span>').firstMatch(rawMk)?.group(1) ?? '');
          final kelas = _cleanHtmlText(tdMatches[5].group(1)!);
          final ruang = _cleanHtmlText(tdMatches[6].group(1)!);
          final dosen = _cleanHtmlText(tdMatches[7].group(1)!);
          final sks = _cleanHtmlText(tdMatches[8].group(1)!);

          if (no.isNotEmpty && no != '-') {
            rows.add(_ParsedJadwalRow(
              no: no,
              hari: hari,
              jam: jam,
              kode: kode,
              matkul: mkName,
              semester: mkSem,
              kelas: kelas,
              ruang: ruang,
              dosen: dosen,
              sks: sks,
              isDayStart: tr.group(0)?.contains('day-start') ?? false,
            ));
          }
        }
      }
    }

    // Jika parsing HTML kosong, ambil dari mata_kuliah JSON atau jadwal JSON
    if (rows.isEmpty) {
      if (data['mata_kuliah'] is List) {
        int idx = 1;
        for (final item in (data['mata_kuliah'] as List)) {
          if (item is Map) {
            final m = asMap(item);
            rows.add(_ParsedJadwalRow(
              no: pickString(m, ['no'], '${idx++}'),
              hari: pickString(m, ['hari', 'kode'], 'Senin'),
              jam: pickString(m, ['jam', 'nama'], '-'),
              kode: pickString(m, ['kode', 'kelas'], '-'),
              matkul: pickString(m, ['nama', 'matkul', 'sks'], 'Mata Kuliah'),
              semester: pickString(m, ['semester'], ''),
              kelas: pickString(m, ['kelas', 'hari'], '-'),
              ruang: pickString(m, ['ruang'], '-'),
              dosen: pickString(m, ['dosen'], '-'),
              sks: pickString(m, ['sks'], '-'),
              isDayStart: false,
            ));
          }
        }
      } else if (data['jadwal'] is Map) {
        final jm = asMap(data['jadwal']);
        int idx = 1;
        jm.forEach((hari, list) {
          if (list is List) {
            bool first = true;
            for (final s in list) {
              if (s is Map) {
                final m = asMap(s);
                final wm = pickString(m, ['waktu_mulai', 'jam_mulai'], '');
                final ws = pickString(m, ['waktu_selesai', 'jam_selesai'], '');
                rows.add(_ParsedJadwalRow(
                  no: '${idx++}',
                  hari: hari,
                  jam: wm.isNotEmpty && ws.isNotEmpty ? '$wm s.d. ${ws.replaceFirst('s.d. ', '')}' : pickString(m, ['jam'], '-'),
                  kode: pickString(m, ['kode'], '-'),
                  matkul: pickString(m, ['matkul', 'nama_mk'], 'Mata Kuliah'),
                  semester: pickString(m, ['info'], ''),
                  kelas: pickString(m, ['kelas'], '-'),
                  ruang: pickString(m, ['ruang'], '-'),
                  dosen: pickString(m, ['dosen'], '-'),
                  sks: pickString(m, ['sks'], '3'),
                  isDayStart: first,
                ));
                first = false;
              }
            }
          }
        });
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
          // ignore: deprecated_member_use
          return await Printing.convertHtml(
            format: format,
            html: htmlContent,
          );
        },
        name: 'Jadwal_Kuliah_${widget.periode}.pdf',
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
    final prodi = pickString(mhs, ['program_studi', 'prodi'], '-');
    final header = asMap(data['header']);
    final subtitle = pickString(header, ['subtitle'], widget.periode);
    final totalSks = pickString(data, ['total_sks'], '-');
    final rows = _extractRows(data);

    final buffer = StringBuffer();
    buffer.writeln('JADWAL PERKULIAHAN');
    buffer.writeln('UNIVERSITAS PUTRA INDONESIA YPTK PADANG');
    buffer.writeln('Periode: $subtitle');
    buffer.writeln('----------------------------------------');
    buffer.writeln('Nama Mahasiswa : $nama');
    buffer.writeln('NIM / No. BP   : $nim');
    buffer.writeln('Program Studi  : $prodi');
    buffer.writeln('Total SKS      : $totalSks SKS');
    buffer.writeln('----------------------------------------');
    buffer.writeln('Daftar Sesi Kuliah:');
    for (final r in rows) {
      buffer.writeln('${r.no}. [${r.hari} ${r.jam}] [${r.kode}] ${r.matkul} (${r.sks} SKS) - Kls: ${r.kelas} - Ruang: ${r.ruang} - Dosen: ${r.dosen}');
    }
    buffer.writeln('----------------------------------------');
    buffer.writeln('Dicetak melalui SIAKAD Mobile');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    appToast(context, 'Rincian lembar jadwal berhasil disalin ke clipboard.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      body: Column(
        children: [
          GradientHeader(
            title: 'Lembar Cetak Jadwal',
            subtitle: 'Periode ${widget.periode} • Dokumen Resmi Akademik',
            leading: Navigator.of(context).canPop() ? const HeaderBackButton() : null,
            actions: [
              HeaderActionButton(
                icon: Icons.copy_rounded,
                tooltip: 'Salin Teks Jadwal',
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
                    child: LoadingView(label: 'Menyiapkan lembar cetak jadwal...'),
                  );
                }

                if (snap.hasError) {
                  return ErrorRetry(
                    message: errorText(snap.error ?? 'Terjadi kesalahan.'),
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
          final webUrl = pickString(data, ['url', 'print_url'], '');

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
                          'Jadwal Kuliah ${widget.periode}',
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
                  if (webUrl.isNotEmpty && webUrl.startsWith('http')) ...[
                    OutlinedButton.icon(
                      onPressed: () => openExternal(context, webUrl),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.public_rounded, size: 16),
                      label: const Text('Web', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 8),
                  ],
                  FilledButton.icon(
                    onPressed: _isPrinting || htmlContent.isEmpty
                        ? null
                        : () => _cetakPdf(htmlContent),
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
    final header = asMap(data['header']);
    final judul = pickString(header, ['judul'], 'JADWAL PERKULIAHAN');
    final subtitle = pickString(header, ['subtitle'], 'Ganjil • Tahun Akademik ${widget.periode} • Reguler');
    final logoUrl = pickString(header, ['logo_url'], '');

    final mhs = asMap(data['mahasiswa']);
    final nama = pickString(mhs, ['nama'], '-');
    final nim = pickString(mhs, ['nim', 'nobp'], '-');
    final prodi = pickString(mhs, ['program_studi', 'prodi'], '-');
    final jenjang = pickString(mhs, ['jenjang_/_program', 'jenjang', 'program'], 'S1 / Reguler');
    final periodeKuliah = pickString(mhs, ['periode_kuliah', 'tanggal'], '-');
    final totalJadwal = pickString(mhs, ['total_jadwal'], '-');
    final totalSks = pickString(data, ['total_sks'], '23');

    final rows = _extractRows(data);
    final signatures = asList(data['signatures']).map((e) => asMap(e)).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
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
                if (logoUrl.isNotEmpty && logoUrl.startsWith('http'))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Image.network(
                      logoUrl,
                      height: 52,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => _buildFallbackKop(),
                    ),
                  )
                else
                  _buildFallbackKop(),

                const SizedBox(height: 10),
                const Divider(thickness: 2, height: 2, color: Color(0xFF1E293B)),
                const SizedBox(height: 16),

                // JUDUL DOKUMEN & VALIDATION BADGE
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Column(
                      children: [
                        Text(
                          judul,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF263B62),
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF8F2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFA9D8C7)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_rounded, size: 12, color: Color(0xFF16835F)),
                            SizedBox(width: 3),
                            Text(
                              'KRS Tervalidasi',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF16835F),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // IDENTITAS MAHASISWA
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCFD6DF)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 3.5,
                        height: 60,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4A315),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          children: [
                            _mhsRow('Nama', nama, 'Jenjang / Program', jenjang),
                            const SizedBox(height: 4),
                            _mhsRow('NIM', nim, 'Periode Kuliah', periodeKuliah),
                            const SizedBox(height: 4),
                            _mhsRow('Program Studi', prodi, 'Total Jadwal', totalJadwal != '-' ? totalJadwal : '$totalSks SKS'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // TABEL JADWAL PERKULIAHAN (Horizontal scrollable untuk layar HP)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 700),
                    child: Table(
                      border: TableBorder.all(color: const Color(0xFFCFD6DF), width: 1),
                      columnWidths: const {
                        0: FixedColumnWidth(32),  // No
                        1: FixedColumnWidth(65),  // Hari
                        2: FixedColumnWidth(100), // Jam
                        3: FixedColumnWidth(85),  // Kode
                        4: FlexColumnWidth(2.2),  // Mata Kuliah
                        5: FixedColumnWidth(48),  // Kelas
                        6: FixedColumnWidth(65),  // Ruang
                        7: FlexColumnWidth(2.0),  // Dosen Pengampu
                        8: FixedColumnWidth(40),  // SKS
                      },
                      children: [
                        // Header Table
                        TableRow(
                          decoration: const BoxDecoration(color: Color(0xFF263B62)),
                          children: [
                            _th('NO'),
                            _th('HARI'),
                            _th('JAM'),
                            _th('KODE'),
                            _th('MATA KULIAH'),
                            _th('KELAS'),
                            _th('RUANG'),
                            _th('DOSEN PENGAMPU'),
                            _th('SKS'),
                          ],
                        ),
                        // Data Rows
                        for (final r in rows)
                          TableRow(
                            decoration: BoxDecoration(
                              color: r.isDayStart ? const Color(0xFFFFFBEB) : Colors.white,
                            ),
                            children: [
                              _td(r.no, align: TextAlign.center),
                              _td(r.hari, align: TextAlign.center, bold: true),
                              _td(r.jam, align: TextAlign.center, fontSize: 10.5),
                              _td(r.kode, align: TextAlign.center, bold: true, color: const Color(0xFF263B62)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      r.matkul,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                    if (r.semester.isNotEmpty)
                                      Text(
                                        r.semester,
                                        style: const TextStyle(
                                          fontSize: 9.5,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              _td(r.kelas, align: TextAlign.center),
                              _td(r.ruang, align: TextAlign.center),
                              _td(r.dosen, fontSize: 10.5),
                              _td(r.sks, align: TextAlign.center, bold: true),
                            ],
                          ),
                        // Footer Total SKS
                        TableRow(
                          decoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
                          children: [
                            const SizedBox.shrink(),
                            const SizedBox.shrink(),
                            const SizedBox.shrink(),
                            const SizedBox.shrink(),
                            const SizedBox.shrink(),
                            const SizedBox.shrink(),
                            const SizedBox.shrink(),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                              child: Text(
                                'TOTAL SKS',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            _td(totalSks, align: TextAlign.center, bold: true),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // CATATAN
                const Text(
                  'Jadwal ini hanya memuat mata kuliah dari KRS mahasiswa yang telah berstatus Disetujui. Perubahan ruang, dosen, atau waktu mengikuti pembaruan resmi pada SIAKAD.',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF64748B),
                    fontStyle: FontStyle.italic,
                  ),
                ),

                const SizedBox(height: 28),

                // TANDA TANGAN
                if (signatures.length >= 2) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSignatureBox(
                        label: pickString(signatures[0], ['label'], 'Mahasiswa,'),
                        nama: pickString(signatures[0], ['nama'], nama),
                        id: pickString(signatures[0], ['id'], 'NIM. $nim'),
                      ),
                      _buildSignatureBox(
                        label: pickString(signatures[1], ['label'], 'Dosen Pembimbing Akademik,'),
                        nama: pickString(signatures[1], ['nama'], '-'),
                        id: pickString(signatures[1], ['id'], '-'),
                      ),
                    ],
                  ),
                ] else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSignatureBox(
                        label: 'Mahasiswa,',
                        nama: nama,
                        id: 'NIM. $nim',
                      ),
                      _buildSignatureBox(
                        label: 'Dosen Pembimbing Akademik,',
                        nama: 'Dosen Pembimbing',
                        id: 'NIDN. -',
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 24),
                const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 8),

                // FOOTER META
                Center(
                  child: Text(
                    pickString(data, ['meta'], 'Dicetak melalui SIAKAD • Sumber: KRS tervalidasi mahasiswa.'),
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackKop() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.upiYellowBright, AppColors.upiYellowDeep],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Center(
            child: Text(
              'YPTK',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'UNIVERSITAS PUTRA INDONESIA "YPTK" PADANG',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E293B),
                ),
              ),
              SizedBox(height: 2),
              Text(
                'SISTEM INFORMASI AKADEMIK (SIAKAD)',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.upiYellowDeep,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _mhsRow(String l1, String v1, String l2, String v2) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              SizedBox(
                width: 95,
                child: Text(
                  l1,
                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                ),
              ),
              const Text(': ', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
              Expanded(
                child: Text(
                  v1,
                  style: const TextStyle(
                    fontSize: 11,
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
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  l2,
                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                ),
              ),
              const Text(': ', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
              Expanded(
                child: Text(
                  v2,
                  style: const TextStyle(
                    fontSize: 11,
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

  Widget _th(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _td(
    String val, {
    TextAlign align = TextAlign.left,
    bool bold = false,
    Color? color,
    double fontSize = 11,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
      child: Text(
        val,
        textAlign: align,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          color: color ?? const Color(0xFF1E293B),
        ),
      ),
    );
  }

  Widget _buildSignatureBox({
    required String label,
    required String nama,
    required String id,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
        ),
        const SizedBox(height: 50),
        Container(
          width: 180,
          padding: const EdgeInsets.only(top: 4),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFF334155), width: 1)),
          ),
          child: Column(
            children: [
              Text(
                nama,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                id,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ParsedJadwalRow {
  final String no;
  final String hari;
  final String jam;
  final String kode;
  final String matkul;
  final String semester;
  final String kelas;
  final String ruang;
  final String dosen;
  final String sks;
  final bool isDayStart;

  _ParsedJadwalRow({
    required this.no,
    required this.hari,
    required this.jam,
    required this.kode,
    required this.matkul,
    required this.semester,
    required this.kelas,
    required this.ruang,
    required this.dosen,
    required this.sks,
    required this.isDayStart,
  });
}

