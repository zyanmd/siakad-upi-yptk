import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_provider.dart';
import '../state/periode_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'dashboard_screen.dart';
import 'jadwal_screen.dart';
import 'profil_screen.dart';
import 'tagihan_screen.dart';
import '../utils/app_strings.dart';
import '../widgets/draggable_assistant_bubble.dart';

/// Shell utama dengan Bottom Navigation Bar yang bersih, modern, dan rapi
/// tanpa floating island atau tema iOS.
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
        label: context.tr('nav_home', 'Beranda'),
        selectedIcon: Icons.home_rounded,
        unselectedIcon: Icons.home_outlined,
      ),
      (
        label: context.tr('nav_schedule', 'Jadwal'),
        selectedIcon: Icons.calendar_month_rounded,
        unselectedIcon: Icons.calendar_month_outlined,
      ),
      (
        label: context.tr('nav_billing', 'Tagihan'),
        selectedIcon: Icons.account_balance_wallet_rounded,
        unselectedIcon: Icons.account_balance_wallet_outlined,
      ),
      (
        label: context.tr('nav_profile', 'Profil'),
        selectedIcon: Icons.person_rounded,
        unselectedIcon: Icons.person_outline_rounded,
      ),
    ];

    // ── Mode desktop: navigasi vertikal di sisi kiri (navigation rail) ──
    if (isDesktopWidth(context)) {
      return Scaffold(
        backgroundColor: context.bg,
        body: Row(
          children: [
            _buildSideRail(context, navItems, isDark),
            Expanded(
              child: Stack(
                children: [
                  IndexedStack(index: _index, children: pages),
                  const DraggableAssistantBubble(),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // ── Mode mobile: floating capsule navigation bar (iOS style bulat melayang) ──
    return Scaffold(
      backgroundColor: context.bg,
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(index: _index, children: pages),
          const DraggableAssistantBubble(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(36),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.10),
                  blurRadius: 24,
                  spreadRadius: 0,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: (isDark ? AppColors.primaryYellow : AppColors.upiYellowDeep)
                      .withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(36),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xE61C1C1E)
                        : Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(36),
                    border: Border.all(
                      color: context.border,
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      for (int i = 0; i < navItems.length; i++)
                        _buildNavItem(
                          index: i,
                          label: navItems[i].label,
                          selectedIcon: navItems[i].selectedIcon,
                          unselectedIcon: navItems[i].unselectedIcon,
                          isSelected: _index == i,
                          isDark: isDark,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSideRailContent(
    BuildContext context,
    List<({String label, IconData selectedIcon, IconData unselectedIcon})>
        navItems,
    bool isDark,
  ) {
    final auth = context.watch<AuthProvider>();
    final nama = auth.nama;
    final nim = auth.nim;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Brand / logo ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryYellow, AppColors.upiYellowDeep],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.school_rounded,
                  color: Color(0xFF1C1917),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SIAKAD',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: context.textPrimary,
                      ),
                    ),
                    Text(
                      'UPI YPTK',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                        color: context.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Text(
            'MENU',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: context.textMuted,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // ── Item navigasi ──
        for (int i = 0; i < navItems.length; i++)
          _buildSideNavItem(
            index: i,
            label: navItems[i].label,
            selectedIcon: navItems[i].selectedIcon,
            unselectedIcon: navItems[i].unselectedIcon,
            isSelected: _index == i,
            isDark: isDark,
          ),

        const Spacer(),
        _buildUserCard(context, isDark, nama, nim),
      ],
    );
  }

  /// Item pada side rail desktop (ikon + label horizontal).
  Widget _buildSideNavItem({
    required int index,
    required String label,
    required IconData selectedIcon,
    required IconData unselectedIcon,
    required bool isSelected,
    required bool isDark,
  }) {
    final inactive = context.textMuted;
    final active = isDark ? AppColors.primaryYellow : AppColors.upiYellowDeep;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            if (_index != index) {
              setState(() => _index = index);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primaryYellow
                      .withValues(alpha: isDark ? 0.16 : 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected ? selectedIcon : unselectedIcon,
                  size: 21,
                  color: isSelected ? active : inactive,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      letterSpacing: -0.2,
                      color: isSelected ? active : inactive,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.upiYellowDeep,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Kartu pengguna di dasar side rail (avatar + nama + logout).
  Widget _buildUserCard(
    BuildContext context,
    bool isDark,
    String nama,
    String nim,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : const Color(0xFFF4F4F6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.border,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: AppColors.primaryYellow,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                _initials(nama),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1C1917),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nama.isEmpty ? 'Mahasiswa' : nama,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimary,
                    ),
                  ),
                  if (nim.isNotEmpty)
                    Text(
                      nim,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Keluar',
              onPressed: () => context.read<AuthProvider>().logout(),
              icon: Icon(
                Icons.logout_rounded,
                size: 20,
                color: context.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String nama) {
    final parts =
        nama.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  // ══════════════════════════════════════════════════════════════════
  //  DESKTOP SIDE RAIL (navigasi vertikal kiri)
  // ══════════════════════════════════════════════════════════════════

  Widget _buildSideRail(
    BuildContext context,
    List<({String label, IconData selectedIcon, IconData unselectedIcon})>
        navItems,
    bool isDark,
  ) {
    return Container(
      width: 264,
      decoration: BoxDecoration(
        color: context.card,
        border: Border(
          right: BorderSide(
            color: context.border,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        right: false,
        child: _buildSideRailContent(context, navItems, isDark),
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
    const activeTextIconColor = Color(0xFF1C1917);
    final inactiveColor = isDark ? Colors.white70 : const Color(0xFF6B7280);

    return GestureDetector(
      onTap: () {
        if (_index != index) {
          setState(() => _index = index);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 12,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: isSelected
              ? const LinearGradient(
                  colors: [AppColors.primaryYellow, AppColors.upiYellowDeep],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Colors.transparent,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.upiYellowDeep.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? selectedIcon : unselectedIcon,
              size: 20,
              color: isSelected ? activeTextIconColor : inactiveColor,
            ),
            AnimatedCrossFade(
              firstChild: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: activeTextIconColor,
                  ),
                ),
              ),
              secondChild: const SizedBox.shrink(),
              crossFadeState: isSelected
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      ),
    );
  }
}
