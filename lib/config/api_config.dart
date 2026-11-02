/// Konfigurasi utama koneksi ke SIAKAD Scraper API.
///
/// Ubah [baseUrl] di sini bila alamat API berpindah.
class ApiConfig {
  /// Base URL API (tanpa trailing slash).
  static const String baseUrl = 'http://103.119.237.37:2027';

  /// Header yang dipakai untuk mengirim session id.
  static const String sessionHeader = 'X-Session-Id';

  /// Batas waktu koneksi awal.
  static const Duration connectTimeout = Duration(seconds: 25);

  /// Batas waktu menunggu respons (scraper bisa lambat).
  static const Duration receiveTimeout = Duration(seconds: 60);
}
