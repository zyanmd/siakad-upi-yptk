import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_provider.dart';
import '../state/periode_provider.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'jadwal_screen.dart';
import 'profil_screen.dart';
import 'tagihan_screen.dart';

/// Shell utama dengan Floating Capsule Navbar bergaya Dynamic Island iOS
/// dilengkapi efek Frosted Glass (BackdropFilter blur), border hairline 0.5px,
/// dan ikon Cupertino native.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  AuthProvider? _auth;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _auth = context.read<AuthProvider>();
      _auth!.addListener(_onAuthChanged);
      context.read<PeriodeProvider>().ensureLoaded();
      if (!_auth!.isAuthed) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    });
  }

  void _onAuthChanged() {
    if (!mounted) return;
    if (_auth != null && !_auth!.isAuthed) {
      context.read<PeriodeProvider>().reset();
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  void dispose() {
    _auth?.removeListener(_onAuthChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    final pages = [
      const DashboardScreen(),
      const JadwalScreen(),
      const TagihanScreen(),
      const ProfilScreen(),
    ];

    final navItems = [
      (
        label: 'Beranda',
        selectedIcon: CupertinoIcons.house_fill,
        unselectedIcon: CupertinoIcons.house,
      ),
      (
        label: 'Jadwal',
        selectedIcon: CupertinoIcons.calendar,
        unselectedIcon: CupertinoIcons.calendar_today,
      ),
      (
        label: 'Tagihan',
        selectedIcon: CupertinoIcons.creditcard_fill,
        unselectedIcon: CupertinoIcons.creditcard,
      ),
      (
        label: 'Profil',
        selectedIcon: CupertinoIcons.person_crop_circle_fill,
        unselectedIcon: CupertinoIcons.person_crop_circle,
      ),
    ];

    return Scaffold(
      backgroundColor: context.bg,
      extendBody: true,
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: SafeArea(
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(34),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xCC1C1C1E)
                      : const Color(0xDDFFFFFF),
                  borderRadius: BorderRadius.circular(34),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.14)
                        : Colors.black.withValues(alpha: 0.08),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    for (int i = 0; i < navItems.length; i++)
                      Expanded(
                        child: _buildNavItem(
                          index: i,
                          label: navItems[i].label,
                          selectedIcon: navItems[i].selectedIcon,
                          unselectedIcon: navItems[i].unselectedIcon,
                          isSelected: _index == i,
                          isDark: isDark,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    required IconData selectedIcon,
    required IconData unselectedIcon,
    required bool isSelected,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () {
        if (_index != index) {
          setState(() => _index = index);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryYellow : Colors.transparent,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? selectedIcon : unselectedIcon,
              size: 20,
              color: isSelected
                  ? const Color(0xFF1C1917)
                  : (isDark ? const Color(0xFF8E8E93) : const Color(0xFF636366)),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: -0.2,
                color: isSelected
                    ? const Color(0xFF1C1917)
                    : (isDark ? const Color(0xFF8E8E93) : const Color(0xFF636366)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
