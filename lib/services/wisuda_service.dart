import 'package:dio/dio.dart';

import 'api_client.dart';

/// Service untuk modul Wisuda & Foto Ijazah: /api/wisuda/*
class WisudaService {
  WisudaService(this._api);

  final ApiClient _api;

  /// Ambil metadata halaman upload dan status foto ijazah saat ini
  Future<dynamic> getFotoIjazah() => _api.get('/api/wisuda/foto-ijazah');

  /// Upload berkas foto ijazah (multipart/form-data)
  Future<dynamic> uploadFotoIjazahBytes(
    List<int> bytes,
    String filename, {
    String contentType = 'image/jpeg',
  }) {
    final formData = FormData.fromMap({
      'photo': MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: DioMediaType.parse(contentType),
      ),
    });
    return _api.post('/api/wisuda/foto-ijazah/upload', body: formData);
  }

  /// Stream binary foto tersimpan dengan otentikasi X-Session-Id
  Future<List<int>> getPreviewFotoBytes() =>
      _api.getBytes('/api/wisuda/foto-ijazah/preview');
}

