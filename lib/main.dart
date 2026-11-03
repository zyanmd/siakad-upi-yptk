import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'screens/chat_assistant_screen.dart';
import 'screens/download_screen.dart';
import 'screens/foto_ijazah_screen.dart';
import 'screens/kartu_qrcode_wisuda_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'screens/profil_akademik_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/tentang_aplikasi_screen.dart';
import 'services/api_client.dart';
import 'services/app_update_service.dart';
import 'services/notification_service.dart';
import 'services/session_store.dart';
import 'state/app_update_provider.dart';
import 'state/auth_provider.dart';
import 'state/language_provider.dart';
import 'state/periode_provider.dart';
import 'state/theme_provider.dart';
import 'theme/app_theme.dart';
import 'widgets/app_update_dialog.dart';
import 'widgets/common.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  runApp(const SiakadApp());
}

/// Kunci navigator global supaya pengalihan ke halaman login saat sesi
/// berakhir bisa dilakukan dari mana pun tanpa bergantung pada context layar.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class SiakadApp extends StatelessWidget {
  const SiakadApp({super.key});

  @override
  Widget build(BuildContext context) {
    final store = SessionStore();

    return MultiProvider(
      providers: [
        Provider<SessionStore>.value(value: store),
        Provider<ApiClient>(create: (_) => ApiClient(store)),
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(store),
        ),
        ChangeNotifierProvider<LanguageProvider>(
          create: (_) => LanguageProvider(store),
        ),
        ChangeNotifierProvider<AuthProvider>(
          create: (ctx) => AuthProvider(
            ctx.read<ApiClient>(),
            ctx.read<SessionStore>(),
          ),
        ),
        ChangeNotifierProvider<PeriodeProvider>(
          create: (ctx) => PeriodeProvider(ctx.read<ApiClient>()),
        ),
        ChangeNotifierProvider<AppUpdateProvider>(
          create: (ctx) => AppUpdateProvider(
            AppUpdateService(ctx.read<ApiClient>()),
          ),
        ),
      ],
      child: _SessionGate(
        child: Consumer2<ThemeProvider, LanguageProvider>(
          builder: (context, tp, lp, _) {
            return MaterialApp(
              title: 'SIAKAD Kampus',
              debugShowCheckedModeBanner: false,
              navigatorKey: appNavigatorKey,
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: tp.materialMode,
              // Bingkai desktop: pada layar lebar, aplikasi ditampilkan
              // terpusat dengan kanvas di belakangnya agar tampilan rapi.
              builder: (context, child) => _UpdateGate(
                child: DesktopFrame(child: child ?? const SizedBox.shrink()),
              ),
                locale: lp.locale,
                supportedLocales: const [
                  Locale('id'),
                  Locale('en'),
                ],
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                initialRoute: '/',
                routes: {
                  '/': (_) => const SplashScreen(),
                  '/login': (_) => const LoginScreen(),
                  '/home': (_) => const MainShell(),
                  '/profil-akademik': (_) => const ProfilAkademikScreen(),
                  '/download': (_) => const DownloadScreen(),
                  '/foto-ijazah': (_) => const FotoIjazahScreen(),
                  '/kartu-wisuda': (_) => const KartuQrCodeWisudaScreen(),
                  '/chat': (_) => const ChatAssistantScreen(),
                  '/tentang': (_) => const TentangAplikasiScreen(),
                },
              );
            },
          ),
        ),
    );
  }
}

/// Memantau status autentikasi secara global. Begitu sesi berakhir (HTTP 401
/// atau logout), seluruh tumpukan halaman dibersihkan dan pengguna dikembalikan
/// ke halaman login — dari layar mana pun.
class _SessionGate extends StatefulWidget {
  const _SessionGate({required this.child});

  final Widget child;

  @override
  State<_SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<_SessionGate> with WidgetsBindingObserver {
  AuthProvider? _auth;
  bool _wasAuthed = false;
  bool _redirecting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthProvider>();
    if (identical(auth, _auth)) return;
    _auth?.removeListener(_onAuthChanged);
    _auth = auth;
    _wasAuthed = auth.isAuthed;
    auth.addListener(_onAuthChanged);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final auth = _auth;
      if (auth != null && auth.isAuthed) {
        auth.validateSession();
      }
    }
  }

  void _onAuthChanged() {
    final auth = _auth;
    if (auth == null) return;
    final authed = auth.isAuthed;
    final lostSession = _wasAuthed && !authed;
    _wasAuthed = authed;
    if (!lostSession) return;

    // Hindari pengalihan ganda bila beberapa request 401 datang bersamaan.
    if (_redirecting) return;
    _redirecting = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _redirecting = false;
      final nav = appNavigatorKey.currentState;
      if (nav == null) return;
      // Kosongkan seluruh tumpukan agar tidak bisa "back" ke layar lama.
      nav.pushNamedAndRemoveUntil('/login', (route) => false);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _auth?.removeListener(_onAuthChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Memeriksa pembaruan aplikasi sekali saat aplikasi dimulai, lalu menampilkan
/// pop up (opsional / wajib) bila tersedia versi terbaru.
class _UpdateGate extends StatefulWidget {
  const _UpdateGate({required this.child});

  final Widget child;

  @override
  State<_UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<_UpdateGate> {
  AppUpdateProvider? _provider;
  bool _dialogVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _provider = context.read<AppUpdateProvider>();
      _provider!.addListener(_onChange);
      _provider!.maybeCheck();
    });
  }

  void _onChange() {
    if (!mounted) return;
    final info = _provider?.pending;
    if (info == null || _dialogVisible) return;
    _maybeShow(info);
  }

  Future<void> _maybeShow(AppUpdateInfo info) async {
    if (_dialogVisible) return;
    _dialogVisible = true;
    try {
      final navContext = appNavigatorKey.currentContext ?? context;
      final deferred = await showAppUpdateDialog(navContext, info: info);
      if (!mounted) return;
      if (deferred && info.status != AppUpdateStatus.force) {
        await _provider?.dismissOptional(info);
      } else {
        _provider?.clearPending();
      }
    } catch (e) {
      debugPrint('[UpdateGate] Kendala saat menampilkan dialog update: ');
    } finally {
      _dialogVisible = false;
    }
  }

  @override
  void dispose() {
    _provider?.removeListener(_onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
