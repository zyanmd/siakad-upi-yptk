import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/download_screen.dart';
import 'screens/foto_ijazah_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'screens/profil_akademik_screen.dart';
import 'screens/splash_screen.dart';
import 'services/api_client.dart';
import 'services/session_store.dart';
import 'state/auth_provider.dart';
import 'state/periode_provider.dart';
import 'state/theme_provider.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SiakadApp());
}

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
        ChangeNotifierProvider<AuthProvider>(
          create: (ctx) => AuthProvider(
            ctx.read<ApiClient>(),
            ctx.read<SessionStore>(),
          ),
        ),
        ChangeNotifierProvider<PeriodeProvider>(
          create: (ctx) => PeriodeProvider(ctx.read<ApiClient>()),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, tp, _) {
          return MaterialApp(
            title: 'SIAKAD Kampus',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: tp.materialMode,
            initialRoute: '/',
            routes: {
              '/': (_) => const SplashScreen(),
              '/login': (_) => const LoginScreen(),
              '/home': (_) => const MainShell(),
              '/profil-akademik': (_) => const ProfilAkademikScreen(),
              '/download': (_) => const DownloadScreen(),
              '/foto-ijazah': (_) => const FotoIjazahScreen(),
            },
          );
        },
      ),
    );
  }
}
