import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_provider.dart';
import '../state/periode_provider.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'jadwal_screen.dart';
import 'profil_screen.dart';
import 'tagihan_screen.dart';

/// Shell utama dengan bottom navigation: Beranda, Jadwal, Tagihan, Profil.
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
        Navigator.of(context)
            .pushReplacementNamed('/login');
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
    final pages = [
      const DashboardScreen(),
      const JadwalScreen(),
      const TagihanScreen(),
      const ProfilScreen(),
    ];

    return Scaffold(
      backgroundColor: context.bg,
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        height: 80,
        selectedIndex: _index,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Jadwal',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Tagihan',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
