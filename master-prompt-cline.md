# Master Implementation Prompt untuk Cline AI

Salin dan gunakan prompt di bawah ini untuk menginstruksikan **Cline** membangun seluruh aplikasi Flutter Android "Pangkalan Cerdas" secara bertahap dari awal hingga selesai:

---

### PROMPT MASTER UNTUK CLINE:

"Halo Cline! Saya ingin Anda membangun aplikasi Flutter Android lengkap bernama **Pangkalan Cerdas LPG 3Kg Mobile v6.0**. Silakan baca dan patuhi aturan arsitektur di clinerules.md, PRD-Pangkalan-Cerdas-Mobile.md, dan TRD-Pangkalan-Cerdas-Mobile.md.

Kerjakan pembuatan aplikasi ini secara bertahap sesuai 7 FASE berikut:

#### FASE 1: INITIALIZATION & DEPENDENCIES
1. Buat struktur folder Flutter berkonsep Clean Architecture:
   - lib/models/
   - lib/services/
   - lib/providers/
   - lib/ui/screens/
   - lib/ui/widgets/
2. Konfigurasikan pubspec.yaml dengan dependency berikut:
   flutter_inappwebview, dio, provider, cloud_firestore, firebase_core, flutter_secure_storage, excel, path_provider, permission_handler, flutter_local_notifications.

#### FASE 2: WEBVIEW & BEARER TOKEN INTERCEPTOR
1. Buat layar WebViewScreen menggunakan InAppWebView yang memuat portal resmi https://subsiditepatlpg.mypertamina.id.
2. Pasang request interceptor untuk mencegat header Authorization yang mengandung Bearer <token>.
3. Simpan token tersebut ke FlutterSecureStorage.
4. Setelah token berhasil ditangkap, panggil API GET https://api-map.my-pertamina.id/general/products/v1/products/user menggunakan Dio Client.
5. Ekstrak dan simpan data registrationId, storeName, stockAvailable, dan sold.

#### FASE 3: FIREBASE FIRESTORE & DATA MODELS
1. Inisialisasi Firebase Firestore dengan persistenceEnabled: true untuk fitur Offline Persistence.
2. Buat data model Dart untuk Pelanggan, LogTransaksi, dan Pangkalan beserta fungsi fromJson() dan toJson().
3. Buat FirebaseService untuk CRUD data pelanggan dan pencatatan log transaksi yang terisolasi berdasarkan registrationId.

#### FASE 4: BUSINESS RULES ENGINE (LOCAL QUOTA VALIDATION)
1. Buat QuotaRuleEngine class.
2. Implementasikan logika pengecekan kuota harian lokal:
   - Kategori **Rumah Tangga**: Maksimal **2 tabung/hari** per NIK.
   - Kategori **UMKM**: Maksimal **5 tabung/hari** per NIK.
3. Pastikan transaksi yang melanggar aturan harian lokal langsung dibatalkan sebelum memanggil API eksternal.

#### FASE 5: TRANSAKSI BATCH & SMART RETRY ENGINE
1. Buat TransactionQueueProvider untuk mengelola antrean transaksi massal.
2. Panggil API Verifikasi NIK (GET https://api-map.my-pertamina.id/general/customer-service/v1/verify-nik-transaction-manual?nationalityId={nik}).
3. Catat hasil transaksi ke log_transaksi Firebase dengan warna status yang sesuai (Hijau untuk Berhasil, Merah untuk Gagal + Alasan Error).
4. Buat fitur **Single Retry** dan **Batch Retry** untuk memproses ulang transaksi gagal.

#### FASE 6: WEB HISTORY AUTO-SYNC & EXCEL ENGINE
1. Buat ExcelService untuk membaca file .xlsx master pelanggan dari folder Download HP dan mengimpornya ke Firestore.
2. Buat fungsi ekspor laporan transaksi ke file .xlsx di folder Download HP.
3. Buat fungsi syncWebHistory() yang memanggil API GET https://api-map.my-pertamina.id/general/v3/transactions/report untuk menarik transaksi resmi dari web MyPertamina.

#### FASE 7: DASHBOARD UI & INTEGRASI UTAMA
1. Buat DashboardScreen yang menampilkan:
   - Header Profil (storeName, registrationId, stockAvailable).
   - Widget Status Token (Terdeteksi / Kadaluarsa).
   - Tabel Log Transaksi (Filter Berhasil/Gagal).
   - Tombol Aksi: Import Pelanggan, Eksekusi Antrean, Retry All, Ekspor Excel.
2. Pastikan seluruh aliran data tersambung dengan rapi dan bebas dari error/warning linter."
