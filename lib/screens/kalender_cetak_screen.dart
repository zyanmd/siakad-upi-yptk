import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../services/akademik_service.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../utils/kalender_pdf.dart';
import '../utils/smart.dart';
import '../widgets/common.dart';
import '../widgets/gradient_header.dart';

/// Halaman lembar cetak resmi Kalender Akademik UPI YPTK Padang.
/// Menampilkan pratinjau dokumen kertas dan pratinjau PDF vektor instan (<30ms).
class KalenderCetakScreen extends StatefulWidget {
  const KalenderCetakScreen({
    super.key,
    required this.token,
    this.tahun,
    this.initialData,
  });

  final String token;
  final String? tahun;
  final Map<String, dynamic>? initialData;

  @override
  State<KalenderCetakScreen> createState() => _KalenderCetakScreenState();
}

class _KalenderCetakScreenState extends State<KalenderCetakScreen> {
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

    // 1. Coba panggil /api/akademik/kalender/cetak/{token}
    try {
      final cetakResp = await srv.kalenderCetak(widget.token);
      final cMap = asMap(cetakResp);
      final cData = asMap(cMap['data'] ?? cMap);
      if (cData.isNotEmpty && cData['kegiatan'] != null) {
        result = cData;
      }
    } catch (_) {}

    // 2. Jika gagal atau kosong, gunakan detail atau fallback data
    if (result.isEmpty || result['kegiatan'] == null) {
      if (widget.initialData != null && widget.initialData!.isNotEmpty) {
        result = Map<String, dynamic>.from(widget.initialData!);
      } else {
        try {
          final detailResp = await srv.kalenderDetail(widget.token, tahun: widget.tahun);
          final dMap = asMap(detailResp);
          final dData = asMap(dMap['data'] ?? dMap);
          if (dData.isNotEmpty) {
            result = dData;
          }
        } catch (_) {}
      }
    }

    // Normalisasi field jika perlu
    if (!result.containsKey('periode')) {
      final th = pickString(result, ['tahun'], widget.tahun ?? currentTahunAkademik());
      final dip = pickString(result, ['diperbarui'], '');
      result['periode'] = 'Tahun Akademik $th ${dip.isNotEmpty ? '• $dip' : ''}'.trim();
    }

    return result;
  }

  Future<void> _cetakPdf(Map<String, dynamic> data) async {
    if (_isPrinting) return;
    setState(() => _isPrinting = true);
    try {
      final tahunSlug = pickString(data, ['tahun'], 'UPI').replaceAll('/', '_');
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async {
          return await KalenderPdfHelper.buildPdf(format, data);
        },
        name: 'Kalender_Akademik_$tahunSlug.pdf',
      );
    } catch (e) {
      if (mounted) {
        appToast(context, 'Gagal mencetak dokumen: $e', error: true);
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  void _salinAgenda(Map<String, dynamic> data) {
    final judul = pickString(data, ['judul'], 'KALENDER AKADEMIK');
    final periode = pickString(data, ['periode', 'tahun'], '');
    final rawKegiatan = data['kegiatan'];

    final buffer = StringBuffer();
    buffer.writeln(judul.toUpperCase());
    buffer.writeln('UNIVERSITAS PUTRA INDONESIA YPTK PADANG');
    if (periode.isNotEmpty) buffer.writeln(periode);
    buffer.writeln('----------------------------------------');

    if (rawKegiatan is List) {
      String? currentGrup;
      for (final k in rawKegiatan) {
        if (k is Map) {
          final km = asMap(k);
          final grup = pickString(km, ['grup'], '');
          if (grup != currentGrup) {
            currentGrup = grup;
            buffer.writeln('\n[ ${grup.isEmpty ? 'Semester Ganjil' : grup} ]');
          }
          final no = pickString(km, ['no'], '');
          final keg = pickString(km, ['kegiatan'], '-');
          final jad = pickString(km, ['jadwal'], '-');
          if (no.isNotEmpty) {
            buffer.writeln('$no $keg : $jad');
          } else {
            buffer.writeln('  • $keg ($jad)');
          }
        }
      }
    }
    buffer.writeln('----------------------------------------');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    appToast(context, 'Agenda kalender akademik berhasil disalin.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      body: Column(
        children: [
          GradientHeader(
            title: 'Lembar Kalender Akademik',
            subtitle: 'Dokumen Resmi Agenda Perkuliahan',
            leading: Navigator.of(context).canPop() ? const HeaderBackButton() : null,
            actions: [
              HeaderActionButton(
                icon: Icons.copy_rounded,
                tooltip: 'Salin Agenda',
                onPressed: () async {
                  final data = await _future;
                  if (mounted && data.isNotEmpty) _salinAgenda(data);
                },
              ),
              HeaderActionButton(
                icon: Icons.public_rounded,
                tooltip: 'Buka di Web SIAKAD',
                onPressed: () async {
                  final data = await _future;
                  final url = pickString(data, ['url', 'print_url'], '');
                  if (url.isNotEmpty && url.startsWith('http')) {
                    if (context.mounted) await openExternal(context, url);
                  } else {
                    if (context.mounted) {
                      appToast(context, 'Tautan web tidak tersedia.', error: true);
                    }
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
              child: LoadingView(label: 'Memuat lembar cetak kalender...'),
            );
          }
          if (snapshot.hasError) {
            return ErrorRetry(
              message: 'Gagal memuat kalender: ${snapshot.error}',
              onRetry: () => setState(() => _future = _loadData()),
            );
          }

          final data = snapshot.data ?? {};
          final toolbar = asMap(data['toolbar']);
          final labelCetak = pickString(
            asMap(toolbar['cetak']),
            ['label'],
            pickString(toolbar, ['cetak'], 'Cetak / Simpan PDF'),
          );
          final labelKembali = pickString(
            asMap(toolbar['kembali']),
            ['label'],
            pickString(toolbar, ['kembali', 'tutup'], 'Kembali'),
          );

          return Column(
            children: [
              // Toolbar resmi respon API & kontrol pratinjau instan
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
                    // Tombol Kembali / Tutup & Mode Switcher
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
                          label: Text(labelKembali, style: const TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
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
                        build: (format) => KalenderPdfHelper.buildPdf(format, data),
                        allowPrinting: true,
                        allowSharing: true,
                        canChangeOrientation: false,
                        canChangePageFormat: false,
                        canDebug: false,
                        initialPageFormat: PdfPageFormat.a4,
                        pdfFileName:
                            'Kalender_Akademik_${pickString(data, ['tahun'], 'UPI').replaceAll('/', '_')}.pdf',
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
                            child: _KalenderPaperSheet(data: data),
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

class _KalenderPaperSheet extends StatelessWidget {
  const _KalenderPaperSheet({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final judul = pickString(data, ['judul'], 'KALENDER AKADEMIK UNIVERSITAS');
    final periode = pickString(data, ['periode', 'tahun'], 'Tahun Akademik');
    final printMeta = pickString(
      data,
      ['print_meta'],
      'Informasi bersumber dari kalender akademik resmi Universitas Putra Indonesia YPTK Padang.',
    );

    final rawKegiatan = data['kegiatan'];
    final List<Map<String, dynamic>> items = [];
    if (rawKegiatan is List) {
      for (final k in rawKegiatan) {
        if (k is Map) items.add(asMap(k));
      }
    }

    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final it in items) {
      final rawGrup = pickString(it, ['grup'], '').trim();
      final grupKey = rawGrup.isEmpty
          ? 'Kalender Akademik | Semester Ganjil'
          : rawGrup.replaceAll('Kalender Akademik UPI-YPTK | ', '');
      grouped.putIfAbsent(grupKey, () => []).add(it);
    }

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
              'https://sisfo.upiyptk.ac.id/assets/img/print-header-upi-yptk.png',
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
          const SizedBox(height: 14),

          // Judul Dokumen
          Center(
            child: Column(
              children: [
                Text(
                  judul.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: Color(0xFF263B62),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  periode,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF667085),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Tabel Kegiatan per Kelompok
          if (grouped.isNotEmpty) ...[
            for (final entry in grouped.entries) ...[
              _buildGroupSection(entry.key, entry.value),
              const SizedBox(height: 16),
            ],
          ] else ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: Text('Tidak ada agenda kegiatan yang tercatat.'),
              ),
            ),
          ],

          const SizedBox(height: 12),
          // Footer
          Center(
            child: Text(
              printMeta,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 8.5, color: Color(0xFF98A2B3)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupSection(String groupTitle, List<Map<String, dynamic>> list) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFCFD6DF)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Judul Grup
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: const BoxDecoration(
              color: Color(0xFFEEF3F9),
              borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
            ),
            child: Text(
              groupTitle.toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF263B62),
              ),
            ),
          ),

          // Header Tabel
          Container(
            color: const Color(0xFF263B62),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: const Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text('NO', style: _thStyle, textAlign: TextAlign.center),
                ),
                Expanded(
                  child: Text('KEGIATAN AKADEMIK', style: _thStyle),
                ),
                SizedBox(
                  width: 140,
                  child: Text('JADWAL / WAKTU', style: _thStyle, textAlign: TextAlign.center),
                ),
              ],
            ),
          ),

          // Rows
          for (int i = 0; i < list.length; i++)
            _buildRow(list[i], isEven: i % 2 == 0),
        ],
      ),
    );
  }

  Widget _buildRow(Map<String, dynamic> item, {required bool isEven}) {
    final no = pickString(item, ['no'], '').trim();
    final kegiatan = pickString(item, ['kegiatan'], '-');
    final jadwal = pickString(item, ['jadwal'], '-');

    final isSubItem = no.isEmpty;
    final isMajor = kegiatan.toUpperCase() == kegiatan && kegiatan.length > 5;

    return Container(
      color: isEven ? Colors.white : const Color(0xFFFAFBFC),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 32,
            child: Text(
              no.isNotEmpty ? no : '•',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: isSubItem ? const Color(0xFF98A2B3) : const Color(0xFF263B62),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: isSubItem ? 16 : 4, right: 8),
              child: Text(
                kegiatan,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: (isMajor || no.isNotEmpty) ? FontWeight.w700 : FontWeight.w500,
                  color: isMajor ? const Color(0xFF263B62) : const Color(0xFF1D2430),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 140,
            child: Text(
              jadwal,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isMajor ? FontWeight.w700 : FontWeight.w600,
                color: const Color(0xFF263B62),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const TextStyle _thStyle = TextStyle(
    color: Colors.white,
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.3,
  );
}

