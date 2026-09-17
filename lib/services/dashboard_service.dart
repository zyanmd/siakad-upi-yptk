import 'api_client.dart';

/// Service khusus modul Dashboard (/api/dashboard)
class DashboardService {
  DashboardService(this._api);

  final ApiClient _api;

  /// Ambil ringkasan agregat dashboard mahasiswa
  Future<dynamic> getDashboard() => _api.get('/api/dashboard');
}

