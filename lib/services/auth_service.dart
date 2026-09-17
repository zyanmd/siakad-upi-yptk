import 'api_client.dart';

/// Endpoint auth: /api/auth/*
class AuthService {
  AuthService(this._api);

  final ApiClient _api;

  Future<dynamic> login(String username, String password) =>
      _api.post('/api/auth/login', body: {
        'username': username,
        'password': password,
      });

  Future<dynamic> logout() => _api.post('/api/auth/logout');

  Future<dynamic> me() => _api.get('/api/auth/me');

  Future<dynamic> refresh() => _api.post('/api/auth/refresh');
}
