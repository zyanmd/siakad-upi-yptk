import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
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
/// Memindai QR presensi dosen langsung menggunakan kamera dengan kontrol zoom.
class AbsenQrScreen extends StatefulWidget {
  const AbsenQrScreen({super.key});

  @override
  State<AbsenQrScreen> createState() => _AbsenQrScreenState();
}

class _AbsenQrScreenState extends State<AbsenQrScreen> with SingleTickerProviderStateMixin {
  late final MobileScannerController _scannerController;
  late final AnimationController _animController;
  late final Animation<double> _scanAnimation;

  bool _isLoading = false;
  bool _isCameraActive = true;
  bool _isTorchOn = false;
  double _zoomScale = 0.0;
  double _baseZoomScale = 0.0;
  String? _successMessage;
  String? _courseName;
  String? _errorMessage;
  int _retryCountdown = 0;
  Timer? _countdownTimer;
  DateTime? _lastScannedTime;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      autoStart: true,
      detectionSpeed: DetectionSpeed.noDuplicates,
      detectionTimeoutMs: 1200,
      facing: CameraFacing.back,
      formats: const [BarcodeFormat.qrCode],
      torchEnabled: false,
      autoZoom: true,
    );

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _animController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _setZoom(double value) async {
    final clamped = value.clamp(0.0, 1.0);
    setState(() {
      _zoomScale = clamped;
    });
    if (_isCameraActive) {
      try {
        await _scannerController.setZoomScale(clamped);
      } catch (_) {}
    }
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

  void _onQrDetected(BarcodeCapture capture) {
    if (_isLoading || _retryCountdown > 0 || !_isCameraActive) return;

    final now = DateTime.now();
    if (_lastScannedTime != null &&
        now.difference(_lastScannedTime!) < const Duration(milliseconds: 1500)) {
      return;
    }

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue?.trim();
      if (raw != null && raw.isNotEmpty) {
        _lastScannedTime = now;
        _submitToken(raw);
        break;
      }
    }
  }

  Future<void> _submitToken(String token) async {
    final cleanToken = token.trim();
    if (cleanToken.isEmpty) {
      setState(() {
        _errorMessage = 'Silakan arahkan kamera ke kode QR.';
        _successMessage = null;
      });
      return;
    }

    if (!RegExp(r'^[A-Za-z0-9_-]{10,2048}$').hasMatch(cleanToken)) {
      HapticFeedback.vibrate();
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
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Presensi perkuliahan via kamera pemindai QR Dosen',
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
                            'Pemindai Kamera',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Arahkan kamera ke QR yang ditampilkan dosen di layar kelas. QR diperbarui setiap 20 detik.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.grey,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 18),

                          // LIVE CAMERA SCANNER VIEWPORT (Pinch-to-Zoom & Tap-to-Focus)
                          GestureDetector(
                            onScaleStart: _isCameraActive
                                ? (_) {
                                    _baseZoomScale = _zoomScale;
                                  }
                                : null,
                            onScaleUpdate: _isCameraActive
                                ? (details) {
                                    if (details.scale == 1.0) return;
                                    final nextZoom =
                                        (_baseZoomScale + (details.scale - 1.0) * 0.45)
                                            .clamp(0.0, 1.0);
                                    _setZoom(nextZoom);
                                  }
                                : null,
                            child: Container(
                              height: 310,
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Live Mobile Scanner
                                    if (_isCameraActive)
                                      MobileScanner(
                                        controller: _scannerController,
                                        fit: BoxFit.cover,
                                        tapToFocus: true,
                                        onDetect: _onQrDetected,
                                        errorBuilder: (context, error) {
                                          return Center(
                                            child: Padding(
                                              padding: const EdgeInsets.all(20),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.no_photography_outlined,
                                                    color: Colors.white70,
                                                    size: 44,
                                                  ),
                                                  const SizedBox(height: 12),
                                                  const Text(
                                                    'Akses Kamera Terhalang',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    'Pastikan izin kamera telah diberikan di pengaturan perangkat Anda.\n${error.errorDetails?.message ?? error.errorCode.name}',
                                                    style: const TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: 12,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      )
                                  else
                                    const Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.videocam_off_rounded,
                                            color: Colors.white54,
                                            size: 52,
                                          ),
                                          SizedBox(height: 10),
                                          Text(
                                            'Kamera sedang nonaktif.',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'Tekan "Mulai Kamera" di bawah untuk menyalakan.',
                                            style: TextStyle(
                                              color: Colors.white38,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                  // Viewfinder Reticle Overlay (Golden Reticle)
                                  if (_isCameraActive)
                                    Center(
                                      child: SizedBox(
                                        width: 210,
                                        height: 210,
                                        child: Stack(
                                          children: [
                                            // Frame Border with Gold Accent
                                            Container(
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: AppColors.upiYellow,
                                                  width: 3,
                                                ),
                                                borderRadius: BorderRadius.circular(16),
                                              ),
                                            ),

                                            // Animated Scanning Laser Bar
                                            AnimatedBuilder(
                                              animation: _scanAnimation,
                                              builder: (context, child) {
                                                return Positioned(
                                                  top: 200 * _scanAnimation.value,
                                                  left: 8,
                                                  right: 8,
                                                  child: Container(
                                                    height: 3,
                                                    decoration: BoxDecoration(
                                                      gradient: const LinearGradient(
                                                        colors: [
                                                          Colors.transparent,
                                                          AppColors.upiYellow,
                                                          Colors.white,
                                                          AppColors.upiYellow,
                                                          Colors.transparent,
                                                        ],
                                                      ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: AppColors.upiYellow.withValues(alpha: 0.8),
                                                          blurRadius: 8,
                                                          spreadRadius: 2,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),

                                            // Loading overlay when token is processing
                                            if (_isLoading)
                                              Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.black54,
                                                  borderRadius: BorderRadius.circular(16),
                                                ),
                                                child: const Center(
                                                  child: CircularProgressIndicator(
                                                    color: AppColors.upiYellow,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),

                                  // Floating Camera Tool Buttons (Torch & Switch Camera)
                                  if (_isCameraActive)
                                    Positioned(
                                      top: 10,
                                      right: 10,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Torch / Flash button
                                          Container(
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.6),
                                              shape: BoxShape.circle,
                                            ),
                                            child: IconButton(
                                              icon: Icon(
                                                _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                                                color: _isTorchOn ? AppColors.upiYellow : Colors.white,
                                                size: 20,
                                              ),
                                              tooltip: 'Senter',
                                              onPressed: () async {
                                                await _scannerController.toggleTorch();
                                                setState(() {
                                                  _isTorchOn = !_isTorchOn;
                                                });
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          // Switch Camera button
                                          Container(
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.6),
                                              shape: BoxShape.circle,
                                            ),
                                            child: IconButton(
                                              icon: const Icon(
                                                Icons.flip_camera_ios_rounded,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                              tooltip: 'Ganti Kamera',
                                              onPressed: () async {
                                                await _scannerController.switchCamera();
                                                setState(() {
                                                  _zoomScale = 0.0;
                                                });
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                  // Quick Zoom Level Pill on bottom overlay
                                  if (_isCameraActive)
                                    Positioned(
                                      bottom: 10,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.65),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            for (final preset in const [
                                              ('1x', 0.0),
                                              ('1.5x', 0.25),
                                              ('2x', 0.5),
                                              ('3x', 0.8),
                                            ])
                                              GestureDetector(
                                                onTap: () => _setZoom(preset.$2),
                                                child: Container(
                                                  margin: const EdgeInsets.symmetric(horizontal: 2),
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 9, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: (_zoomScale - preset.$2).abs() < 0.12
                                                        ? AppColors.upiYellow
                                                        : Colors.transparent,
                                                    borderRadius: BorderRadius.circular(14),
                                                  ),
                                                  child: Text(
                                                    preset.$1,
                                                    style: TextStyle(
                                                      fontSize: 11.5,
                                                      fontWeight: FontWeight.w800,
                                                      color: (_zoomScale - preset.$2).abs() < 0.12
                                                          ? Colors.black87
                                                          : Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          ),

                          // Zoom Slider Control Bar
                          if (_isCameraActive) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    onPressed: _zoomScale <= 0.0
                                        ? null
                                        : () => _setZoom(_zoomScale - 0.15),
                                    icon: const Icon(Icons.zoom_out_rounded, size: 20),
                                    tooltip: 'Perkecil',
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  Expanded(
                                    child: SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        trackHeight: 3,
                                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                      ),
                                      child: Slider(
                                        value: _zoomScale,
                                        min: 0.0,
                                        max: 1.0,
                                        activeColor: AppColors.upiYellowDeep,
                                        inactiveColor: isDark ? Colors.white24 : Colors.black12,
                                        onChanged: (v) => _setZoom(v),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _zoomScale >= 1.0
                                        ? null
                                        : () => _setZoom(_zoomScale + 0.15),
                                    icon: const Icon(Icons.zoom_in_rounded, size: 20),
                                    tooltip: 'Perbesar',
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  SizedBox(
                                    width: 38,
                                    child: Text(
                                      '${(_zoomScale * 100).round()}%',
                                      textAlign: TextAlign.end,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: context.textMuted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),

                          // Action Buttons: Mulai / Hentikan Kamera
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
                                      : () async {
                                          setState(() {
                                            _isCameraActive = true;
                                            _errorMessage = null;
                                            _zoomScale = 0.0;
                                          });
                                          await _scannerController.start();
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
                                      : () async {
                                          setState(() {
                                            _isCameraActive = false;
                                            _zoomScale = 0.0;
                                            _isTorchOn = false;
                                          });
                                          await _scannerController.stop();
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
                                        ? 'Kamera aktif. Posisikan QR dosen di dalam bingkai emas. Presensi akan diproses otomatis.'
                                        : 'Kamera sedang nonaktif.',
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
