# Product Requirement Document (PRD)
## Aplikasi Mobile "Pangkalan Cerdas LPG 3Kg" v6.0 (Android)

---

## 1. Dokumen Control & Metadata
- **Nama Produk**: Pangkalan Cerdas Mobile
- **Versi**: 6.0-Android
- **Tanggal Release Target**: Q4 2026
- **Target Platform**: Android (Smartphone & Tablet, OS Android 8.0+)
- **Target Pengguna**: Pengelola Pangkalan LPG 3kg (Single Manager untuk 3 Pangkalan)

---

## 2. Latar Belakang & Ringkasan Eksekutif
Sistem Pangkalan Cerdas v5.0 sebelumnya berjalan sebagai aplikasi Command Line Interface (CLI) berbasis Node.js. Walaupun berfungsi dengan baik, operasional CLI memerlukan komputer/laptop, penyalinan token Bearer secara manual/bridge, serta kurang praktis untuk operasional lapangan.

Sistem Pangkalan Cerdas v6.0 Mobile bertransisi menjadi **Aplikasi Android Khusus (Flutter)** yang menggabungkan WebView cerdas (untuk mengakses portal resmi Subsidi Tepat MyPertamina) dengan engine otomatisasi lokal dan database cloud terpusat (Firebase Firestore). Aplikasi ini dirancang **tanpa konfigurasi manual (zero-configuration)** untuk identifikasi pangkalan, mendukung operasional 3 pangkalan sekaligus, serta menerapkan aturan kuota transaksi yang ketat secara otomatis.

---

## 3. Tujuan Utama & Key Results (OKRs)
1. **Otomatisasi 100% Token Bearer**: Menghilangkan penyalinan token manual secara total melalui pencegatan HTTP header otomatis di WebView.
2. **Zero-Configuration Base Identification**: Mengidentifikasi pangkalan secara otomatis lewat API profil pengguna tanpa dropdown/role selector manual.
3. **Efisiensi Waktu Transaksi**: Memangkas waktu verifikasi dan pencatatan transaksi batch hingga 80%.
4. **Kepatuhan Aturan Kuota**: Menjamin 0% pelanggaran batas harian (Rumah Tangga max 2 tabung/hari, UMKM max 5 tabung/hari).
5. **Multi-Device & Offline First**: Data tersinkronisasi antar-HP secara real-time via Firebase, dan tetap dapat mengantre transaksi saat koneksi internet terputus.

---

## 4. Personas & Alur Kerja Pengguna
- **Persona Utama**: Pengelola Pangkalan LPG 3kg (1 Pengelola untuk 3 Pangkalan).
- **Skenario Operasional**:
  1. Pengelola membuka aplikasi di HP/Tablet Android.
  2. Pengelola melakukan login di tab WebView MyPertamina (`https://subsiditepatlpg.mypertamina.id`).
  3. Aplikasi mencegat token JWT Bearer, memanggil API profil pengguna, dan mengeset identitas pangkalan aktif (`registrationId`, `storeName`, `stockAvailable`).
  4. Pengelola beralih ke tab Dashboard / Transaksi untuk:
     - Melakukan transaksi langsung per NIK.
     - Memproses antrean transaksi batch dari daftar pelanggan.
     - Memantau log berhasil/gagal dan melakukan *retry*.
     - Mengunduh laporan Excel (`.xlsx`) ke folder Download HP.

---

## 5. Spesifikasi Fitur & Persyaratan Fungsional (FR)

### 5.1 WebView Cerdas & Interceptor Token
- **FR-1.1**: Aplikasi wajib menyediakan WebView terintegrasi memuat `https://subsiditepatlpg.mypertamina.id`.
- **FR-1.2**: Sistem secara otomatis mencegat header `Authorization: Bearer <token>` dari setiap request outgoing.
- **FR-1.3**: Setelah token terdeteksi, sistem memanggil API `GET /general/products/v1/products/user` untuk mengambil:
  - `registrationId` (ID unik pangkalan)
  - `storeName` (Nama pangkalan)
  - `stockAvailable` (Sisa stok tabung)
  - `sold` (Total tabung terjual)
- **FR-1.4**: Token disimpan di Encrypted Storage lokal dan diperbarui otomatis jika sesi login diperbarui.

### 5.2 Pengelolaan Multi-Pangkalan Tanpa Role Selector
- **FR-2.1**: Tidak ada tombol pemilih pangkalan manual (*no role/dropdown selector*).
- **FR-2.2**: Seluruh data pelanggan, transaksi, dan log dipisahkan berdasarkan `registrationId` yang terdeteksi otomatis dari token aktif.
- **FR-2.3**: Pengelola dapat melayani 3 pangkalan berbeda hanya dengan berpindah akun login di WebView; aplikasi menyesuaikan konteks pangkalan secara otomatis.

### 5.3 Engine Validasi Kuota Lokal
- **FR-3.1**: Sebelum memanggil API MyPertamina, sistem WAJIB mengecek batasan harian lokal:
  - **Kategori Rumah Tangga (RT)**: Maksimal **2 tabung / hari** per NIK.
  - **Kategori UMKM / Usaha Mikro**: Maksimal **5 tabung / hari** per NIK.
- **FR-3.2**: Transaksi yang melanggar batasan lokal langsung dibatalkan dengan status `GAGAL` dan alasan `"Melebihi Kuota Harian Lokal (RT max 2 / UMKM max 5)"` tanpa mengirim request ke server pusat.
- **FR-3.3**: Transaksi yang lolos dilanjutkan ke API verifikasi NIK MyPertamina (`GET /general/customer-service/v1/verify-nik-transaction-manual`).

### 5.4 Master Data Pelanggan & Synchronized Storage
- **FR-4.1**: Menyimpan master data pelanggan terpusat menggunakan Firebase Cloud Firestore dengan *Offline Persistence* aktif.
- **FR-4.2**: Atribut pelanggan meliputi: `nik` (16 digit), `nama`, `kategori` (RT/UMKM), `registrationId`, `terakhirTransaksi`, `created_at`.
- **FR-4.3**: Dukungan Impor & Ekspor file Excel (`.xlsx`) ke/dari folder `Download` penyimpanan internal Android.
- **FR-4.4**: Pencarian instan berdasarkan NIK atau Nama dengan filter kategori.

### 5.5 Eksekusi Antrean Batch Transaksi
- **FR-5.1**: Fitur pemrosesan transaksi massal (batch) dengan indikator visual kemajuan (*progress bar* X/Y selesai).
- **FR-5.2**: Pemrosesan transaksi dilakukan secara sekuensial dengan jeda waktu aman (*rate limiting delay*) untuk mencegah pemblokiran IP/Rate Limit (HTTP 429).

### 5.6 Log Transaksi, Detail Error, & Smart Retry
- **FR-6.1**: Tampilan Log Terpisah:
  - **Log Berhasil (Hijau)**: NIK, Nama, Kategori, Tabung, RefNo MyPertamina, Timestamp.
  - **Log Gagal (Merah)**: NIK, Nama, Kategori, Detail Alasan Error.
- **FR-6.2**: Fitur *Smart Retry*:
  - **Single Retry**: Mencoba ulang 1 transaksi gagal.
  - **Batch Retry**: Mencoba ulang seluruh transaksi gagal dalam 1 kali tekan.
  - **Handling Token Expired**: Jika error disebabkan token expired, aplikasi memberikan notifikasi untuk refresh WebView, lalu melanjutkan retry secara otomatis.

### 5.7 Auto-Sync Riwayat Web & Ekspor Laporan
- **FR-7.1**: Sinkronisasi riwayat transaksi dari web resmi secara periodik via endpoint `GET /general/v3/transactions/report` (parameter `startDate`, `endDate`, `sort=latest`).
- **FR-7.2**: Generasi laporan transaksi berkala (.xlsx) yang tersimpan otomatis di folder `Download` HP dan opsi backup ke Google Drive API.

### 5.8 Sistem Notifikasi
- **FR-8.1**: Local Notification untuk status progress transaksi batch dan peringatan Sesi Token Kadaluarsa.
- **FR-8.2**: Cloud Notification (Firebase FCM) jika sisa stok pangkalan (`stockAvailable`) di bawah 10 tabung.

---

## 6. Persyaratan Non-Fungsional (NFR)
- **Kinerja**: Waktu eksekusi verifikasi per NIK < 2 detik.
- **Ketersediaan**: Offline-first architecture, sinkronisasi otomatis begitu terhubung internet.
- **Keamanan**: EncryptedSharedPreferences untuk token, TLS 1.3/HTTPS, Firebase Security Rules per `registrationId`.
- **UI/UX**: Responsive untuk Android Smartphone dan Tablet, Touch-Friendly controls.

---

## 7. Metrik Keberhasilan & KPI
- **0 Manual Token Entry**: 100% token didapatkan otomatis via WebView interceptor.
- **0 Over-Quota Violation**: Terbukti menolak transaksi > 2 tabung (RT) dan > 5 tabung (UMKM).
- **100% Data Sync Consistency**: Data transaksi di Firebase identik dengan data portal resmi Subsidi Tepat MyPertamina.
