import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/tagihan_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/smart.dart';
import '../widgets/common.dart';
import '../widgets/gradient_header.dart';

/// Halaman Tagihan & Pembayaran Keuangan Mahasiswa:
/// Menampilkan ringkasan invoice semester, rincian pembayaran,
/// nomor Virtual Account (BSI), riwayat transaksi, dan status per periode.
class TagihanScreen extends StatefulWidget {
  const TagihanScreen({super.key});

  @override
  State<TagihanScreen> createState() => _TagihanScreenState();
}

class _TagihanScreenState extends State<TagihanScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: context.bg,
        body: Column(
          children: [
            GradientHeader(
              title: 'Tagihan & Pembayaran',
              subtitle: 'Kelola kewajiban biaya kuliah dan virtual account',
              leading: Navigator.of(context).canPop()
                  ? const HeaderBackButton()
                  : null,
              bottom: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AppColors.amberLight,
                unselectedLabelColor: Colors.white.withValues(alpha: 0.65),
                indicatorColor: AppColors.amber,
                indicatorWeight: 3,
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
                tabs: const [
                  Tab(text: 'Daftar Tagihan'),
                  Tab(text: 'Virtual Account'),
                  Tab(text: 'Riwayat Transaksi'),
                  Tab(text: 'Status Keuangan'),
                ],
              ),
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  _TagihanTab(),
                  _VaTab(),
                  _RiwayatTab(),
                  _StatusTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================================================================== TAB 1: TAGIHAN
class _TagihanTab extends StatefulWidget {
  const _TagihanTab();

  @override
  State<_TagihanTab> createState() => _TagihanTabState();
}

class _TagihanTabState extends State<_TagihanTab>
    with AutomaticKeepAliveClientMixin {
  late Future<Map<String, dynamic>> _future;
  String _filterStatus = 'all'; // 'all', 'paid', 'unpaid'

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  Future<Map<String, dynamic>> _loadData() async {
    final srv = TagihanService(context.read<ApiClient>());
    final resp = await srv.list();
    final data = resp is Map ? (resp['data'] ?? resp) : resp;
    return asMap(data);
  }

  void _openInvoiceDetail(Map<String, dynamic> inv) {
    final token = pickString(inv, ['detail_token', 'token'], '');
    if (token.isEmpty) {
      appToast(context, 'Token invoice tidak tersedia.', error: true);
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InvoiceDetailSheet(token: token, initialInv: inv),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: LoadingView(label: 'Memuat daftar tagihan mahasiswa...'),
          );
        }
        if (snap.hasError) {
          return ErrorRetry(
            message: errorText(snap.error!),
            onRetry: () => setState(() => _future = _loadData()),
          );
        }

        final data = snap.data ?? const <String, dynamic>{};
        final mhs = asMap(data['mahasiswa']);
        final namaMhs = pickString(mhs, ['nama'], 'Mahasiswa');
        final nimMhs = pickString(mhs, ['nim'], '-');
        final prodiMhs = pickString(mhs, ['prodi'], '-');
        final statusMhs = pickString(mhs, ['status'], 'Terverifikasi');

        final summary = asMap(data['summary']);
        final bannerStats = asMap(data['banner_stats']);
        final totalNominal = pickString(
          summary,
          ['total_nominal'],
          rupiah(data['total_tagihan'] ?? 0),
        );
        final totalInvoice = pickString(data, ['total_invoice'], '0 Invoice');
        final lunasCount = pickString(bannerStats, ['lunas'], '0');
        final belumCount = pickString(bannerStats, ['belum_selesai'], '0');

        final notice = asMap(data['notice']);
        final noticeJudul = pickString(notice, ['judul'], '');
        final noticeIsi = pickString(notice, ['isi'], '');

        final rawInvoices = data['invoice'];
        final List<Map<String, dynamic>> invoices = [];
        if (rawInvoices is List) {
          for (final i in rawInvoices) {
            if (i is Map) invoices.add(asMap(i));
          }
        }

        // Terapkan filter status
        List<Map<String, dynamic>> filteredInvoices = invoices;
        if (_filterStatus == 'paid') {
          filteredInvoices = invoices.where((i) {
            final st = pickString(i, ['status', 'status_kind'], '').toLowerCase();
            return st.contains('paid') || st.contains('lunas');
          }).toList();
        } else if (_filterStatus == 'unpaid') {
          filteredInvoices = invoices.where((i) {
            final st = pickString(i, ['status', 'status_kind'], '').toLowerCase();
            return !st.contains('paid') && !st.contains('lunas');
          }).toList();
        }

        return RefreshIndicator(
          color: AppColors.upiYellowDeep,
          onRefresh: () async {
            setState(() => _future = _loadData());
            await _future;
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 96),
            children: [
              // 1. Hero Ringkasan Tagihan & Status Akun
              _buildHeroSummaryCard(
                namaMhs: namaMhs,
                nimMhs: nimMhs,
                prodiMhs: prodiMhs,
                statusMhs: statusMhs,
                totalNominal: totalNominal,
                totalInvoice: totalInvoice,
                lunasCount: lunasCount,
                belumCount: belumCount,
              ),
              const SizedBox(height: 12),

              // 2. Banner Informasi Resmi VA
              if (noticeIsi.isNotEmpty) ...[
                _buildNoticeBanner(noticeJudul, noticeIsi),
                const SizedBox(height: 12),
              ],

              // 3. Filter Chips Status
              _buildFilterChips(invoices.length, lunasCount, belumCount),
              const SizedBox(height: 12),

              // 4. Daftar Invoice
              if (filteredInvoices.isEmpty) ...[
                const SizedBox(height: 40),
                Center(
                  child: EmptyView(
                    icon: Icons.receipt_long_rounded,
                    message: _filterStatus != 'all'
                        ? 'Tidak ada invoice dengan status yang dipilih.'
                        : 'Tidak ada invoice tagihan perkuliahan.',
                  ),
                ),
                const SizedBox(height: 40),
              ] else ...[
                for (final inv in filteredInvoices) ...[
                  _buildInvoiceCard(inv),
                  const SizedBox(height: 10),
                ],
              ],

              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeroSummaryCard({
    required String namaMhs,
    required String nimMhs,
    required String prodiMhs,
    required String statusMhs,
    required String totalNominal,
    required String totalInvoice,
    required String lunasCount,
    required String belumCount,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF78350F), // Deep Warm Amber
            Color(0xFFB45309), // UPI YPTK Gold
            Color(0xFF1E293B), // Dark Navy
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.upiYellowDeep.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      namaMhs,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$nimMhs • $prodiMhs',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_rounded,
                        color: AppColors.amberLight, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      statusMhs,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.amberLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Colors.white24),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOTAL TAGIHAN MAHASISWA',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    totalNominal,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  _buildMiniStat('Lunas', lunasCount, Colors.white, AppColors.green),
                  const SizedBox(width: 8),
                  _buildMiniStat('Perlu Selesai', belumCount, Colors.white, AppColors.orange),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String count, Color textColor, Color dotColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            '$count $label',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeBanner(String title, String content) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              color: AppColors.upiYellowDeep, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty) ...[
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF92400E),
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF78350F),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(int total, String lunasCount, String belumCount) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildChip('all', 'Semua Invoice ($total)'),
          const SizedBox(width: 8),
          _buildChip('paid', 'Lunas ($lunasCount)'),
          const SizedBox(width: 8),
          _buildChip('unpaid', 'Belum Lunas ($belumCount)'),
        ],
      ),
    );
  }

  Widget _buildChip(String key, String label) {
    final isSelected = _filterStatus == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _filterStatus = key),
      selectedColor: AppColors.upiYellowDeep.withValues(alpha: 0.18),
      labelStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? AppColors.upiYellowDeep : const Color(0xFF475569),
      ),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? AppColors.upiYellowDeep : const Color(0xFFE2E8F0),
        ),
      ),
      showCheckmark: false,
    );
  }

  Widget _buildInvoiceCard(Map<String, dynamic> inv) {
    final komponen = pickString(inv, ['komponen', 'nama_tagihan'], 'Biaya Kuliah');
    final periodeLabel = pickString(inv, ['periode_label', 'periode'], 'Periode');
    final invoiceId = pickString(inv, ['invoice_id'], '-');
    final nominal = pickString(inv, ['nominal'], 'Rp -');
    final jatuhTempo = pickString(inv, ['jatuh_tempo'], '-');
    final terbit = pickString(inv, ['terbit'], '');
    final status = pickString(inv, ['status'], 'Paid');
    final isPaid = status.toLowerCase() == 'paid' || status.toLowerCase() == 'lunas';

    return SurfaceCard(
      onTap: () => _openInvoiceDetail(inv),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isPaid
                      ? AppColors.green.withValues(alpha: 0.12)
                      : AppColors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isPaid ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                  color: isPaid ? AppColors.green : AppColors.orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      komponen,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      periodeLabel,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.upiYellowDeep,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isPaid
                      ? AppColors.green.withValues(alpha: 0.10)
                      : AppColors.red.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isPaid
                        ? AppColors.green.withValues(alpha: 0.3)
                        : AppColors.red.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  isPaid ? 'Lunas' : 'Belum Lunas',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isPaid ? AppColors.green : AppColors.red,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // Nominal & Tanggal
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nominal Tagihan',
                    style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    nominal,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    terbit.isNotEmpty ? terbit : 'Jatuh Tempo: $jatuhTempo',
                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    invoiceId,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Detail CTA
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Lihat Rincian & VA',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: context.primary,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward_rounded, size: 14, color: context.primary),
            ],
          ),
        ],
      ),
    );
  }
}

// ==================================================================== INVOICE DETAIL SHEET
class _InvoiceDetailSheet extends StatefulWidget {
  const _InvoiceDetailSheet({required this.token, required this.initialInv});

  final String token;
  final Map<String, dynamic> initialInv;

  @override
  State<_InvoiceDetailSheet> createState() => _InvoiceDetailSheetState();
}

class _InvoiceDetailSheetState extends State<_InvoiceDetailSheet> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadDetail();
  }

  Future<Map<String, dynamic>> _loadDetail() async {
    final srv = TagihanService(context.read<ApiClient>());
    final resp = await srv.invoice(widget.token);
    final data = resp is Map ? (resp['data'] ?? resp) : resp;
    return asMap(data);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.50,
      maxChildSize: 0.95,
      builder: (ctx, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: FutureBuilder<Map<String, dynamic>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: LoadingView(label: 'Memuat rincian invoice...'),
                );
              }
              if (snap.hasError) {
                return Center(
                  child: ErrorRetry(
                    message: 'Gagal memuat detail invoice: ${snap.error}',
                    onRetry: () => setState(() => _future = _loadDetail()),
                  ),
                );
              }

              final d = snap.data ?? widget.initialInv;
              final invoiceId = pickString(d, ['invoice_id'], '-');
              final namaTagihan = pickString(
                d,
                ['nama_tagihan', 'komponen'],
                'Biaya Kuliah Per Semester',
              );
              final totalPembayaran = pickString(
                d,
                ['total_pembayaran', 'total_tagihan', 'nominal'],
                'Rp -',
              );
              final bank = pickString(d, ['bank'], 'BSI');
              final va = pickString(d, ['virtual_account'], '-');
              final kodeBayar = pickString(d, ['kode_pembayaran'], '12');
              final idTransaksi = pickString(d, ['id_transaksi'], '-');
              final referensi = pickString(d, ['referensi'], '-');
              final periode = pickString(d, ['periode', 'tahun_akademik'], '-');
              final semester = pickString(d, ['semester'], '-');
              final jatuhTempo = pickString(d, ['jatuh_tempo'], '-');
              final tglTerbit = pickString(d, ['tanggal_terbit', 'terbit'], '-');

              final statusHero = asMap(d['status_hero']);
              final badgeHero = pickString(statusHero, ['badge'], 'Lunas');
              final judulHero = pickString(
                statusHero,
                ['judul'],
                'Pembayaran Terverifikasi',
              );
              final pesanHero = pickString(
                statusHero,
                ['pesan'],
                'Pembayaran Berhasil',
              );

              final mhs = asMap(d['mahasiswa']);
              final mhsNama = pickString(mhs, ['nama'], '-');
              final mhsNim = pickString(mhs, ['nim'], '-');
              final mhsProdi = pickString(mhs, ['prodi'], '-');
              final mhsFakultas = pickString(mhs, ['fakultas'], '-');
              final mhsHp = pickString(mhs, ['handphone'], '-');
              final mhsEmail = pickString(mhs, ['email'], '-');

              return ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 44,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Header Judul Sheet
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Lembar Rincian Invoice',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            invoiceId,
                            style: const TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Hero Status Box
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: AppColors.green,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_rounded,
                              color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    judulHero,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF166534),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: AppColors.green,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      badgeHero,
                                      style: const TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                pesanHero,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF15803D),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Virtual Account Box (BSI)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E293B), Color(0xFF334155)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'VIRTUAL ACCOUNT ($bank)',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: AppColors.amberLight,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Kode: $kodeBayar',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                va,
                                style: const TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                  fontFamily: 'monospace',
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            IconButton.filled(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: va));
                                appToast(ctx, 'Nomor VA berhasil disalin.');
                              },
                              style: IconButton.styleFrom(
                                backgroundColor: AppColors.upiYellowDeep,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.copy_rounded, size: 16),
                              tooltip: 'Salin Nomor VA',
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'ID Transaksi: $idTransaksi',
                          style: TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                            color: Colors.white.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Data Tagihan & Transaksi
                  _buildSectionBox(
                    title: 'Rincian Tagihan',
                    icon: Icons.receipt_rounded,
                    children: [
                      _buildRowItem('Komponen', namaTagihan),
                      _buildRowItem('Total Pembayaran', totalPembayaran, isBoldValue: true, highlight: true),
                      _buildRowItem('Periode / Semester', '$periode ($semester)'),
                      _buildRowItem('Nomor Referensi', referensi),
                      _buildRowItem('Tanggal Terbit', tglTerbit),
                      _buildRowItem('Jatuh Tempo', jatuhTempo),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Data Mahasiswa
                  _buildSectionBox(
                    title: 'Identitas Mahasiswa',
                    icon: Icons.person_rounded,
                    children: [
                      _buildRowItem('Nama', mhsNama),
                      _buildRowItem('NIM / No. BP', mhsNim),
                      _buildRowItem('Program Studi', mhsProdi),
                      _buildRowItem('Fakultas', mhsFakultas),
                      if (mhsHp.isNotEmpty && mhsHp != '-') _buildRowItem('No. HP', mhsHp),
                      if (mhsEmail.isNotEmpty && mhsEmail != '-') _buildRowItem('Email', mhsEmail),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Footer Validasi
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.shield_outlined, size: 15, color: Color(0xFF64748B)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Data pembayaran resmi bersumber dari sistem Billing UPI YPTK Padang.',
                            style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSectionBox({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: AppColors.upiYellowDeep),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }

  Widget _buildRowItem(
    String label,
    String value, {
    bool isBoldValue = false,
    bool highlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ),
          const Text(': ', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isBoldValue ? FontWeight.w900 : FontWeight.w600,
                color: highlight ? AppColors.upiYellowDeep : const Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================================================================== TAB 2: VIRTUAL ACCOUNT
class _VaTab extends StatefulWidget {
  const _VaTab();

  @override
  State<_VaTab> createState() => _VaTabState();
}

class _VaTabState extends State<_VaTab> with AutomaticKeepAliveClientMixin {
  late Future<Map<String, dynamic>> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = _loadVa();
  }

  Future<Map<String, dynamic>> _loadVa() async {
    final srv = TagihanService(context.read<ApiClient>());
    final resp = await srv.virtualAccount();
    final data = resp is Map ? (resp['data'] ?? resp) : resp;
    return asMap(data);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: LoadingView(label: 'Memuat informasi Virtual Account...'),
          );
        }
        if (snap.hasError) {
          return ErrorRetry(
            message: errorText(snap.error!),
            onRetry: () => setState(() => _future = _loadVa()),
          );
        }

        final data = snap.data ?? const <String, dynamic>{};
        final catatan = pickString(
          data,
          ['catatan'],
          'Gunakan nomor VA yang tertera pada invoice untuk pembayaran melalui Mobile Banking, ATM, atau Teller.',
        );
        final mhs = asMap(data['mahasiswa']);
        final mhsNama = pickString(mhs, ['nama'], 'Mahasiswa');
        final mhsInfo = pickString(mhs, ['info'], '-');

        return RefreshIndicator(
          color: AppColors.upiYellowDeep,
          onRefresh: () async {
            setState(() => _future = _loadVa());
            await _future;
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            children: [
              // Card Mahasiswa & Petunjuk Utama
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.upiYellowDeep.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.credit_card_rounded,
                              color: AppColors.amberLight, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mhsNama,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                mhsInfo,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.75),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: Colors.white12),
                    const SizedBox(height: 12),
                    Text(
                      catatan,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.amberLight,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Panduan Pembayaran VA
              _buildPanduanCard(),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPanduanCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.help_outline_rounded,
                  size: 16, color: AppColors.upiYellowDeep),
              SizedBox(width: 6),
              Text(
                'Panduan Pembayaran Virtual Account',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          _buildStepItem(
            '1',
            'Buka Aplikasi Mobile Banking (BSI Mobile / Bank Lain)',
            'Pilih menu Pembayaran / Bayar Tagihan > Akademik / Institusi.',
          ),
          _buildStepItem(
            '2',
            'Masukkan Kode Institusi atau Nomor Virtual Account',
            'Input nomor VA yang tercantum pada rincian invoice tagihan semester.',
          ),
          _buildStepItem(
            '3',
            'Periksa Nama Mahasiswa & Nominal Tagihan',
            'Pastikan data yang muncul sesuai dengan nama Anda dan nominal biaya kuliah.',
          ),
          _buildStepItem(
            '4',
            'Konfirmasi & Simpan Bukti Transaksi',
            'Selesaikan transaksi. Status pembayaran akan otomatis terverifikasi di sistem SIAKAD.',
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem(String step, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.upiYellowDeep.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              step,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: AppColors.upiYellowDeep,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==================================================================== TAB 3: RIWAYAT TRANSAKSI
class _RiwayatTab extends StatefulWidget {
  const _RiwayatTab();

  @override
  State<_RiwayatTab> createState() => _RiwayatTabState();
}

class _RiwayatTabState extends State<_RiwayatTab>
    with AutomaticKeepAliveClientMixin {
  late Future<Map<String, dynamic>> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = _loadRiwayat();
  }

  Future<Map<String, dynamic>> _loadRiwayat() async {
    final srv = TagihanService(context.read<ApiClient>());
    final resp = await srv.riwayat();
    final data = resp is Map ? (resp['data'] ?? resp) : resp;
    return asMap(data);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: LoadingView(label: 'Memuat riwayat transaksi pembayaran...'),
          );
        }
        if (snap.hasError) {
          return ErrorRetry(
            message: errorText(snap.error!),
            onRetry: () => setState(() => _future = _loadRiwayat()),
          );
        }

        final data = snap.data ?? const <String, dynamic>{};
        final rawRiwayat = data['riwayat'];
        final List<Map<String, dynamic>> items = [];

        if (rawRiwayat is List) {
          for (final item in rawRiwayat) {
            if (item is Map) {
              final m = asMap(item);
              final kolom = m['kolom'];
              if (kolom is List && kolom.length >= 6) {
                items.add({
                  'invoice_info': kolom[0].toString(),
                  'komponen': kolom[1].toString(),
                  'periode': kolom[2].toString(),
                  'nominal': kolom[3].toString(),
                  'jatuh_tempo': kolom[4].toString(),
                  'status': kolom[5].toString(),
                });
              } else {
                items.add(m);
              }
            }
          }
        }

        if (items.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              SizedBox(height: 60),
              Center(
                child: EmptyView(
                  icon: Icons.history_rounded,
                  message: 'Belum ada riwayat transaksi pembayaran.',
                ),
              ),
            ],
          );
        }

        return RefreshIndicator(
          color: AppColors.upiYellowDeep,
          onRefresh: () async {
            setState(() => _future = _loadRiwayat());
            await _future;
          },
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            itemCount: items.length,
            itemBuilder: (ctx, idx) {
              final it = items[idx];
              final komponen = pickString(it, ['komponen'], 'Biaya Kuliah');
              final periode = pickString(it, ['periode'], '-');
              final nominal = pickString(it, ['nominal'], 'Rp -');
              final invoiceInfo = pickString(it, ['invoice_info'], '-');
              final status = pickString(it, ['status'], 'Paid');
              final isPaid = status.toLowerCase() == 'paid' || status.toLowerCase() == 'lunas';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.check_circle_rounded,
                          color: AppColors.green, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            komponen,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            periode,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.upiYellowDeep,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            invoiceInfo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              fontFamily: 'monospace',
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          nominal,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isPaid
                                ? AppColors.green.withValues(alpha: 0.10)
                                : AppColors.red.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isPaid ? 'Lunas' : status,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isPaid ? AppColors.green : AppColors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ==================================================================== TAB 4: STATUS KEUANGAN
class _StatusTab extends StatefulWidget {
  const _StatusTab();

  @override
  State<_StatusTab> createState() => _StatusTabState();
}

class _StatusTabState extends State<_StatusTab>
    with AutomaticKeepAliveClientMixin {
  late Future<Map<String, dynamic>> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = _loadStatus();
  }

  Future<Map<String, dynamic>> _loadStatus() async {
    final srv = TagihanService(context.read<ApiClient>());
    final resp = await srv.status();
    final data = resp is Map ? (resp['data'] ?? resp) : resp;
    return asMap(data);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: LoadingView(label: 'Memuat status keuangan...'),
          );
        }
        if (snap.hasError) {
          return ErrorRetry(
            message: errorText(snap.error!),
            onRetry: () => setState(() => _future = _loadStatus()),
          );
        }

        final data = snap.data ?? const <String, dynamic>{};
        final summary = asMap(data['summary']);
        final totalInv = pickString(summary, ['Total Invoice'], '0');
        final paid = pickString(summary, ['Paid'], '0');
        final unpaid = pickString(summary, ['Unpaid'], '0');
        final partial = pickString(summary, ['Partial'], '0');

        final rawList = data['status_per_periode'];
        final List<Map<String, dynamic>> statusList = [];
        if (rawList is List) {
          for (final s in rawList) {
            if (s is Map) statusList.add(asMap(s));
          }
        }

        return RefreshIndicator(
          color: AppColors.upiYellowDeep,
          onRefresh: () async {
            setState(() => _future = _loadStatus());
            await _future;
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            children: [
              // 4 Stat Box Summary
              Row(
                children: [
                  Expanded(child: _buildMetricCard('Total Invoice', totalInv, Icons.receipt_rounded, AppColors.blue)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildMetricCard('Lunas (Paid)', paid, Icons.check_circle_rounded, AppColors.green)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildMetricCard('Belum Lunas', unpaid, Icons.error_outline_rounded, AppColors.red)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildMetricCard('Parsial', partial, Icons.timelapse_rounded, AppColors.orange)),
                ],
              ),
              const SizedBox(height: 16),

              const Text(
                'Status Keuangan per Periode',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 10),

              if (statusList.isEmpty) ...[
                const SizedBox(height: 40),
                const Center(
                  child: EmptyView(
                    icon: Icons.check_circle_outline_rounded,
                    message: 'Tidak ada catatan tunggakan atau status pending.',
                  ),
                ),
              ] else ...[
                for (final st in statusList) ...[
                  _buildPeriodStatusCard(st),
                  const SizedBox(height: 10),
                ],
              ],

              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricCard(String label, String val, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(
            val,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodStatusCard(Map<String, dynamic> st) {
    final status = pickString(st, ['status'], 'Biaya Kuliah Per Semester');
    final periodeInfo = pickString(st, ['periode'], '-');
    final keterangan = pickString(st, ['keterangan'], '-');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                keterangan,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Lunas',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.green,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            status,
            style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 4),
          Text(
            periodeInfo,
            style: const TextStyle(
              fontSize: 10.5,
              fontFamily: 'monospace',
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}
