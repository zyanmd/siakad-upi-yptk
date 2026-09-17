import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:siakad_app/screens/krs_screen.dart';
import 'package:siakad_app/services/api_client.dart';
import 'package:siakad_app/services/session_store.dart';
import 'package:siakad_app/state/auth_provider.dart';
import 'package:siakad_app/state/periode_provider.dart';
import 'package:siakad_app/state/theme_provider.dart';
import 'package:siakad_app/theme/app_theme.dart';

class MockApiClient extends ApiClient {
  MockApiClient(super.store);

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    if (path.contains('/periode')) {
      return {
        'success': true,
        'data': [
          {'kode': '20261', 'label': 'Ganjil 2026/2027'},
        ]
      };
    }
    if (path == '/api/akademik/krs') {
      return {
        'success': true,
        'data': {
          'periode': 'Ganjil 2026/2027',
          'periode_kode': '20261',
          'status_krs': 'open',
          'bisa_ubah': true,
          'total_sks': '18',
          'maks_sks': '24',
          'mata_kuliah': [
            {
              'kode': 'SI101',
              'nama': 'Algoritma & Pemrograman',
              'sks': '3',
              'kelas': 'SI-1',
              'ruang': 'F.3.4',
              'hari': 'Senin',
              'jam': '07:30 - 10:00',
              'dosen': 'Dr. Budi',
              'status': 'Disetujui',
              'delete_token': 'del123',
              'detail_token': 'det123',
            },
            {
              'kode': null,
              'nama': 'Basis Data',
              'sks': null,
              'kelas': null,
              'ruang': null,
              'hari': null,
              'jam': null,
              'dosen': null,
              'status': null,
              'delete_token': null,
              'detail_token': null,
            },
            {
              'kode': 'SI103',
              'nama': null,
              'sks': '3',
              'kelas': 'SI-2',
              'ruang': null,
              'hari': 'Rabu',
              'jam': '08:00 - 10:00',
              'dosen': null,
              'status': 'Batal',
              'delete_token': null,
              'detail_token': null,
            },
            {
              'kode': 'SI104',
              'nama': 'Jaringan Komputer',
              'sks': '3',
              'kelas': 'SI-1',
              'ruang': 'Lab 1',
              'hari': 'Kamis',
              'jam': '10:00 - 12:00',
              'dosen': 'Dosen A',
              'status': null,
              'delete_token': 'del4',
              'detail_token': 'det4',
            },
            {
              'kode': 'SI105',
              'nama': 'Kecerdasan Buatan',
              'sks': '3',
              'kelas': 'SI-3',
              'ruang': 'F.1.1',
              'hari': null,
              'jam': null,
              'dosen': 'Dosen B',
              'status': 'Disetujui',
              'delete_token': null,
              'detail_token': null,
            },
            {
              'kode': 'SI106',
              'nama': 'Rekayasa Perangkat Lunak',
              'sks': '3',
              'kelas': 'SI-1',
              'ruang': 'F.1.2',
              'hari': 'Jumat',
              'jam': '13:30 - 16:00',
              'dosen': null,
              'status': null,
              'delete_token': 'del6',
              'detail_token': null,
            },
            {
              'kode': 'SI107',
              'nama': 'Etika Profesi',
              'sks': '2',
              'kelas': 'SI-2',
              'ruang': 'F.2.1',
              'hari': 'Sabtu',
              'jam': '08:00 - 10:00',
              'dosen': 'Dosen C',
              'status': 'Disetujui',
              'delete_token': null,
              'detail_token': 'det7',
            },
          ]
        }
      };
    }
    if (path == '/api/akademik/krs/status') {
      return {
        'success': true,
        'data': {
          'status_krs': 'open',
          'bisa_ubah': true,
        }
      };
    }
    return {'success': true, 'data': {}};
  }
}

void main() {
  testWidgets('KrsScreen pumps and renders correctly', (tester) async {
    final store = SessionStore();
    final api = MockApiClient(store);
    final auth = AuthProvider(api, store);
    final pp = PeriodeProvider(api);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SessionStore>.value(value: store),
          Provider<ApiClient>.value(value: api),
          ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider(store)),
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<PeriodeProvider>.value(value: pp),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const KrsScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 1));
  });
}
