import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/krs_cetak_screen.dart';
import '../screens/krs_screen.dart';
import '../services/api_client.dart';
import '../state/periode_provider.dart';
import '../theme/app_theme.dart';
import '../utils/smart.dart';

/// Widget ringkasan KRS (Kartu Rencana Studi) modern untuk ditampilkan
/// di halaman utama (Dashboard) aplikasi SIAKAD UPI YPTK.
class KrsDashboardCard extends StatefulWidget {
  const KrsDashboardCard({
    super.key,
    this.preloadedData,
  });

  final Map<String, dynamic>? preloadedData;

  @override
  State<KrsDashboardCard> createState() => _KrsDashboardCardState();
}

class _KrsDashboardCardState extends State<KrsDashboardCard> {
  Future<Map<String, dynamic>>? _future;

  @override
  void initState() {
    super.initState();
    if (widget.preloadedData == null || widget.preloadedData!.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _fetchKrs();
      });
    }
  }

  void _fetchKrs() {
    final api = context.read<ApiClient>();
    final periode = context.read<PeriodeProvider>().value ?? fallbackPeriode();
    setState(() {
      _future = _loadKrs(api, periode);
    });
  }

  Future<Map<String, dynamic>> _loadKrs(ApiClient api, String periode) async {
    try {
      final results = await Future.wait<dynamic>([
        api.get('/api/akademik/krs', query: {'periode': periode}),
        api.get('/api/akademik/krs/status'),
      ]);
      return {
        'krs': results[0],
        'status': results[1],
        'periode': periode,
      };
    } catch (_) {
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.preloadedData != null && widget.preloadedData!.isNotEmpty) {
      return _buildCardContent(context, widget.preloadedData!);
    }

    if (_future == null) {
      return _buildPlaceholder(context, isLoading: true);
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _buildPlaceholder(context, isLoading: true);
        }
        final data = snap.data ?? {};
        return _buildCardContent(context, data);
      },
    );
  }

  Widget _buildPlaceholder(BuildContext context, {required bool isLoading}) {
    final isDark = context.isDark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: context.border,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.upiYellowDeep.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.fact_check_rounded,
              color: AppColors.upiYellowDeep,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kartu Rencana Studi (KRS)',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isLoading
                      ? 'Memuat data rencana studi...'
                      : 'Buka untuk melihat KRS semester ini',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (isLoading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.upiYellowDeep,
              ),
            )
          else
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
        ],
      ),
    );
  }

  Widget _buildCardContent(BuildContext context, Map<String, dynamic> raw) {
    final isDark = context.isDark;
    final krsResp = asMap(raw['krs']);
    final krsData = asMap(krsResp['data'] ?? krsResp);
    final statusResp = asMap(raw['status']);
    final statusData = asMap(statusResp['data'] ?? statusResp);

    final totalSks = pickString(
      krsData,
      ['total_sks', 'jumlah_sks', 'sks_total'],
      pickString(krsResp, ['total_sks', 'jumlah_sks', 'sks_total'], '24'),
    );
    final maksSks = pickString(
      krsData,
      ['maks_sks', 'max_sks', 'maksimal_sks'],
      pickString(statusData, ['maks_sks', 'max_sks', 'maksimal_sks'], '24'),
    );
    final statusKrs = pickString(
      krsData,
      ['status_krs', 'status', 'status_validasi'],
      pickString(statusData, ['status_krs', 'status'], 'Valid'),
    );

    final items = findMapList(krsData['items'] ?? krsData['data'] ?? krsData);
    final countMk = items.isNotEmpty ? items.length : null;

    final double totalVal = double.tryParse(totalSks) ?? 20.0;
    final double maksVal = double.tryParse(maksSks) ?? 24.0;
    final double progress =
        maksVal > 0 ? (totalVal / maksVal).clamp(0.0, 1.0) : 0.85;

    final bool isValid = statusKrs.toLowerCase().contains('valid') ||
        statusKrs.toLowerCase().contains('setuju') ||
        statusKrs.toLowerCase().contains('acc') ||
        statusKrs.toLowerCase().contains('ok');

    final periode = raw['periode']?.toString() ??
        context.read<PeriodeProvider>().value ??
        fallbackPeriode();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppColors.upiYellowDeep.withValues(alpha: 0.22),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.25)
                : AppColors.upiYellowDeep.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Baris Header: Icon + Judul + Status Badge ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFE5A620),
                      Color(0xFFD48B08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryYellow.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.fact_check_rounded,
                  color: Colors.white,
                  size: 22,
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
                          'KRS Online',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: context.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color:
                                AppColors.primaryYellow.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            periode.isNotEmpty ? periode : 'Semester Ini',
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.upiYellowDeep,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Kartu Rencana Studi Mahasiswa',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textMuted,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: isValid
                      ? AppColors.green.withValues(alpha: 0.12)
                      : AppColors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isValid
                        ? AppColors.green.withValues(alpha: 0.3)
                        : AppColors.amber.withValues(alpha: 0.4),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isValid
                          ? Icons.check_circle_rounded
                          : Icons.access_time_filled_rounded,
                      size: 11.5,
                      color: isValid ? AppColors.green : AppColors.amber,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      statusKrs.isNotEmpty ? statusKrs : 'Aktif',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isValid ? AppColors.green : AppColors.amber,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Progress Bar Beban SKS ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Beban SKS Diambil',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${totalVal.toInt()}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppColors.upiYellowDeep,
                        fontSize: 14.5,
                      ),
                    ),
                    TextSpan(
                      text: ' / ${maksVal.toInt()} SKS',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: context.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.grey.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primaryYellow,
              ),
            ),
          ),

          const SizedBox(height: 14),

          // ── 3 Mini Tags: SKS Terambil, Jumlah MK, Kuota Sisa ──
          Row(
            children: [
              Expanded(
                child: _buildMiniStat(
                  context,
                  label: 'SKS Diambil',
                  value: '${totalVal.toInt()} SKS',
                  color: AppColors.upiYellowDeep,
                  icon: Icons.stars_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniStat(
                  context,
                  label: 'Mata Kuliah',
                  value: countMk != null ? '$countMk MK' : 'Terdaftar',
                  color: AppColors.blue,
                  icon: Icons.auto_stories_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniStat(
                  context,
                  label: 'Sisa Kuota',
                  value: '${(maksVal - totalVal).clamp(0, 24).toInt()} SKS',
                  color: AppColors.green,
                  icon: Icons.check_circle_outline_rounded,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // ── Aksi Cepat: Buka KRS & Cetak KRS ──
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => KrsCetakScreen(periode: periode),
                      ),
                    );
                  },
                  icon: const Icon(Icons.print_rounded, size: 16),
                  label: const Text(
                    'Cetak KRS',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.textPrimary,
                    side: BorderSide(color: context.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 1,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const KrsScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text(
                    'Buka KRS',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryYellow,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    final isDark = context.isDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: 0.15),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: context.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
