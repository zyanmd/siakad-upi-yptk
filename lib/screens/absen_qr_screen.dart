import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/akademik_service.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

// UPI YPTK Golden Yellow Gradient
const _yellowHeaderGradient = [
  Color(0xFFE5A620), // Bright Academic Gold
  Color(0xFFD48B08), // UPI Yellow
  Color(0xFFB87500), // Deep Academic Gold
];

/// Halaman Absen QR SIAKAD UPI YPTK
/// Memindai atau memasukkan token QR yang ditampilkan dosen saat perkuliahan.
class AbsenQrScreen extends StatefulWidget {
  const AbsenQrScreen({super.key});

  @override
  State<AbsenQrScreen> createState() => _AbsenQrScreenState();
}

class _AbsenQrScreenState extends State<AbsenQrScreen> {
  final TextEditingController _tokenCtrl = TextEditingController();
  bool _isLoading = false;
  bool _isCameraActive = true;
  String? _successMessage;
  String? _courseName;
  String? _errorMessage;
  int _retryCountdown = 0;
  Timer? _countdownTimer;

  @override
  void dispose() {
    _tokenCtrl.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown(int seconds) {
    _countdownTimer?.cancel();
    setState(() {
      _retryCountdown = seconds;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_retryCountdown <= 1) {
        timer.cancel();
        setState(() {
          _retryCountdown = 0;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _retryCountdown--;
        });
      }
    });
  }

  Future<void> _submitToken(String token) async {
    final cleanToken = token.trim();
    if (cleanToken.isEmpty) {
      setState(() {
        _errorMessage = 'Silakan masukkan atau scan kode QR.';
        _successMessage = null;
      });
      return;
    }

    if (!RegExp(r'^[A-Za-z0-9_-]{10,2048}$').hasMatch(cleanToken)) {
      setState(() {
        _errorMessage =
            'Kode ini bukan QR presensi SISFO. Arahkan ke QR yang ditampilkan dosen.';
        _successMessage = null;
      });
      return;
    }

    if (_retryCountdown > 0) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
      _courseName = null;
    });

    final api = context.read<ApiClient>();
    final service = AkademikService(api);

    try {
      final res = await service.absenQrSubmit(cleanToken);
      if (!mounted) return;

      final isSuccess = res is Map && res['success'] == true;
      final msg = res is Map ? (res['message']?.toString() ?? '') : '';
      final course = res is Map ? (res['course']?.toString() ?? '') : '';

      if (isSuccess) {
        HapticFeedback.heavyImpact();
        setState(() {
          _isLoading = false;
          _successMessage = msg.isNotEmpty ? msg : 'Presensi berhasil dicatat.';
          _courseName = course;
          _tokenCtrl.clear();
        });
        _showSuccessDialog(_successMessage!, _courseName);
      } else {
        HapticFeedback.vibrate();
        final statusCode = res is Map ? res['status_code'] : null;
        if (statusCode == 429) {
          final retrySec = int.tryParse(res['retry_after']?.toString() ?? '60') ?? 60;
          _startCountdown(retrySec);
        }
        setState(() {
          _isLoading = false;
          _errorMessage = msg.isNotEmpty ? msg : 'QR presensi gagal diproses.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.vibrate();
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _showSuccessDialog(String message, String? course) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.green.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.green,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Presensi Berhasil!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(fontSize: 14, color: AppColors.grey),
              textAlign: TextAlign.center,
            ),
            if (course != null && course.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.upiYellow.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  course,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.upiYellowDeep,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.upiYellowDeep,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                },
                child: const Text(
                  'Selesai',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showManualInputDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Input Token QR Manual', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Jika kamera tidak dapat memindai, Anda dapat menempelkan token kode QR di sini:',
              style: TextStyle(fontSize: 13, color: AppColors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Tempel token QR di sini...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.upiYellowDeep,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final val = ctrl.text.trim();
              Navigator.of(ctx).pop();
              if (val.isNotEmpty) {
                _tokenCtrl.text = val;
                _submitToken(val);
              }
            },
            child: const Text('Kirim'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final cardBg = context.card;
    final bg = context.bg;
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          // ──── HEADER KUNING LEKUKAN KHAS UPI YPTK ────
          ClipPath(
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (canPop) ...[
                                IconButton(
                                  onPressed: () => Navigator.of(context).maybePop(),
                                  icon: const Icon(Icons.arrow_back_rounded,
                                      color: Colors.white, size: 24),
                                  tooltip: 'Kembali',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                const SizedBox(width: 8),
                              ],
                              const Text(
                                'Absen QR',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            onPressed: _showManualInputDialog,
                            icon: const Icon(Icons.keyboard_alt_outlined, color: Colors.white),
                            tooltip: 'Input Manual',
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Presensi perkuliahan via kode QR Dosen',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ──── BODY KONTEN ────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                children: [
                  // Main Card Presensi QR
                  Card(
                    color: cardBg,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Absen QR',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Arahkan kamera ke QR yang ditampilkan dosen. QR berubah setiap 20 detik.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.grey,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Scanner viewfinder box
                          Container(
                            height: 280,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                if (!_isCameraActive)
                                  const Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.videocam_off_rounded,
                                          color: Colors.white54,
                                          size: 48,
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'Kamera belum dimulai.',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Target Reticle
                                        Container(
                                          width: 190,
                                          height: 190,
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: AppColors.upiYellow,
                                              width: 3,
                                            ),
                                            borderRadius: BorderRadius.circular(18),
                                          ),
                                          child: Stack(
                                            children: [
                                              Center(
                                                child: Icon(
                                                  Icons.qr_code_scanner_rounded,
                                                  color: AppColors.upiYellow.withValues(alpha: 0.8),
                                                  size: 80,
                                                ),
                                              ),
                                              if (_isLoading)
                                                const Center(
                                                  child: CircularProgressIndicator(
                                                    color: AppColors.upiYellow,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        const Text(
                                          'Posisikan QR dosen di dalam bingkai',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Action Buttons: Mulai / Hentikan
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.upiYellowDeep,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: isDark ? Colors.white12 : Colors.black12,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  onPressed: _isCameraActive
                                      ? null
                                      : () {
                                          setState(() {
                                            _isCameraActive = true;
                                            _errorMessage = null;
                                          });
                                        },
                                  icon: const Icon(Icons.videocam_rounded, size: 20),
                                  label: const Text(
                                    'Mulai Kamera',
                                    style: TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: isDark ? Colors.white70 : Colors.black87,
                                    side: BorderSide(
                                      color: isDark ? Colors.white24 : Colors.black26,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  onPressed: !_isCameraActive
                                      ? null
                                      : () {
                                          setState(() {
                                            _isCameraActive = false;
                                          });
                                        },
                                  icon: const Icon(Icons.stop_circle_outlined, size: 20),
                                  label: const Text(
                                    'Hentikan',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // Status Info Alert
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFBAE6FD),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _isCameraActive
                                        ? 'Kamera aktif. Arahkan ke QR dosen. Hasil akhir disimpan oleh dosen.'
                                        : 'Kamera belum dimulai.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0369A1),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Error Alert if any
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _retryCountdown > 0
                                          ? 'Terlalu banyak percobaan. Tunggu $_retryCountdown detik sebelum mencoba kembali.'
                                          : _errorMessage!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.red,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Success Alert if any
                          if (_successMessage != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.check_circle_outline_rounded, color: AppColors.green, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '$_successMessage ${_courseName ?? ''}'.trim(),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.green,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 20),
                          const Divider(),
                          const SizedBox(height: 12),

                          // Manual input section
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _tokenCtrl,
                                  decoration: InputDecoration(
                                    hintText: 'Tempel token QR di sini...',
                                    hintStyle: const TextStyle(fontSize: 13),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () async {
                                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                                  if (data?.text != null) {
                                    _tokenCtrl.text = data!.text!.trim();
                                  }
                                },
                                icon: const Icon(Icons.content_paste_rounded),
                                tooltip: 'Tempel dari Clipboard',
                              ),
                              const SizedBox(width: 4),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.upiYellowDeep,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                onPressed: _isLoading || _retryCountdown > 0
                                    ? null
                                    : () => _submitToken(_tokenCtrl.text),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Kirim',
                                        style: TextStyle(fontWeight: FontWeight.w700),
                                      ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
