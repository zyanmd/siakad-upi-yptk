import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

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
        headers: {
          'Accept': 'application/json',
          // Header User-Agent dilarang (forbidden header) di browser.
          // Hanya dikirim pada platform non-web agar tidak menggagalkan
          // request / memicu preflight CORS saat berjalan di Chrome.
          if (!kIsWeb)
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36 SiakadApp/1.0',
        },
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
        onError: (DioException error, handler) async {
          final statusCode = error.response?.statusCode;
          final extra = error.requestOptions.extra;
          final retryCount = (extra['retry_count'] as int?) ?? 0;

          // Jika server 502 / 503 / 504 (LiteSpeed / Passenger cold start atau busy),
          // lakukan retry otomatis 1x setelah 1.2 detik agar pengguna tidak terganggu.
          if ((statusCode == 500 || statusCode == 502 || statusCode == 503 || statusCode == 504 || statusCode == 522) &&
              retryCount < 2) {
            extra['retry_count'] = retryCount + 1;
            await Future.delayed(const Duration(milliseconds: 1500));
            try {
              final response = await _dio.fetch(error.requestOptions);
              return handler.resolve(response);
            } catch (e) {
              if (e is DioException) {
                return handler.next(e);
              }
            }
          }
          handler.next(error);
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

  Future<List<int>> getBytes(String path, {Map<String, dynamic>? query}) async {
    try {
      final resp = await _dio.get<List<int>>(
        path,
        queryParameters: query,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
        ),
      );
      final code = resp.statusCode ?? 0;
      if (code == 401) {
        onUnauthorized?.call();
        throw ApiException('Sesi berakhir. Silakan login kembali.',
            statusCode: 401, isAuthError: true);
      }
      if (code >= 400) {
        throw ApiException('Permintaan unduh gagal (HTTP $code).',
            statusCode: code);
      }
      final data = resp.data ?? <int>[];
      final contentType = resp.headers.value('content-type') ?? '';
      if (contentType.contains('application/json') ||
          (data.isNotEmpty && data.first == 0x7B /* '{' */)) {
        try {
          final str = utf8.decode(data);
          final jsonMap = jsonDecode(str);
          if (jsonMap is Map) {
            final msg = _msgOf(jsonMap);
            if (_isSessionExpiredMessage(msg)) {
              onUnauthorized?.call();
              throw ApiException(
                  msg ?? 'Sesi berakhir. Silakan login kembali.',
                  statusCode: 401,
                  isAuthError: true);
            }
            if (jsonMap['success'] == false || msg != null) {
              throw ApiException(msg ?? 'Gagal mengunduh berkas.');
            }
          }
        } catch (e) {
          if (e is ApiException) rethrow;
        }
      }
      return data;
    } catch (e) {
      throw _wrapError(e);
    }
  }

  // ------------------------------------------------------------ helper

  bool _isSessionExpiredMessage(String? msg) {
    if (msg == null || msg.trim().isEmpty) return false;
    final lower = msg.toLowerCase();
    return lower.contains('session tidak valid') ||
        lower.contains('sesi berakhir') ||
        lower.contains('sesi habis') ||
        lower.contains('kadaluarsa') ||
        lower.contains('kedaluwarsa') ||
        lower.contains('login ulang') ||
        lower.contains('session rusak') ||
        lower.contains('session expired') ||
        lower.contains('session_expired') ||
        lower.contains('session siakad') ||
        lower.contains('x-session-id wajib') ||
        lower.contains('unauthorized') ||
        lower.contains('unauthenticated') ||
        lower.contains('login - siakad upi yptk') ||
        lower.contains('silakan login') ||
        lower.contains('belum login');
  }

  dynamic _unwrap(Response resp) {
    final code = resp.statusCode ?? 0;
    final data = resp.data;
    final msg = _msgOf(data);

    final bool isSessionExpired = code == 401 ||
        (data is Map &&
            (data['session_expired'] == true ||
                data['is_auth_error'] == true ||
                (data['success'] == false && _isSessionExpiredMessage(msg)) ||
                _isSessionExpiredMessage(msg)));

    if (isSessionExpired) {
      final text = msg ?? 'Sesi berakhir. Silakan login kembali.';
      onUnauthorized?.call();
      throw ApiException(text, statusCode: 401, isAuthError: true);
    }
    if (code >= 400) {
      throw ApiException(
        msg ?? 'Permintaan gagal (HTTP $code).',
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
        final msg = _msgOf(resp.data);
        if (code == 401 || _isSessionExpiredMessage(msg)) {
          onUnauthorized?.call();
          return ApiException(
            msg ?? 'Sesi berakhir. Silakan login kembali.',
            statusCode: 401,
            isAuthError: true,
          );
        }
        if (code == 503) {
          return ApiException(
            msg ?? 'Server SIAKAD sedang sibuk atau sedang memuat ulang proses (HTTP 503). Silakan coba sesaat lagi.',
            statusCode: 503,
          );
        }
        if (code == 502 || code == 504 || code == 522) {
          return ApiException(
            msg ?? 'Koneksi ke gateway SIAKAD kampus timeout / terputus (HTTP $code). Silakan coba lagi.',
            statusCode: code,
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
          // Di browser (web), kegagalan koneksi hampir selalu karena
          // permintaan diblokir CORS oleh server, bukan karena internet.
          if (kIsWeb) {
            return ApiException(
                'Permintaan diblokir oleh browser (CORS). Server belum mengizinkan akses dari aplikasi web ini. Hubungi pengembang backend untuk mengaktifkan header CORS.');
          }
          return ApiException(
              'Tidak dapat terhubung ke server. Periksa koneksi internet Anda lalu coba lagi.');
      }
    }
    return ApiException('Terjadi kesalahan yang tidak diketahui.');
  }
}
