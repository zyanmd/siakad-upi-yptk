# SIAKAD Kampus — Aplikasi Flutter

Aplikasi SIAKAD mahasiswa modern untuk **SIAKAD UPI YPTK Scraper API**, dengan
tema indigo kampus + aksen kuning, mode terang/gelap, dan seluruh modul
akademik: Dashboard, KRS, Jadwal, Presensi, Materi, Kartu Ujian, KHS,
Transkrip, Kalender Akademik, Tagihan, dan Profil.

![stack](https://img.shields.io/badge/Flutter-3.22%2B-02569B) ![state](https://img.shields.io/badge/State-Provider-283593) ![api](https://img.shields.io/badge/API-SIAKAD%20Scraper-FFB300)

---

## Fitur

| Modul | Kemampuan |
|---|---|
| Dashboard | Sambutan + foto inisial, ringkasan IPK/IPS/SKS/Semester, pengumuman, grid layanan, CTA tagihan |
| Login | NIM + password SIAKAD, simpan NIM, auto-restore sesi, banner sesi berakhir |
| KRS | Lihat daftar MK diambil, status KRS, ambil MK (sheet + pencarian), hapus MK, detail jadwal MK, kurikulum, cetak KRS |
| Jadwal | Jadwal per hari (terurut Senin-Minggu), chip jam/ruang/kelas, detail sesi, cetak jadwal |
| Presensi | Rekap hadir/izin/sakit/alpa + persentase dengan progress bar, detail per MK |
| Materi | Daftar kelas -> daftar materi, buka tautan file |
| Kartu Ujian | Toggle UTS/UAS, jadwal ujian (tanggal, jam, ruang, no. kursi), cetak kartu |
| KHS | Pilih semester, ringkasan IP/IPK/SKS, daftar nilai dengan warna grade, cetak KHS |
| Transkrip | Ringkasan IPK besar, tren IP per semester (bar sederhana), daftar nilai, cetak transkrip |
| Kalender | Pilih tahun ajaran, agenda, detail agenda, cetak |
| Tagihan | 4 tab: Tagihan (total + daftar invoice + detail), Virtual Account (salin VA), Riwayat bayar, Status |
| Profil | Info mahasiswa (dari /profil), edit field umum (PATCH), toggle tema Terang/Gelap/Sistem, info sesi, logout |

Halaman-halaman detail memakai **Smart Renderer**: bentuk data scraper yang
dinamis tetap tampil rapi (key-value, nested section, list bernomor), key
berisi token disembunyikan otomatis, link http bisa ditap, dan tekan-lama
untuk menyalin nilai.

## Struktur Proyek

```
siakad_app/
├── pubspec.yaml                       # Dependensi: provider, dio, shared_preferences, url_launcher
├── android/app/src/main/AndroidManifest.xml   # Sudah ada permission INTERNET + queries
└── lib/
    ├── main.dart                      # Entry point + MultiProvider + routing
    ├── config/api_config.dart         # BASE URL API  <== ubah di sini bila perlu
    ├── theme/app_theme.dart           # Tema terang/gelap, palet indigo+kuning
    ├── services/                      # api_client, auth, akademik, tagihan, session store
    ├── state/                         # AuthProvider, ThemeProvider, PeriodeProvider
    ├── utils/                         # format (rupiah/label), smart (parser JSON defensif)
    ├── widgets/                       # AsyncPage, GradientHeader, SmartJson, dll.
    └── screens/                       # Semua halaman aplikasi
```

## Cara Menjalankan

> Butuh Flutter SDK 3.22+ (Dart 3.4+). Folder platform (android/ ios/ penuh)
> sengaja tidak disertakan supaya ZIP-nya ringan dan tidak terikat versi —
> Flutter akan men-generate-nya.

```bash
# 1. Ekstrak ZIP lalu masuk folder
cd siakad_app

# 2. Generate folder platform (android, ios) sesuai versi Flutter Anda
flutter create .

# 3. Ambil dependensi
flutter pub get

# 4. Jalankan (pilih device/emulator)
flutter run
```

> Catatan `flutter create .`: berkas yang sudah ada (lib/, pubspec.yaml,
> AndroidManifest.xml) tidak akan ditimpa, Flutter hanya menambahkan berkas
> platform yang kurang. AndroidManifest.xml sudah disiapkan dengan izin
> INTERNET dan `<queries>` untuk url_launcher.

## Konfigurasi API

Alamat API sudah diarahkan ke deployment berikut (lihat `lib/config/api_config.dart`):

```dart
static const String baseUrl = 'https://z1.pipinipon.site';
```

Autentikasi memakai header `X-Session-Id` yang otomatis disisipkan
`ApiClient` untuk semua request setelah login. Sesi kedaluwarsa (HTTP 401)
otomatis mengembalikan pengguna ke halaman login.

### Pemetaan endpoint yang dipakai

| Layanan | Endpoint |
|---|---|
| Auth | `POST /api/auth/login`, `POST /api/auth/logout` |
| Umum | `/api/akademik/periode`, `/dashboard`, `/profil` (GET/PATCH) |
| KRS | `/krs`, `/krs/status`, `/krs/available`, `/krs/add`, `/krs/{delete_token}` (DELETE), `/krs/jadwal/{token}`, `/krs/kurikulum`, `/krs/cetak-url` |
| Jadwal | `/jadwal/data`, `/jadwal/detail/{token}`, `/jadwal/cetak-url` |
| Presensi | `/presensi/data`, `/presensi/detail/{token}` |
| Materi | `/materi`, `/materi/kelas/{token}` |
| Kartu Ujian | `/kartu-ujian/data?jenis=`, `/kartu-ujian/cetak-url` |
| KHS | `/khs/periode`, `/khs/data?periode=`, `/khs/cetak-url` |
| Transkrip | `/transkrip/data`, `/transkrip/cetak-url` |
| Kalender | `/kalender/data?tahun=`, `/kalender/detail/{token}`, `/kalender/cetak-url/{token}` |
| Tagihan | `/api/tagihan`, `/invoice/{token}`, `/virtual-account`, `/riwayat`, `/status` |

## Catatan Teknis

- **State management**: `Provider` + pola per-halaman (`AsyncPage`) yang
  menangani loading/error/retry/pull-to-refresh secara seragam.
- **Periode global**: dipilih lewat `PeriodeProvider` (dropdown di header),
  perubahannya otomatis memuat ulang halaman yang terbuka.
- **Data scraper yang fleksibel**: util `utils/smart.dart` mencari nilai
  dengan kandidat key (mis. `nama_mk`, `nm_mk`, `mata_kuliah`) sehingga UI
  tetap jalan meski nama field sedikit berubah.
- **Format rupiah otomatis**: field seperti `nominal`, `total`, `denda`
  diformat sebagai Rupiah di seluruh tampilan.
- **Ganti server**: cukup ubah `ApiConfig.baseUrl`.

## Troubleshooting

| Masalah | Solusi |
|---|---|
| "Tidak dapat terhubung ke server" | Pastikan API aktif; buka `https://z1.pipinipon.site/docs` di browser |
| Sering diminta login lagi | TTL sesi server pendek; ini perilaku scraper, aplikasi otomatis kembali ke login |
| Tombol cetak tidak bereaksi | Endpoint cetak perlu token valid; pastikan status KRS/KHS sudah disetujui di siakad |
| Build gagal setelah `flutter create .` | Jalankan `flutter clean` lalu `flutter pub get` |
