// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:siakad_app/screens/dashboard_screen.dart';
import 'package:siakad_app/services/api_client.dart';
import 'package:siakad_app/services/session_store.dart';
import 'package:siakad_app/state/auth_provider.dart';
import 'package:siakad_app/state/periode_provider.dart';
import 'package:siakad_app/state/theme_provider.dart';
import 'package:siakad_app/theme/app_theme.dart';

void main() {
  testWidgets('DashboardScreen renders without error', (WidgetTester tester) async {
    final store = SessionStore();
    final api = ApiClient(store);
    final auth = AuthProvider(api, store);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SessionStore>.value(value: store),
          Provider<ApiClient>.value(value: api),
          ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider(store)),
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<PeriodeProvider>(create: (_) => PeriodeProvider(api)),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const DashboardScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Layanan Akademik'), findsOneWidget);
    expect(find.text('Tagihan & Pembayaran'), findsOneWidget);
    expect(find.text('Jadwal Kuliah Hari Ini'), findsOneWidget);
    await tester.pump(const Duration(seconds: 35));
  });
}
