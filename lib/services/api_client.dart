import 'package:dio/dio.dart';

import '../config/api_config.dart';
import 'session_store.dart';

/// Exception aplikasi dengan pesan yang ramah pengguna.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.isAuthError = false});

  final String message;
  final int? statusCode;
  final bool isAuthError;

  @override
  String toString() => message;
}

/// Klien HTTP tunggal: base url, timeout, header session, dan
/// pemetaan error ke [ApiException] berbahasa Indonesia.
class ApiClient {
  ApiClient(this._store) {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        headers: {'Accept': 'application/json'},
        // Biarkan 4xx masuk sebagai respons biasa supaya pesan error
        // dari server bisa dibaca, 5xx tetap jadi DioException.
        validateStatus: (code) => code != null && code < 500,
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final sid = _store.sessionIdCached;
          if (sid != null && sid.isNotEmpty) {
            options.headers[ApiConfig.sessionHeader] = sid;
          }
          handler.next(options);
        },
      ),
    );
  }

  final SessionStore _store;
  late final Dio _dio;

  /// Dipanggil saat terdeteksi sesi berakhir (HTTP 401).
  void Function()? onUnauthorized;

  // -------------------------------------------------------------- HTTP

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    try {
      return _unwrap(await _dio.get(path, queryParameters: query));
    } catch (e) {
      throw _wrapError(e);
    }
  }

  Future<dynamic> post(String path,
      {Object? body, Map<String, dynamic>? query}) async {
    try {
      return _unwrap(await _dio.post(path, data: body, queryParameters: query));
    } catch (e) {
      throw _wrapError(e);
    }
  }

  Future<dynamic> patch(String path,
      {Object? body, Map<String, dynamic>? query}) async {
    try {
      return _unwrap(
          await _dio.patch(path, data: body, queryParameters: query));
    } catch (e) {
      throw _wrapError(e);
    }
  }

  Future<dynamic> delete(String path,
      {Object? body, Map<String, dynamic>? query}) async {
    try {
      return _unwrap(
          await _dio.delete(path, data: body, queryParameters: query));
    } catch (e) {
      throw _wrapError(e);
    }
  }

  // ------------------------------------------------------------ helper

  dynamic _unwrap(Response resp) {
    final code = resp.statusCode ?? 0;
    final data = resp.data;

    if (code == 401) {
      final msg =
          _msgOf(data) ?? 'Sesi berakhir. Silakan login kembali.';
      onUnauthorized?.call();
      throw ApiException(msg, statusCode: 401, isAuthError: true);
    }
    if (code >= 400) {
      throw ApiException(
        _msgOf(data) ?? 'Permintaan gagal (HTTP $code).',
        statusCode: code,
      );
    }
    return data;
  }

  String? _msgOf(dynamic data) {
    if (data is Map) {
      for (final key in ['message', 'error', 'msg']) {
        final v = data[key];
        if (v is String && v.trim().isNotEmpty) return v;
      }
    }
    return null;
  }

  ApiException _wrapError(Object e) {
    if (e is ApiException) return e;
    if (e is DioException) {
      final resp = e.response;
      if (resp != null) {
        final code = resp.statusCode ?? 0;
        if (code == 401) {
          onUnauthorized?.call();
          return ApiException(
            _msgOf(resp.data) ?? 'Sesi berakhir. Silakan login kembali.',
            statusCode: 401,
            isAuthError: true,
          );
        }
        return ApiException(
          _msgOf(resp.data) ?? 'Terjadi kesalahan pada server (HTTP $code).',
          statusCode: code,
        );
      }
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return ApiException(
              'Koneksi timeout. Periksa jaringan Anda lalu coba lagi.');
        case DioExceptionType.cancel:
          return ApiException('Permintaan dibatalkan.');
        default:
          return ApiException(
              'Tidak dapat terhubung ke server. Periksa koneksi internet '
              'atau pastikan API aktif di ${ApiConfig.baseUrl}.');
      }
    }
    return ApiException('Terjadi kesalahan yang tidak diketahui.');
  }
}
