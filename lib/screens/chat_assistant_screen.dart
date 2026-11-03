import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/chat_service.dart';
import '../theme/app_theme.dart';
import '../utils/smart.dart';
import '../widgets/common.dart';

// ── UPI YPTK Golden Yellow Gradient ──
const _yellowHeaderGradient = [
  Color(0xFFE5A620), // Bright Academic Gold
  Color(0xFFD48B08), // UPI Yellow
  Color(0xFFB87500), // Deep Academic Gold
];

/// Layar Percakapan Asisten SISFO AI dengan Header Emas Kurva Gelombang
/// Bersambung khas UPI YPTK dan antarmuka Neumorphic modern.
class ChatAssistantScreen extends StatefulWidget {
  const ChatAssistantScreen({super.key});

  @override
  State<ChatAssistantScreen> createState() => _ChatAssistantScreenState();
}

class _ChatAssistantScreenState extends State<ChatAssistantScreen> {
  late final ChatService _chatService;
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  bool _isLoading = true;
  bool _isSending = false;
  String? _error;

  List<Map<String, dynamic>> _messages = [];
  Map<String, dynamic> _state = {};

  final List<String> _quickPrompts = [
    'Bagaimana cara ambil KRS?',
    'Cek status tagihan & pembayaran',
    'Kapan jadwal ujian semester?',
    'Bagaimana cara ganti foto ijazah?',
  ];

  @override
  void initState() {
    super.initState();
    _chatService = ChatService(context.read<ApiClient>());
    _loadBootstrap();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBootstrap() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final resp = await _chatService.bootstrap();
      final data = asMap(resp['data'] ?? resp);

      final rawMsgs = asList(data['messages']);
      final msgs = rawMsgs.map((e) => asMap(e)).toList();
      final state = asMap(data['state']);

      if (mounted) {
        setState(() {
          _messages = msgs;
          _state = state;
          _isLoading = false;
        });
        _scrollToBottom(animate: false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = errorText(e);
          _isLoading = false;
        });
      }
    }
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      if (animate) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent + 80);
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    final clean = text.trim();
    if (clean.isEmpty || _isSending) return;

    _textCtrl.clear();
    HapticFeedback.lightImpact();

    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    // Tambahkan pesan pengguna secara instan (optimistic UI)
    setState(() {
      _messages.add({
        'id': now.millisecondsSinceEpoch,
        'message': clean,
        'sender': 'visitor',
        'sender_name': null,
        'time': timeStr,
      });
      _isSending = true;
    });
    _scrollToBottom();

    try {
      final resp = await _chatService.sendMessage(clean);
      final data = asMap(resp['data'] ?? resp);

      final rawMsgs = asList(data['messages']);
      final msgs = rawMsgs.map((e) => asMap(e)).toList();
      final state = asMap(data['state']);

      if (mounted) {
        setState(() {
          if (msgs.isNotEmpty) {
            _messages = msgs;
          }
          if (state.isNotEmpty) {
            _state = state;
          }
          _isSending = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        appToast(context, 'Gagal mengirim pesan: ${errorText(e)}', error: true);
      }
    }
  }

  void _showRoutingOptions() {
    final routingOptions = asList(_state['routing_options'])
        .map((e) => asMap(e))
        .toList();
    final currentChannel = pickString(_state, ['routing_channel'], 'ai');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: ctx.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: ctx.border, width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: ctx.isDark ? 0.45 : 0.12),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4.5,
                decoration: BoxDecoration(
                  color: ctx.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFF4D9), Color(0xFFFFE6A8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.upiYellowDeep.withValues(alpha: 0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.alt_route_rounded,
                    color: AppColors.upiYellowDeep,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pilih Saluran Percakapan',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: ctx.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Arahkan pertanyaan ke AI atau staf helpdesk kampus',
                        style: TextStyle(fontSize: 11.5, color: ctx.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(height: 1, color: ctx.border.withValues(alpha: 0.6)),
            const SizedBox(height: 12),
            if (routingOptions.isEmpty) ...[
              _routingTile(
                ctx,
                code: 'ai',
                label: 'AI Assistant',
                desc: 'Pertanyaan umum SISFO, panduan, pengumuman, dan data akademik.',
                icon: Icons.auto_awesome_rounded,
                isSelected: currentChannel == 'ai',
              ),
              _routingTile(
                ctx,
                code: 'prodi',
                label: 'Program Studi',
                desc: 'Masalah perkuliahan, administrasi akademik, dan jurusan.',
                icon: Icons.school_rounded,
                isSelected: currentChannel == 'prodi',
              ),
              _routingTile(
                ctx,
                code: 'wd2',
                label: 'WD-II (Keuangan)',
                desc: 'Tagihan, pembayaran SPP, dan registrasi perkuliahan.',
                icon: Icons.account_balance_wallet_rounded,
                isSelected: currentChannel == 'wd2',
              ),
              _routingTile(
                ctx,
                code: 'pa',
                label: 'Pembimbing Akademik',
                desc: 'Konsultasi KRS, rencana studi, dan bimbingan akademik.',
                icon: Icons.supervisor_account_rounded,
                isSelected: currentChannel == 'pa',
              ),
              _routingTile(
                ctx,
                code: 'it-support',
                label: 'IT Support',
                desc: 'Kendala login, sistem, aplikasi, dan teknis SISFO.',
                icon: Icons.support_agent_rounded,
                isSelected: currentChannel == 'it-support',
              ),
            ] else ...[
              for (final opt in routingOptions)
                _routingTile(
                  ctx,
                  code: pickString(opt, ['code'], ''),
                  label: pickString(opt, ['label'], 'Divisi'),
                  desc: pickString(opt, ['description'], ''),
                  icon: _iconForChannel(pickString(opt, ['code'], '')),
                  isSelected: currentChannel == pickString(opt, ['code'], ''),
                ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _iconForChannel(String code) {
    switch (code.toLowerCase()) {
      case 'ai':
        return Icons.auto_awesome_rounded;
      case 'prodi':
        return Icons.school_rounded;
      case 'wd2':
        return Icons.account_balance_wallet_rounded;
      case 'pa':
        return Icons.supervisor_account_rounded;
      case 'it-support':
        return Icons.support_agent_rounded;
      default:
        return Icons.chat_bubble_outline_rounded;
    }
  }

  Widget _routingTile(
    BuildContext ctx, {
    required String code,
    required String label,
    required String desc,
    required IconData icon,
    required bool isSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: IosBounceTap(
        onTap: () async {
          Navigator.pop(ctx);
          await _switchRouting(code, label);
        },
        child: Container(
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.upiYellowDeep.withValues(alpha: 0.12)
                : ctx.softFill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.upiYellowDeep : ctx.border,
              width: isSelected ? 1.4 : 0.8,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.upiYellowDeep : ctx.card,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: isSelected ? Colors.white : AppColors.upiYellowDeep,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                        color: isSelected ? AppColors.upiYellowDeep : ctx.textPrimary,
                      ),
                    ),
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        desc,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: ctx.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.upiYellowDeep,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _switchRouting(String code, String label) async {
    setState(() => _isSending = true);
    try {
      Map<String, dynamic> resp;
      if (code == 'ai') {
        resp = await _chatService.useAi();
      } else {
        resp = await _chatService.routeDestination(code);
      }
      final data = asMap(resp['data'] ?? resp);
      final rawMsgs = asList(data['messages']);
      final msgs = rawMsgs.map((e) => asMap(e)).toList();
      final state = asMap(data['state']);

      if (mounted) {
        setState(() {
          if (msgs.isNotEmpty) _messages = msgs;
          if (state.isNotEmpty) _state = state;
          _isSending = false;
        });
        appToast(context, 'Tujuan chat dialihkan ke $label');
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        appToast(context, 'Gagal mengalihkan tujuan: ${errorText(e)}',
            error: true);
      }
    }
  }

  // ────────────────────────────────────────────────── NEUMORPHIC CARD HELPER
  Widget _buildNeuCard({
    required BuildContext context,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
    VoidCallback? onTap,
  }) {
    final isDark = context.isDark;
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.border,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.35)
                : const Color(0xFF94A3B8).withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
          if (!isDark)
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.9),
              blurRadius: 10,
              offset: const Offset(-2, -2),
            ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return IosBounceTap(onTap: onTap, child: content);
    }
    return content;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final bg = context.bg;

    final routingLabel = pickString(_state, ['routing_label'], 'AI Assistant');
    final isAi = pickString(_state, ['routing_channel'], 'ai') == 'ai';

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          // ──── HEADER KUNING DENGAN LEKUKAN BERSAMBUNG & FLOATING CHANNEL PILL ────
          Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              _buildCurvedYellowHeader(
                routingLabel: routingLabel,
                isAi: isAi,
              ),
              Positioned(
                bottom: -22,
                left: 0,
                right: 0,
                child: _buildFloatingChannelPill(context, routingLabel, isAi, isDark),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Banner Status Divisi jika terhubung ke Helpdesk Manusia
          if (!isAi)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.blue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.blue.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.support_agent_rounded,
                      size: 16, color: AppColors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Terhubung ke $routingLabel. Pesan akan diproses oleh staf.',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.blue,
                      ),
                    ),
                  ),
                  IosBounceTap(
                    onTap: () => _switchRouting('ai', 'AI Assistant'),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        'Kembali ke AI',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.upiYellowDeep,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Daftar Pesan Chat
          Expanded(
            child: _isLoading
                ? const Center(
                    child: LoadingView(label: 'Menghubungkan ke Asisten SISFO...'),
                  )
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: ErrorRetry(
                            message: _error!,
                            onRetry: _loadBootstrap,
                          ),
                        ),
                      )
                    : ListView(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        children: [
                          // Kartu Pengantar Awal Neumorphic
                          _buildWelcomeCard(),
                          const SizedBox(height: 14),

                          // Quick Prompts jika pesan masih sedikit
                          if (_messages.length <= 2) ...[
                            _buildQuickPromptsBar(),
                            const SizedBox(height: 14),
                          ],

                          // Deretan Pesan
                          for (final msg in _messages) _buildMessageBubble(msg),

                          // Indikator AI Sedang Mengetik
                          if (_isSending) _buildTypingIndicator(),
                        ],
                      ),
          ),

          // Input Bar di Bawah
          _buildInputBar(),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────── HEADER KUNING DENGAN LEKUKAN BERSAMBUNG
  Widget _buildCurvedYellowHeader({
    required String routingLabel,
    required bool isAi,
  }) {
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
                // Top Row: Back + Judul + Reset/Reload Action
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (canPop) ...[
                          IconButton(
                            onPressed: () {
                              Navigator.of(context).maybePop();
                            },
                            icon: const Icon(Icons.arrow_back_rounded,
                                color: Colors.white, size: 24),
                            tooltip: 'Kembali',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 8),
                        ],
                        const Text(
                          'Asisten SISFO AI',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ],
                    ),
                    IosBounceTap(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _loadBootstrap();
                        appToast(context, 'Memuat ulang percakapan...');
                      },
                      child: Container(
                        width: 38,
                        height: 38,
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
                        child: const Icon(Icons.refresh_rounded,
                            size: 20, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Hero Banner Profil Asisten: Avatar Robot & Status Online
                Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.2),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.9),
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
                          Icons.auto_awesome_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Asisten Pintar Mahasiswa',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF4ADE80), // Bright green indicator
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Aktif 24/7 • Siap Membantu',
                                style: TextStyle(
                                  color: Color(0xE6FFFFFF),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'UPI YPTK',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
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

  // ────────────────────────────────────────────────── FLOATING CHANNEL PILL
  Widget _buildFloatingChannelPill(
    BuildContext context,
    String routingLabel,
    bool isAi,
    bool isDark,
  ) {
    return Center(
      child: IosBounceTap(
        onTap: _showRoutingOptions,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.40)
                    : Colors.black.withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isAi
                      ? AppColors.upiYellowDeep.withValues(alpha: 0.15)
                      : AppColors.blue.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _iconForChannel(pickString(_state, ['routing_channel'], 'ai')),
                  size: 15,
                  color: isAi ? AppColors.upiYellowDeep : AppColors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Saluran: $routingLabel',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: AppColors.upiYellowDeep,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return _buildNeuCard(
      context: context,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF4D9), Color(0xFFFFE6A8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.upiYellowDeep.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.smart_toy_outlined,
              color: AppColors.upiYellowDeep,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Halo! Saya Asisten AI SISFO',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tanyakan seputar KRS, jadwal kuliah, kartu ujian, status keuangan, atau kendala perkuliahan kampus UPI YPTK Padang.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: context.textMuted,
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

  Widget _buildQuickPromptsBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Rekomendasi Pertanyaan Cepat:',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: context.textMuted,
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final prompt in _quickPrompts)
              IosBounceTap(
                onTap: () => _sendMessage(prompt),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.upiYellowDeep.withValues(alpha: 0.25),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 13,
                        color: AppColors.upiYellowDeep,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        prompt,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final sender = pickString(msg, ['sender'], 'ai').toLowerCase();
    final isVisitor = sender == 'visitor' || sender == 'user';
    final text = pickString(msg, ['message', 'text'], '');
    final time = pickString(msg, ['time'], '');
    final senderName =
        pickString(msg, ['sender_name'], isVisitor ? 'Saya' : 'Asisten SISFO');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: isVisitor ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.84,
          ),
          child: isVisitor
              ? _visitorBubble(text, time)
              : _aiBubble(text, time, senderName),
        ),
      ),
    );
  }

  Widget _visitorBubble(String text, String time) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFE5A620), // Bright Gold
            Color(0xFFD48B08), // UPI Yellow
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(4),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.upiYellowDeep.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.35,
            ),
          ),
          if (time.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _aiBubble(String text, String time, String senderName) {
    return _buildNeuCard(
      context: context,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.amber, AppColors.upiYellowDeep],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 13,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                senderName,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.upiYellowDeep,
                ),
              ),
              const Spacer(),
              IosBounceTap(
                onTap: () {
                  copyText(context, text);
                  HapticFeedback.selectionClick();
                },
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.copy_rounded,
                    size: 15,
                    color: context.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: context.textPrimary,
              height: 1.45,
            ),
          ),
          if (time.isNotEmpty) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                time,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: context.textMuted,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: context.border,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.upiYellowDeep,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Asisten sedang merespons...',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: context.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar() {

    return Container(
      decoration: BoxDecoration(
        color: context.card,
        border: Border(
          top: BorderSide(
            color: context.border,
            width: 0.8,
          ),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        14,
        MediaQuery.of(context).padding.bottom + 10,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: context.softFill,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: context.border,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _textCtrl,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: _sendMessage,
                style: TextStyle(fontSize: 13.5, color: context.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Ketik pertanyaan untuk Asisten SISFO...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: context.textMuted,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IosBounceTap(
            onTap: _isSending ? null : () => _sendMessage(_textCtrl.text),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: _yellowHeaderGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.upiYellowDeep.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: _isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.arrow_upward_rounded,
                        color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
