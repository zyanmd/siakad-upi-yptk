import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/smart.dart';
import '../widgets/common.dart';
import '../widgets/gradient_header.dart';
import '../widgets/smart_detail_page.dart';
import '../widgets/smart_json.dart';

/// Tagihan & pembayaran: daftar invoice, virtual account,
/// riwayat pembayaran, dan status.
class TagihanScreen extends StatelessWidget {
  const TagihanScreen({super.key});

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
              subtitle: 'Kelola keuangan kuliah Anda',
              leading:
                  Navigator.of(context).canPop() ? const HeaderBackButton() : null,
              bottom: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AppColors.amberLight,
                unselectedLabelColor: Colors.white.withOpacity(0.65),
                indicatorColor: AppColors.amber,
                indicatorWeight: 3,
                dividerColor: Colors.transparent,
                labelStyle:
                    const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                tabs: const [
                  Tab(text: 'Tagihan'),
                  Tab(text: 'Virtual Account'),
                  Tab(text: 'Riwayat'),
                  Tab(text: 'Status'),
                ],
              ),
            ),
            Expanded(
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

// ==================================================================== tab 1

class _TagihanTab extends StatefulWidget {
  @override
  State<_TagihanTab> createState() => _TagihanTabState();
}

class _TagihanTabState extends State<_TagihanTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Future<Map<String, dynamic>> _load() async {
    final api = context.read<ApiClient>();
    final resp = await api.get('/api/tagihan');
    final data = resp is Map ? (resp['data'] ?? resp) : resp;
    return asMap(data);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<Map<String, dynamic>>(
      future: _load(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const LoadingView();
        }
        if (snap.hasError) {
          return ErrorRetry(
              message: errorText(snap.error!),
              onRetry: () => setState(() {}));
        }
        final data = snap.data ?? const <String, dynamic>{};
        final invoices = deepFindMapList(
            data, ['invoice', 'invoices', 'daftar_invoice', 'list']);
        final total =
            deepFind(data, ['total_invoice', 'total', 'total_tagihan']);
        final nama = pickString(
            asMap(data['mahasiswa']),
            ['nama', 'nama_mahasiswa', 'name'],
            '');

        return RefreshIndicator(
          color: AppColors.indigo700,
          onRefresh: () async => setState(() {}),
          child: ListView(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SurfaceCard(
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.amber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(Icons.account_balance_wallet_rounded,
                          size: 23, color: AppColors.orange),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            total != null ? rupiah(total) : 'Rp -',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              color: context.textPrimary,
                            ),
                          ),
                          Text(
                            nama.isNotEmpty
                                ? 'Total tagihan - $nama'
                                : 'Total tagihan saat ini',
                            style: TextStyle(
                                fontSize: 11.5, color: context.textMuted),
                          ),
                        ],
                      ),
                    ),
                    if (data['banner_stats'] != null)
                      const Icon(Icons.arrow_outward_rounded,
                          size: 18, color: AppColors.indigo300),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (invoices.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: EmptyView(
                      icon: Icons.receipt_outlined,
                      message: 'Tidak ada invoice tagihan.'),
                )
              else ...[
                SectionTitle('Invoice (${invoices.length})'),
                const SizedBox(height: 10),
                for (final inv in invoices) ...[
                  _InvoiceCard(
                    inv: inv,
                    onTap: () {
                      final token = pickString(
                          inv, ['detail_token', 'token'], '');
                      if (token.isEmpty) return;
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => SmartDetailPage(
                          title: 'Detail Invoice',
                          load: () => context
                              .read<ApiClient>()
                              .get('/api/tagihan/invoice/$token'),
                        ),
                      ));
                    },
                  ),
                  const SizedBox(height: 9),
                ],
              ],
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.inv, this.onTap});
  final Map<String, dynamic> inv;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final komponen = pickString(
        inv, ['komponen', 'nama', 'judul', 'jenis'], 'Invoice');
    final periodeLabel =
        pickString(inv, ['periode_label', 'periode'], '');
    final nominal = inv['nominal'];
    final jatuhTempo = pickString(inv, ['jatuh_tempo', 'tempo'], '');
    final status = pickString(inv, ['status'], '');
    final statusKind = pickString(inv, ['status_kind'], '');
    final terbit = pickString(inv, ['terbit'], '');

    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  komponen,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (periodeLabel.isNotEmpty) periodeLabel,
                    if (terbit.isNotEmpty) 'Terbit $terbit',
                    if (jatuhTempo.isNotEmpty) 'Tempo $jatuhTempo',
                  ].join('  -  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: context.textMuted),
                ),
                const SizedBox(height: 6),
                if (status.isNotEmpty) StatusChip(label: status, kind: statusKind),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            nominal != null ? rupiah(nominal) : '-',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
              color: AppColors.indigo700,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================================================================== tab 2

class _VaTab extends StatefulWidget {
  @override
  State<_VaTab> createState() => _VaTabState();
}

class _VaTabState extends State<_VaTab> with AutomaticKeepAliveClientMixin {
  late Future<dynamic> _future = _load();

  @override
  bool get wantKeepAlive => true;

  Future<dynamic> _load() => context.read<ApiClient>().get('/api/tagihan/virtual-account');

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<dynamic>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const LoadingView();
        }
        if (snap.hasError) {
          return ErrorRetry(
              message: errorText(snap.error!),
              onRetry: () => setState(() => _future = _load()));
        }
        final data = snap.hasData
            ? (snap.data is Map
                ? ((snap.data as Map)['data'] ?? snap.data)
                : snap.data)
            : null;
        final va = deepFind(data, ['no_va', 'va', 'nomor_va', 'virtual_account'])
            ?.toString();
        final bank = deepFind(data, ['bank', 'nama_bank'])?.toString();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (va != null && va.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.indigo900, AppColors.indigo500],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        bank != null && bank.isNotEmpty
                            ? 'Virtual Account - $bank'
                            : 'Nomor Virtual Account',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.72),
                            fontSize: 12.5),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            va,
                            style: const TextStyle(
                              color: AppColors.amberLight,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => copyText(context, va),
                          icon: const Icon(Icons.copy_rounded,
                              color: Colors.white, size: 20),
                          tooltip: 'Salin VA',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            SurfaceCard(
              child: SmartJson(data: data),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}

// ==================================================================== tab 3

class _RiwayatTab extends StatefulWidget {
  @override
  State<_RiwayatTab> createState() => _RiwayatTabState();
}

class _RiwayatTabState extends State<_RiwayatTab>
    with AutomaticKeepAliveClientMixin {
  late Future<dynamic> _future = _load();

  @override
  bool get wantKeepAlive => true;

  Future<dynamic> _load() =>
      context.read<ApiClient>().get('/api/tagihan/riwayat');

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<dynamic>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const LoadingView();
        }
        if (snap.hasError) {
          return ErrorRetry(
              message: errorText(snap.error!),
              onRetry: () => setState(() => _future = _load()));
        }
        final data =
            snap.hasData ? ((snap.data is Map) ? (snap.data as Map)['data'] ?? snap.data : snap.data) : null;
        final items = findMapList(data);
        if (items.isEmpty) {
          return ListView(
            children: [
              const SizedBox(height: 60),
              const EmptyView(
                  icon: Icons.history_rounded,
                  message: 'Belum ada riwayat pembayaran.'),
              SurfaceCard(
                child: SmartJson(data: data),
              ),
            ],
          );
        }
        return RefreshIndicator(
          color: AppColors.indigo700,
          onRefresh: () async => setState(() => _future = _load()),
          child: ListView(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              for (final r in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: SurfaceCard(
                    padding: const EdgeInsets.all(13),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.green.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.check_circle_outline_rounded,
                              size: 20, color: AppColors.green),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pickString(r,
                                    ['komponen', 'keterangan', 'nama', 'metode'],
                                    'Pembayaran'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: context.textPrimary,
                                ),
                              ),
                              Text(
                                pickString(
                                    r, ['tanggal', 'tgl', 'waktu'], '-'),
                                style: TextStyle(
                                    fontSize: 11,
                                    color: context.textMuted),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          r['jumlah'] != null || r['nominal'] != null
                              ? rupiah(r['jumlah'] ?? r['nominal'])
                              : '-',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            color: AppColors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

// ==================================================================== tab 4

class _StatusTab extends StatefulWidget {
  @override
  State<_StatusTab> createState() => _StatusTabState();
}

class _StatusTabState extends State<_StatusTab>
    with AutomaticKeepAliveClientMixin {
  late Future<dynamic> _future = _load();

  @override
  bool get wantKeepAlive => true;

  Future<dynamic> _load() =>
      context.read<ApiClient>().get('/api/tagihan/status');

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<dynamic>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const LoadingView();
        }
        if (snap.hasError) {
          return ErrorRetry(
              message: errorText(snap.error!),
              onRetry: () => setState(() => _future = _load()));
        }
        final data =
            snap.hasData ? ((snap.data is Map) ? (snap.data as Map)['data'] ?? snap.data : snap.data) : null;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SurfaceCard(
              child: SmartJson(data: data),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}
