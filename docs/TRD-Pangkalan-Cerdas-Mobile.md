# Technical Requirement Document (TRD)
## Aplikasi Mobile "Pangkalan Cerdas LPG 3Kg" v6.0 (Android)

---

## 1. Arsitektur Sistem & Diagram Alur Data

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        APLIKASI FLUTTER ANDROID                         │
├──────────────────────────────────┬──────────────────────────────────────┤
│    TAB 1: INAPPWEBVIEW           │     TAB 2: DASHBOARD & TRANSAKSI     │
│  - Load Portal MyPertamina       │  - Auto Profile Display              │
│  - Intercept Header Authorization│  - Master Data Pelanggan             │
│    (Bearer JWT Token)            │  - Engine Validasi Kuota Lokal       │
└─────────────────┬────────────────┴──────────────────┬───────────────────┘
                  │                                   │
                  ▼                                   ▼
    ┌───────────────────────────┐         ┌──────────────────────────┐
    │  Encrypted Token Storage  │ ──────> │  REST API Client (Dio)   │
    │ (FlutterSecureStorage)    │         └─────────────┬────────────┘
    └───────────────────────────┘                       │
                                                        │
         ┌──────────────────────────────────────────────┴──────────────────────────────┐
         ▼                                              ▼                              ▼
┌─────────────────────────────┐           ┌─────────────────────────────┐    ┌──────────────────┐
│ API User Product / Profile  │           │ API Verifikasi NIK Manual   │    │ API Sync Report  │
│ GET /v1/products/user       │           │ GET /verify-nik-transaction │    │ GET /v3/report   │
└─────────────────────────────┘           └─────────────────────────────┘    └──────────────────┘
         │                                              │                              │
         └──────────────────────────────┬───────────────┴──────────────────────────────┘
                                        ▼
                         ┌──────────────────────────────┐
                         │   Firebase Cloud Firestore   │
                         │ (Offline Persistence Active) │
                         └──────────────────────────────┘
```

---

## 2. Spesifikasi Tech Stack
- **Framework Utama**: Flutter 3.x (Dart 3.x)
- **State Management**: Provider / BLoC Pattern
- **WebView Component**: `flutter_inappwebview` (dengan `shouldInterceptRequest` / `onLoadResource`)
- **HTTP Client**: `dio` (Handling BaseURL, Interceptors, Headers, Retries)
- **Local Secure Storage**: `flutter_secure_storage` (Android EncryptedSharedPreferences)
- **Database Cloud**: `cloud_firestore` & `firebase_core` (dengan `persistenceEnabled: true`)
- **Excel Processor**: `excel` (Parsing & Generasi file `.xlsx`)
- **File System & Permissions**: `path_provider`, `permission_handler`
- **Notifications**: `flutter_local_notifications`, `firebase_messaging`

---

## 3. Spesifikasi API & Integrasi Endpoint

### 3.1 Common HTTP Headers
Setiap request outgoing dari HTTP Client WAJIB menyertakan header berikut:
```json
{
  "Authorization": "Bearer <JWT_TOKEN>",
  "Origin": "https://subsiditepatlpg.mypertamina.id",
  "Referer": "https://subsiditepatlpg.mypertamina.id/",
  "Accept": "application/json, text/plain, */*",
  "User-Agent": "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36"
}
```

### 3.2 Endpoint Profil Pangkalan
- **Method & URL**: `GET https://api-map.my-pertamina.id/general/products/v1/products/user`
- **Fungsi**: Mengambil profil pangkalan dan sisa stok secara otomatis setelah token berhasil dicegat.
- **Sample Response**:
```json
{
  "success": true,
  "data": {
    "registrationId": "316920704188009",
    "storeName": "M. LUKMAN",
    "productId": "80d36445-6189-41df-b1ac-2e1f273e2ef4",
    "productName": "LPG 3 Kg",
    "stockAvailable": 78,
    "stockRedeem": 900,
    "sold": 822,
    "modal": 16000,
    "price": 18700,
    "lastSyncAt": "13 Oct 2026, 16.11"
  }
}
```

### 3.3 Endpoint Verifikasi NIK
- **Method & URL**: `GET https://api-map.my-pertamina.id/general/customer-service/v1/verify-nik-transaction-manual`
- **Query Params**: `nationalityId={16_DIGIT_NIK}`
- **Fungsi**: Memverifikasi NIK pelanggan dan mengecek status kuota resmi dari server MyPertamina.

### 3.4 Endpoint Synchronize Report
- **Method & URL**: `GET https://api-map.my-pertamina.id/general/v3/transactions/report`
- **Query Params**: `startDate={YYYY-MM-DD}&endDate={YYYY-MM-DD}&sort=latest`
- **Fungsi**: Menarik seluruh transaksi yang ada di web resmi untuk disinkronkan ke Firebase & Excel.

---

## 4. Skema Database Firebase Cloud Firestore

### 4.1 Collection: `pangkalan`
Document ID: `{registrationId}`
```typescript
interface Pangkalan {
  registrationId: string;    // e.g. "316920704188009"
  storeName: string;         // e.g. "M. LUKMAN"
  stockAvailable: number;    // e.g. 78
  sold: number;              // e.g. 822
  lastTokenUpdate: Timestamp;
  lastSyncAt: Timestamp;
}
```

### 4.2 Collection: `pelanggan`
Document ID: `{nik}`
```typescript
interface Pelanggan {
  nik: string;               // 16 digit NIK
  nama: string;
  kategori: "RUMAH_TANGGA" | "UMKM";
  registrationId: string;    // Auto-scoped per pangkalan
  totalBeliBulanIni: number;
  terakhirTransaksi: Timestamp;
  createdAt: Timestamp;
}
```

### 4.3 Collection: `log_transaksi`
Document ID: `{auto_generated_id}`
```typescript
interface LogTransaksi {
  id: string;
  nik: string;
  nama: string;
  kategori: "RUMAH_TANGGA" | "UMKM";
  jumlahTabung: number;
  status: "BERHASIL" | "GAGAL";
  pesanError?: string;
  refNo?: string;
  registrationId: string;
  timestamp: Timestamp;
}
```

---

## 5. Algoritma Engine Validasi Kuota Lokal

```dart
bool validateLocalQuota({
  required String nik,
  required String kategori,
  required int jumlahTabungAkanDibeli,
  required List<LogTransaksi> transaksiHariIni,
}) {
  // Hitung akumulasi tabung yang sudah dibeli NIK ini hari ini
  int tabungHariIni = transaksiHariIni
      .where((t) => t.nik == nik && t.status == "BERHASIL")
      .fold(0, (sum, item) => sum + item.jumlahTabung);

  int totalPrediksi = tabungHariIni + jumlahTabungAkanDibeli;

  if (kategori == "RUMAH_TANGGA" && totalPrediksi > 2) {
    throw Exception("Gagal Validasi Lokal: Kategori Rumah Tangga maksimal 2 tabung/hari. (Sudah beli: $tabungHariIni)");
  }

  if (kategori == "UMKM" && totalPrediksi > 5) {
    throw Exception("Gagal Validasi Lokal: Kategori UMKM maksimal 5 tabung/hari. (Sudah beli: $tabungHariIni)");
  }

  return true; // Lolos validasi lokal
}
```

---

## 6. Smart Retry Engine & Exponential Backoff
- **Kondisi Network Error (HTTP 500 / 502 / 503 / Timeout)**:
  - Retry otomatis hingga 3x dengan *exponential backoff* (delay: 2s, 4s, 8s).
- **Kondisi Token Expired (HTTP 401 / 403)**:
  - Hentikan antrean → Tampilkan pemicu dialog "Sesi Berakhir" → Muat ulang WebView untuk menangkap token baru → Lanjutkan antrean otomatis (*auto-resume queue*).
- **Kondisi Kuota Habis / Invalid NIK**:
  - Tandai `GAGAL` permanen, catat pesan error dari server, dan lanjut ke antrean berikutnya.
