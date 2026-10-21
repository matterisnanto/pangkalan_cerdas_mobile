# Representasi Lengkap Arsitektur, Tampilan, dan Fungsi Aplikasi Saat Ini

> Audit statis seluruh `lib/` proyek Flutter. Total: 39 berkas Dart.

## 1. Struktur dan State Management

### Struktur folder

```text
lib/
├── main.dart
├── models/       # log_transaksi.dart, mypertamina_models.dart, pangkalan.dart, pelanggan*.dart
├── providers/    # auth_provider.dart, theme_provider.dart, transaction_queue_provider.dart
├── services/     # API, Firebase, Excel, secure storage, quota, automation, notification
└── ui/
    ├── screens/  # dashboard, home, pelanggan, settings, transaksi, webview
    ├── theme/    # app_theme.dart
    └── widgets/  # komponen kartu, tabel, form, queue, token, tema
```

### Bootstrap dan navigasi

`main.dart` menginisialisasi Firebase, Firestore offline persistence, notification service, lalu memuat tema dari `SharedPreferences`. `MultiProvider` menyediakan `AuthProvider` dan `TransactionQueueProvider`; `ThemeProvider` disediakan melalui `ChangeNotifierProvider.value`. Navigasi memakai `IndexedStack` berisi lima tab: WebView, transaksi, pelanggan, dashboard, settings.

Konsekuensi `IndexedStack`: state tab dipertahankan; WebView tetap hidup. `WebViewScreen` juga memakai `AutomaticKeepAliveClientMixin`.

### Provider

| Provider | Fungsi |
|---|---|
| `AuthProvider` | Token, validasi JWT, profil pangkalan, stok, status sesi, `ApiClient`. |
| `ThemeProvider` | Light/Dark mode global; persistensi `SharedPreferences`. |
| `TransactionQueueProvider` | Antrean, pause/resume, submit transaksi, hasil, progres, stok, token expired. |

Pemakaian: `ChangeNotifierProvider`, `Consumer`, `Consumer2`, `context.read`, `Provider.of(..., listen: false)`. `Selector` belum digunakan.

### Penyimpanan

- **FlutterSecureStorage**: `bearer_token`, `registration_id`, `store_name`, delay transaksi, profil pangkalan. Android memakai encrypted shared preferences.
- **SharedPreferences**: hanya `is_dark_mode`.
- **Firestore**: profil pangkalan, pelanggan, log transaksi, kuota, transaksi hasil interceptor. Offline persistence aktif.

Catatan: `PelangganService` menggunakan koleksi root `pelanggan`; scope `registrationId` perlu diverifikasi konsisten pada semua query.

## 2. Arsitektur Lima Layar

### Layar 1 — Portal WebView

File: `lib/ui/screens/webview_screen.dart`.

- Portal: `https://subsiditepatlpg.mypertamina.id/`.
- Full area memakai `Positioned.fill`.
- `SafeArea(top: true, bottom: false)` melindungi status bar; belum immersive full screen Android eksplisit.
- JavaScript, DOM storage, cache, shared cookies, `useShouldInterceptRequest`, dan `useOnLoadResource` aktif.
- User script diinjeksi pada `AT_DOCUMENT_START`.

#### Token interceptor

Interceptor JavaScript membungkus `fetch` dan `XMLHttpRequest.setRequestHeader`, mencari `Authorization: Bearer <token>`, lalu memanggil handler `onTokenCaptured`. Token masuk ke `AuthProvider`, disimpan di `FlutterSecureStorage`, lalu memicu fetch profil dan stok.

Efektif untuk fetch/XHR standar. Batasan: request non-fetch/XHR atau perubahan struktur portal bisa tidak tertangkap; `_tokenCaptured` dapat mengabaikan rotasi token pada instance WebView yang sama.

#### Auto-capture transaksi manual

Bridge membungkus fetch/XHR response, memproses POST ke `/general/v2/transactions` atau `/general/v3/transactions`, lalu mengirim payload melalui `myPertaminaTransaction` ke Firestore.

Risiko: tidak ada deduplikasi; parse error ditelan; retry/response ganda dapat membuat duplikasi; payload mentah berpotensi menyimpan data sensitif.

### Layar 2 — Riwayat Transaksi dan Sisa Kuota

File: `lib/ui/screens/transaksi_screen.dart`.

Konten: daftar pelanggan, kuota harian, tombol sinkronisasi, riwayat transaksi, empty/error/401 state.

Saat load:

```text
Firestore getAllLogTransaksi + getAllPelanggan (paralel)
→ GET /general/v3/transactions/report
→ konversi TransactionReceiptModel ke LogTransaksi
→ gabungkan hasil
```

Default report: awal bulan sampai hari ini, `sort=latest`, `search=`.

Mapping report: transaction ID, NIK, nama, kategori, jumlah, status, unique key/ref, registration ID, timestamp.

Loading memakai `try/catch/finally`; spinner berhenti pada semua jalur. 401 menampilkan `Sesi token berakhir` dan tombol `Login Ulang via WebView`. Empty state tersedia.

Risiko: hasil Firestore dan API digabung tanpa deduplikasi atau sorting akhir; report belum pagination; sinkronisasi satu pelanggan memanggil reload penuh dan mengulang report API.

### Layar 3 — Pelanggan dan Smart Queue

File: `lib/ui/screens/pelanggan_screen.dart`.

Fitur: master pelanggan, search NIK/nama, filter kategori, tambah/edit/hapus/detail, riwayat per pelanggan, import/export Excel.

Import:

```text
FilePicker (.xlsx/.csv)
→ parsing Excel
→ NIK minimal 16 karakter
→ batch verify MyPertamina
→ simpan Firestore
```

`BatchVerificationService` memakai `Future.wait` untuk semua pelanggan. Risiko: request simultan besar, rate limit 429, memori dan tidak ada concurrency limit/retry terkontrol.

#### Aturan antrean

`AutomationService` mengimplementasikan:

- Skip `sisaKuotaHarian <= 0` atau `sisaKuotaBulanan <= 0`.
- Pelanggan pangkalan sama dilewati bila transaksi terakhir berjarak kurang dari 2 hari.
- Lintas pangkalan tetap eligible bila kuota tersedia.
- Prioritas: sisa kuota harian terkecil.
- Jumlah antrean dibatasi `targetStock`.

`QuotaRuleEngine` mengimplementasikan batas harian:

```text
Rumah Tangga: 2 tabung/hari
UMKM:         5 tabung/hari
```

Validasi menghitung transaksi sukses NIK pada hari berjalan. Kategori selain string persis `UMKM` diperlakukan sebagai Rumah Tangga; normalisasi kategori perlu konsisten.

Perlu verifikasi bahwa tombol otomatisasi dashboard benar-benar selalu memakai `AutomationService`, bukan hanya antrean manual.

## 3. Layar 4 — Dashboard Analytics dan Warning

File: `lib/ui/screens/dashboard_screen.dart`.

Tersedia: profil pangkalan, token status, sisa stok, penjualan hari ini, total sukses, antrean aktif, filter transaksi, tabel transaksi, import/export, sync, pause/resume, retry.

Belum tersedia: `PieChart`, grafik penerimaan/penyaluran stok, agregasi bulanan per NIK, dan warning pelanggan dengan akumulasi `>= 5 tabung/bulan`. Dashboard saat ini masih operational dashboard berbasis metric card dan tabel.

## 4. Layar 5 — Settings

File: `lib/ui/screens/settings_screen.dart`.

- Theme switcher Light/Dark global memakai `ThemeProvider` dan `SharedPreferences`.
- Profil pangkalan: nama, `registrationId`, stok, penjualan.
- Status token dan jalur login ulang WebView.
- Delay transaksi tersimpan di secure storage dan dibatasi 2–5 detik.
- Logout menghapus secure storage; cookie WebView belum terlihat dibersihkan.

## 5. Integrasi API MyPertamina

Base URL: `https://api-map.my-pertamina.id`.

`ApiClient` otomatis menambahkan `Authorization: Bearer <token>`, `Origin: https://subsiditepatlpg.mypertamina.id`, `Referer: https://subsiditepatlpg.mypertamina.id/`, dan header `Accept`/`User-Agent`.

### Endpoint aktif

| Method | Endpoint | Fungsi |
|---|---|---|
| POST | `/general/v3/transactions` | Submit transaksi |
| GET | `/general/products/v1/products/user` | Produk/stok |
| GET | `/general/v1/users/profile` | Profil pangkalan |
| GET | `/general/transactions/v1/summary` | Ringkasan transaksi |
| GET | `/general/v3/transactions/report` | Report transaksi |
| GET | `/general/customer-service/v1/verify-nik` | Verifikasi NIK |
| GET | `/general/v5/customers/{nik}/quota` | Kuota pelanggan |
| GET | `/general/v1/transactions/{transactionId}` | Detail transaksi |
| GET | `/general/v1/transactions/logbook` | Logbook periode |
| GET | `/general/customer-service/v1/verify-nik-transaction-manual` | Verifikasi transaksi manual |

Catatan: requirement menyebut `/v1/users/profile` dan `/verify-nik`; implementasi aktual memakai prefix `/general/...` lengkap.

## 6. Bottleneck dan Error Handling

### Infinite loading

`TransaksiScreen` sudah memakai `finally` dan aman terhadap exception utama. `DashboardScreen.loadLogs()` masih memanggil `setState` akhir tanpa `mounted` guard dan menelan error.

### Redundant calls

- `onTokenCaptured` menjalankan fetch profile dan stok paralel; dapat menghasilkan rebuild ganda bila token tertangkap berulang.
- `_syncQuota` memuat ulang seluruh pelanggan, log, dan report setelah update satu pelanggan.
- `IndexedStack` mempertahankan beberapa screen dan state sekaligus.
- `ApiClient` membaca secure storage pada setiap request; aman, tetapi menambah operasi async.

### Memory/performance

- `fetchReport()` memuat seluruh report ke memori tanpa pagination.
- `TransaksiScreen` membangun semua transaksi dalam list children, bukan `ListView.builder`.
- Batch verification memakai `Future.wait` tanpa pembatas concurrency.
- WebView tetap hidup sepanjang `IndexedStack`; cache, cookies, bridge, dan JavaScript tetap aktif.
- `TextEditingController` pada `PelangganScreen` sudah di-dispose.
- Tidak ditemukan `Timer` aktif.

### Error yang sudah ditangani

Firebase/notification initialization; Dio timeout, 401, 403, 429, server error; API report; import/export; batch verification per pelanggan; submit transaksi individual; empty/error/token-expired UI.

### Error handling yang masih lemah

- `AutomationService` tidak membungkus fetch Firestore.
- `loadTodayLogs()` tidak memiliki `try/catch`.
- JavaScript bridge menelan parse error.
- Batch verification belum retry/concurrency limit/cancellation.
- Callback token expired berpotensi dipanggil berkali-kali.
- Tidak ada deduplikasi transaksi hasil merge Firestore/API.

## 7. Kesimpulan dan Prioritas

Fondasi aplikasi mencakup Flutter + Provider, Dio, Secure Storage, Firestore offline-first, WebView, Excel, quota engine, dan transaction queue. Alur operasional utama tersedia.

Prioritas tinggi:

1. Deduplikasi merge Firestore dan API report.
2. Pagination atau pembatasan periode report.
3. Concurrency limit dan retry batch verification.
4. Verifikasi scope `registrationId` seluruh query pelanggan.
5. Implementasi warning akumulasi `>= 5 tabung/bulan`.
6. Implementasi pie chart dan grafik stok.
7. Debounce token-expired callback.
8. Tambahkan `mounted` guard dan logging pada async flow dashboard.
9. Bersihkan cookie WebView saat logout bila logout harus memutus sesi portal.
10. Gunakan `ListView.builder` untuk volume transaksi besar.

## 8. Verifikasi Audit

- Sumber: seluruh berkas di `lib/`.
- Temuan utama: report v3, fallback Firestore, loading `finally`, 401 flow, dan smart queue dasar tersedia.
- Gap utama: analytics chart dan warning bulanan belum tersedia.

