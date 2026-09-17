import 'api_client.dart';

/// Endpoint keuangan: /api/tagihan/*
class TagihanService {
  TagihanService(this._api);

  final ApiClient _api;

  Future<dynamic> list() => _api.get('/api/tagihan');

  Future<dynamic> invoice(String token) =>
      _api.get('/api/tagihan/invoice/$token');

  Future<dynamic> virtualAccount() => _api.get('/api/tagihan/virtual-account');

  Future<dynamic> riwayat() => _api.get('/api/tagihan/riwayat');

  Future<dynamic> status() => _api.get('/api/tagihan/status');
}
