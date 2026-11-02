import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../screens/chat_assistant_screen.dart';
import '../theme/app_theme.dart';

/// Floating draggable bubble dengan snapping ke tepi layar ala iOS AssistiveTouch.
/// Menyediakan akses cepat ke Asisten SISFO AI dari mana saja dalam shell aplikasi.
class DraggableAssistantBubble extends StatefulWidget {
  const DraggableAssistantBubble({super.key});

  @override
  State<DraggableAssistantBubble> createState() => _DraggableAssistantBubbleState();
}

class _DraggableAssistantBubbleState extends State<DraggableAssistantBubble>
    with SingleTickerProviderStateMixin {
  static const double _bubbleSize = 56.0;
  static const double _margin = 12.0;

  Offset _position = Offset.zero;
  bool _initialized = false;
  bool _isDragging = false;
  double _dragDistance = 0;

  late AnimationController _animController;
  Animation<Offset>? _snapAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..addListener(() {
        if (_snapAnimation != null) {
          setState(() {
            _position = _snapAnimation!.value;
          });
        }
      });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    _animController.stop();
    _dragDistance = 0;
    setState(() {
      _isDragging = true;
    });
  }

  void _onPanUpdate(DragUpdateDetails details, Size screenSize, EdgeInsets padding) {
    _dragDistance += details.delta.distance;
    final minY = padding.top + 45.0;
    final maxY = screenSize.height - padding.bottom - 110.0;

    double newX = _position.dx + details.delta.dx;
    double newY = _position.dy + details.delta.dy;

    // Batasi posisi agar tidak keluar layar saat ditarik
    newX = newX.clamp(0.0, screenSize.width - _bubbleSize);
    newY = newY.clamp(minY, maxY);

    setState(() {
      _position = Offset(newX, newY);
    });
  }

  void _onPanEnd(DragEndDetails details, Size screenSize, EdgeInsets padding) {
    setState(() {
      _isDragging = false;
    });

    // Jika jarak pergerakan sangat minim, anggap sentuhan biasa (tap)
    if (_dragDistance < 7.0) {
      _openChat();
      return;
    }

    // Snap ke tepi kiri atau tepi kanan terdekat
    final screenMidX = screenSize.width / 2;
    final targetX = (_position.dx + (_bubbleSize / 2) < screenMidX)
        ? _margin
        : (screenSize.width - _bubbleSize - _margin);

    final minY = padding.top + 60.0;
    final maxY = screenSize.height - padding.bottom - 120.0;
    final targetY = _position.dy.clamp(minY, maxY);

    _snapTo(Offset(targetX, targetY));
  }

  void _snapTo(Offset target) {
    _snapAnimation = Tween<Offset>(
      begin: _position,
      end: target,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    _animController.forward(from: 0.0);
  }

  void _openChat() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ChatAssistantScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final padding = media.padding;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Ukuran efektif = area Stack tempat bubble hidup. Ini penting di
        // desktop, di mana aplikasi dibatasi oleh bingkai (DesktopFrame)
        // sehingga bukan lebar layar penuh — bubble harus dibatasi ke frame.
        final size = Size(
          constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : media.size.width,
          constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : media.size.height,
        );

        // Inisialisasi posisi sekali, dijadwalkan setelah frame pertama agar
        // `setState` tidak dipanggil di tengah build.
        if (!_initialized) {
          _initialized = true;
          final x = size.width - _bubbleSize - _margin;
          final y = size.height - padding.bottom - 165.0;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _position = Offset(x, y));
          });
        } else {
          // Jika ukuran area berubah (mis. resize jendela browser),
          // pastikan bubble tetap berada di dalam batas.
          final maxX = (size.width - _bubbleSize).clamp(0.0, double.infinity);
          final maxY = (size.height - _bubbleSize).clamp(0.0, double.infinity);
          final clamped = Offset(
            _position.dx.clamp(0.0, maxX),
            _position.dy.clamp(0.0, maxY),
          );
          if (clamped != _position) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _position = clamped);
            });
          }
        }

        final isDark = context.isDark;

        // `Positioned` hanya berfungsi bila parent langsungnya adalah `Stack`,
        // jadi LayoutBuilder mengembalikan Stack yang mengisi penuh area ini.
        return Stack(
          children: [
            Positioned(
              left: _position.dx,
              top: _position.dy,
              child: GestureDetector(
        onPanStart: _onPanStart,
        onPanUpdate: (details) => _onPanUpdate(details, size, padding),
        onPanEnd: (details) => _onPanEnd(details, size, padding),
        onTap: _openChat,
        child: AnimatedScale(
          scale: _isDragging ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: Container(
            width: _bubbleSize,
            height: _bubbleSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFF7D958),
                  Color(0xFFD3A40B),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.5),
                width: 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD3A40B).withValues(alpha: 0.45),
                  blurRadius: _isDragging ? 22 : 14,
                  offset: const Offset(0, 6),
                  spreadRadius: _isDragging ? 2 : 0,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 26,
                ),
                Positioned(
                  right: 4,
                  top: 5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4.5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFFF3CB32),
                        width: 0.8,
                      ),
                    ),
                    child: const Text(
                      'AI',
                      style: TextStyle(
                        color: Color(0xFFF3CB32),
                        fontSize: 8.0,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
              ),
            ),
          ],
        );
      },
    );
  }
}

