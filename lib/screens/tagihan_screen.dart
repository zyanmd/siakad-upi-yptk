import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/tagihan_service.dart';
import '../state/auth_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/smart.dart';
import '../widgets/common.dart';

const _yellowHeaderGradient = [
  Color(0xFFE5A620), // Bright Academic Gold
  Color(0xFFD48B08), // UPI Yellow
  Color(0xFFB87500), // Deep Academic Gold
];

/// Halaman Tagihan & Pembayaran Keuangan Mahasiswa:
/// Menampilkan ringkasan invoice semester, rincian pembayaran,
/// nomor Virtual Account (BSI), riwayat transaksi, dan status per periode.
class TagihanScreen extends StatefulWidget {
  const TagihanScreen({super.key});

  @override
  State<TagihanScreen> createState() => _TagihanScreenState();
}

class _TagihanScreenState extends State<TagihanScreen> {
  int _refreshKey = 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = context.isDark;
    final bg = isDark ? const Color(0xFF000000) : const Color(0xFFF9FAFB);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: bg,
        body: Column(
          children: [
            // ──── HEADER KUNING DENGAN LEKUKAN BERSAMBUNG & FLOATING PILL TABS ────
            Stack(
              alignment: Alignment.bottomCenter,
              clipBehavior: Clip.none,
              children: [
                _buildCurvedYellowHeader(auth.nama, auth.nim),
                Positioned(
                  bottom: -18,
                  left: 0,
                  right: 0,
                  child: _buildPillTabBar(context, isDark),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Expanded(
              child: ResponsiveCenter(
                child: TabBarView(
                  key: ValueKey(_refreshKey),
                  children: const [
                    _TagihanTab(),
                    _VaTab(),
                    _RiwayatTab(),
                    _StatusTab(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────── HEADER KUNING DENGAN LEKUKAN BERSAMBUNG
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
            padding: const EdgeInsets.fromLTRB(22, 12, 22, kCurvedHeaderBottomPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Baris Atas: Judul Halaman dan Tombol Aksi
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (canPop) ...[
                          IconButton(
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              Navigator.of(context).maybePop();
                            },
                            icon: const Icon(Icons.arrow_back_rounded,
                                color: Colors.white, size: 24),
                            tooltip: 'Kembali',
                            splashRadius: 20,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 8),
                        ],
                        const Text(
                          'Keuangan & Tagihan',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ],
                    ),
                    // Tombol Refresh data tagihan
                    IosBounceTap(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _refreshKey++);
                        appToast(context, 'Memuat ulang data keuangan...');
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.10),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
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
                const SizedBox(height: 16),

                // Baris Profil: Lingkaran Icon (54x54) + Nama & NIM Mahasiswa
                Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.85),
                          width: 1.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 27,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Teks Nama Mahasiswa & Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nama.isNotEmpty ? nama : 'Mahasiswa UPI YPTK',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                nim.isNotEmpty ? nim : 'Administrasi Keuangan',
                                style: const TextStyle(
                                  color: Color(0xE6FFFFFF),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'BSI VA',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
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

  // ────────────────────────────────────────────────── FLOATING PILL TAB BAR
  //  Disamakan dengan gaya Pill Tabs pada Dashboard (patokan):
  //  container putih/abu rounded 30, tab aktif memakai gradien kuning UPI.
  Widget _buildPillTabBar(BuildContext context, bool isDark) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.30)
                  : Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.center,
          padding: EdgeInsets.zero,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: const BoxDecoration(
            gradient: LinearGradient(
              colors: _yellowHeaderGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.all(Radius.circular(26)),
          ),
          labelColor: Colors.white,
          unselectedLabelColor:
              isDark ? const Color(0xFF98989F) : const Color(0xFF6B7280),
          dividerColor: Colors.transparent,
          labelStyle: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
          tabs: const [
            Tab(text: 'Daftar Tagihan'),
            Tab(text: 'Virtual Account'),
            Tab(text: 'Riwayat Transaksi'),
            Tab(text: 'Status Keuangan'),
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

  // Kartu ringkasan bergaya bersih seperti Dashboard: putih, rounded 16, shadow halus.
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
    final isDark = context.isDark;

    // Kartu mengikuti tema seperti kartu Virtual Account: putih saat terang, gelap saat gelap.
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.30)
                : Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sub-header Institusi Kampus
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: context.softFill,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.border, width: 0.6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.account_balance_rounded,
                        size: 13, color: context.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      'UPI YPTK PADANG',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: context.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 16),

          // Nama & NIM Mahasiswa
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.upiYellowDeep.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.school_rounded,
                    color: AppColors.upiYellowDeep, size: 24),
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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'NIM: $nimMhs • $prodiMhs',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: context.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: context.border),
          const SizedBox(height: 14),

          // Total Tagihan & Metrik Lunas
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TOTAL KEWAJIBAN BIAYA KULIAH',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: context.textMuted,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_rounded,
                            color: AppColors.green, size: 11),
                        const SizedBox(width: 4),
                        Text(
                          statusMhs,
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                totalNominal,
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildMiniStat('Lunas', lunasCount, AppColors.green),
                  _buildMiniStat('Belum Selesai', belumCount, AppColors.orange),
                  if (totalInvoice.isNotEmpty)
                    _buildMiniStat('Total', totalInvoice, AppColors.upiYellowDeep),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$count $label',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeBanner(String title, String content) {
    final isDark = context.isDark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.30)
                : Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.upiYellowDeep.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.info_outline_rounded,
                color: AppColors.upiYellowDeep, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty) ...[
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: context.primaryContrast,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: context.textPrimary,
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
          _buildChip('all', 'Semua ($total)'),
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
    final isDark = context.isDark;

    return IosBounceTap(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _filterStatus = key);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF2C2C30) : AppColors.primaryYellow)
              : context.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? (isDark
                    ? AppColors.primaryYellow.withValues(alpha: 0.5)
                    : AppColors.upiYellowDeep)
                : context.border,
            width: isSelected ? 1.0 : 0.6,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? (isDark
                      ? Colors.black.withValues(alpha: 0.35)
                      : AppColors.primaryYellow.withValues(alpha: 0.30))
                  : Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
              blurRadius: isSelected ? 6 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected
                ? (isDark ? Colors.white : const Color(0xFF1C1917))
                : context.textMuted,
          ),
        ),
      ),
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
    final isDark = context.isDark;

    return IosBounceTap(
      onTap: () => _openInvoiceDetail(inv),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.30)
                  : Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: isPaid
                        ? AppColors.green.withValues(alpha: 0.14)
                        : AppColors.upiYellowDeep.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isPaid ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                    color: isPaid ? AppColors.green : AppColors.upiYellowDeep,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        komponen,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: context.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryYellow.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          periodeLabel,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.upiYellowDeep,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: isPaid
                        ? AppColors.green.withValues(alpha: 0.12)
                        : AppColors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isPaid
                          ? AppColors.green.withValues(alpha: 0.4)
                          : AppColors.red.withValues(alpha: 0.4),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    isPaid ? 'Lunas' : 'Belum Lunas',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: isPaid ? AppColors.green : AppColors.red,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: context.border),
            const SizedBox(height: 10),

            // Nominal & Tanggal
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nominal Tagihan',
                      style: TextStyle(fontSize: 10.5, color: context.textMuted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      nominal,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                        color: context.textPrimary,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today_rounded,
                            size: 11, color: context.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          terbit.isNotEmpty ? terbit : 'Tempo: $jatuhTempo',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: context.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      invoiceId,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        color: context.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Detail CTA
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Lihat Rincian & VA',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: context.primaryContrast,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward_rounded,
                    size: 14, color: context.primaryContrast),
              ],
            ),
          ],
        ),
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
        final isPaidInitial = pickString(widget.initialInv, ['status'], '').toLowerCase() == 'paid' ||
            pickString(widget.initialInv, ['status'], '').toLowerCase() == 'lunas';

        return Container(
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: context.border, width: 0.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: context.isDark ? 0.45 : 0.12),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
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
              final badgeHero = pickString(statusHero, ['badge'], isPaidInitial ? 'Lunas' : 'Belum Lunas');
              final judulHero = pickString(
                statusHero,
                ['judul'],
                isPaidInitial ? 'Pembayaran Terverifikasi' : 'Menunggu Pembayaran',
              );
              final pesanHero = pickString(
                statusHero,
                ['pesan'],
                isPaidInitial ? 'Pembayaran Berhasil' : 'Silakan selesaikan pembayaran sebelum jatuh tempo.',
              );

              final isPaid = badgeHero.toLowerCase().contains('lunas') ||
                  badgeHero.toLowerCase().contains('paid') ||
                  judulHero.toLowerCase().contains('terverifikasi') ||
                  judulHero.toLowerCase().contains('berhasil');

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
                      width: 42,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: context.isDark ? Colors.white24 : Colors.black12,
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
                          Text(
                            'Lembar Rincian Invoice',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: context.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            invoiceId,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                              color: context.textMuted,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: IconButton.styleFrom(
                          backgroundColor: context.softFill,
                          padding: const EdgeInsets.all(8),
                          minimumSize: const Size(36, 36),
                        ),
                        icon: Icon(Icons.close_rounded, size: 18, color: context.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Hero Status Box
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isPaid
                          ? AppColors.green.withValues(alpha: 0.12)
                          : AppColors.red.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isPaid
                            ? AppColors.green.withValues(alpha: 0.3)
                            : AppColors.red.withValues(alpha: 0.3),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isPaid ? AppColors.green : AppColors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isPaid ? Icons.check_rounded : Icons.pending_actions_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
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
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      color: isPaid ? AppColors.green : AppColors.red,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isPaid ? AppColors.green : AppColors.red,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      badgeHero,
                                      style: const TextStyle(
                                        fontSize: 10,
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
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: context.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Virtual Account Box (BSI) Modern - gaya putih bersih seperti Dashboard
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.isDark
                          ? const Color(0xFF1C1C1E)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                              alpha: context.isDark ? 0.30 : 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: AppColors.upiYellowDeep
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: const Icon(Icons.account_balance_rounded,
                                      color: AppColors.upiYellowDeep, size: 16),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'VIRTUAL ACCOUNT',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                    color: AppColors.upiYellowDeep,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: AppColors.upiYellowDeep
                                    .withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$bank • Kode: $kodeBayar',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.upiYellowDeep,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                va,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                  fontFamily: 'monospace',
                                  color: context.textPrimary,
                                ),
                              ),
                            ),
                            IosBounceTap(
                              onTap: () {
                                copyText(context, va);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: _yellowHeaderGradient,
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.copy_rounded,
                                        size: 14, color: Colors.white),
                                    SizedBox(width: 4),
                                    Text(
                                      'Salin',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Divider(height: 1, color: context.border),
                        const SizedBox(height: 8),
                        Text(
                          'ID Transaksi: $idTransaksi',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontFamily: 'monospace',
                            color: context.textMuted,
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
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: context.softFill,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: context.border, width: 0.6),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.shield_outlined, size: 16, color: context.primaryContrast),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Data pembayaran resmi bersumber dari sistem Billing UPI YPTK Padang.',
                            style: TextStyle(fontSize: 10.5, color: context.textMuted),
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
        color: context.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.30 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.upiYellowDeep.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 15, color: AppColors.upiYellowDeep),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: context.border),
          const SizedBox(height: 8),
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
      padding: const EdgeInsets.symmetric(vertical: 4.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: context.textMuted),
          ),
          const SizedBox(width: 14),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12,
                fontWeight: (isBoldValue || highlight)
                    ? FontWeight.w800
                    : FontWeight.w600,
                color: highlight ? context.primaryContrast : context.textPrimary,
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
        final rawVaList = data['va_list'];
        final List<Map<String, dynamic>> vaList = [];
        if (rawVaList is List) {
          for (final item in rawVaList) {
            if (item is Map) vaList.add(asMap(item));
          }
        }

        return RefreshIndicator(
          color: AppColors.upiYellowDeep,
          onRefresh: () async {
            setState(() => _future = _loadVa());
            await _future;
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            children: [
              // Kartu BSI Virtual Account Utama
              if (vaList.isNotEmpty) ...[
                for (final v in vaList) ...[
                  _buildBsiCard(
                    bank: pickString(v, ['bank'], 'Bank Syariah Indonesia (BSI)'),
                    vaNumber: pickString(v, ['nomor', 'va'], '-'),
                    nama: pickString(v, ['nama'], mhsNama),
                    nominal: pickString(v, ['nominal'], ''),
                    status: pickString(v, ['status'], ''),
                  ),
                  const SizedBox(height: 14),
                ],
              ] else ...[
                _buildBsiCard(
                  bank: 'Bank Syariah Indonesia (BSI)',
                  vaNumber: '12${pickString(mhs, ['nim'], '')}',
                  nama: mhsNama,
                  nominal: null,
                  status: 'Aktif',
                ),
                const SizedBox(height: 14),
              ],

              // Card Mahasiswa & Petunjuk Utama
              SurfaceCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.amber, AppColors.upiYellowDeep],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.upiYellowDeep.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.badge_rounded,
                              color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mhsNama,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: context.textPrimary,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                mhsInfo,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Divider(height: 1, color: context.border),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.softFill,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.border, width: 0.6),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded,
                              size: 16, color: context.primaryContrast),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              catatan,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: context.textPrimary,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
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

  // Kartu Virtual Account bergaya bersih seperti Dashboard: putih, rounded 16, shadow halus.
  Widget _buildBsiCard({
    required String bank,
    required String vaNumber,
    required String nama,
    String? nominal,
    String? status,
  }) {
    final isDark = context.isDark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.30)
                : Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Header Bank + Chip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.upiYellowDeep.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.account_balance_rounded,
                      size: 18,
                      color: AppColors.upiYellowDeep,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    bank.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      color: AppColors.upiYellowDeep,
                    ),
                  ),
                ],
              ),
              // EMV Chip
              Container(
                width: 32,
                height: 22,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFFDF73),
                      Color(0xFFD4AF37),
                      Color(0xFFA67C1E),
                    ],
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 18,
                    height: 12,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.3),
                        width: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Row 2: Nomor Virtual Account Monospace + Salin Button
          Text(
            'NOMOR VIRTUAL ACCOUNT',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: context.textMuted,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: Text(
                  vaNumber,
                  style: TextStyle(
                    fontSize: 20,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.8,
                    color: context.textPrimary,
                  ),
                ),
              ),
              IosBounceTap(
                onTap: () {
                  copyText(context, vaNumber, 'Nomor VA berhasil disalin!');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: _yellowHeaderGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.copy_rounded, size: 12, color: Colors.white),
                      SizedBox(width: 5),
                      Text(
                        'Salin',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: context.border),
          const SizedBox(height: 12),

          // Row 3: Nama Mahasiswa & Kode Institusi
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ATAS NAMA',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: context.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      nama.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                        color: context.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.upiYellowDeep.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Kode: 12 (UPI YPTK)',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.upiYellowDeep,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPanduanCard() {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.30 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline_rounded,
                  size: 16, color: context.primaryContrast),
              const SizedBox(width: 8),
              Text(
                'Panduan Pembayaran Virtual Account',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: context.border),
          const SizedBox(height: 12),

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
              color: AppColors.primaryYellow.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Text(
              step,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: context.primaryContrast,
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
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.textMuted,
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
              final isDark = context.isDark;

              return IosBounceTap(
                onTap: () {
                  copyText(context, '$komponen: $nominal ($invoiceInfo)', 'Data transaksi disalin');
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(16),
                    border: isDark
                        ? Border.all(
                            color: AppColors.green.withValues(alpha: 0.25),
                            width: 0.8,
                          )
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.30)
                            : Colors.black.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: AppColors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.check_circle_rounded,
                            color: AppColors.green, size: 22),
                      ),
                      const SizedBox(width: 12),
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
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: AppColors.primaryYellow.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                periode,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.upiYellowDeep,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              invoiceInfo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontFamily: 'monospace',
                                color: context.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            nominal,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                              color: context.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: isPaid
                                  ? AppColors.green.withValues(alpha: 0.12)
                                  : AppColors.red.withValues(alpha: 0.12),
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

              Text(
                'Status Keuangan per Periode',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
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
    final isDark = context.isDark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.30)
                : color.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 6),
          Text(
            val,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: context.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodStatusCard(Map<String, dynamic> st) {
    final status = pickString(st, ['status'], 'Biaya Kuliah Per Semester');
    final periodeInfo = pickString(st, ['periode'], '-');
    final keterangan = pickString(st, ['keterangan'], '-');
    final isDark = context.isDark;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.green.withValues(alpha: 0.25),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.30)
                : Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  keterangan,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.green.withValues(alpha: 0.4),
                    width: 0.8,
                  ),
                ),
                child: const Text(
                  'Lunas',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.green,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            status,
            style: TextStyle(fontSize: 12, color: context.textMuted),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 12, color: AppColors.upiYellowDeep),
              const SizedBox(width: 5),
              Text(
                periodeInfo,
                style: TextStyle(
                  fontSize: 10.5,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                  color: context.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
