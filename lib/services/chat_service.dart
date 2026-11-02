import '../utils/smart.dart';
import 'api_client.dart';

/// Layanan integrasi SISFO Assistant (AI Chat).
class ChatService {
  ChatService(this._api);

  final ApiClient _api;

  /// Ambil info awal chat, welcome message, mode aktif, dan routing options.
  Future<Map<String, dynamic>> bootstrap() async {
    final resp = await _api.post('/api/chat/bootstrap');
    return asMap(resp);
  }

  /// Kirim pesan ke SISFO AI Assistant.
  Future<Map<String, dynamic>> sendMessage(String message) async {
    final resp = await _api.post(
      '/api/chat/messages',
      body: {'message': message.trim()},
    );
    return asMap(resp);
  }

  /// Minta dihubungkan ke helpdesk manusia.
  Future<Map<String, dynamic>> requestHuman({String? destination}) async {
    final body = <String, dynamic>{};
    if (destination != null && destination.isNotEmpty) {
      body['destination'] = destination;
    }
    final resp = await _api.post('/api/chat/request-human', body: body);
    return asMap(resp);
  }

  /// Balik dari mode human ke AI assistant.
  Future<Map<String, dynamic>> useAi() async {
    final resp = await _api.post('/api/chat/use-ai');
    return asMap(resp);
  }

  /// Route chat ke divisi / destination tertentu (prodi, wd2, pa, it-support, ai).
  Future<Map<String, dynamic>> routeDestination(String destination) async {
    final resp = await _api.post(
      '/api/chat/route-destination',
      body: {'destination': destination},
    );
    return asMap(resp);
  }
}

