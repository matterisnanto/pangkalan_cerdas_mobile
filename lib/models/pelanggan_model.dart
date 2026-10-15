import 'package:cloud_firestore/cloud_firestore.dart';

class Pelanggan {
  final String? id;
  final String nik;
  final String nama;
  final String? tanggalLahir; // Format: YYYY-MM-DD
  final String kategori; // 'Rumah Tangga' | 'UMKM'
  final String? alamat;
  final DateTime? createdAt;
  // Transient for backwards compatibility only (never saved to Firestore)
  final String? registrationId;
  final int sisaKuotaHarian;
  final int sisaKuotaBulanan;
  final DateTime? lastTransactedAt;
  final String? lastTransactionPangkalan;
  final int? sisaKuotaKeluarga;
  final String? encryptedFamilyId;
  final DateTime? lastSyncedAt;

  Pelanggan({
    this.id,
    required this.nik,
    required this.nama,
    this.tanggalLahir,
    required this.kategori,
    this.alamat,
    this.createdAt,
    this.registrationId,
    this.sisaKuotaHarian = 0,
    this.sisaKuotaBulanan = 0,
    this.lastTransactedAt,
    this.lastTransactionPangkalan,
    this.sisaKuotaKeluarga,
    this.encryptedFamilyId,
    this.lastSyncedAt,
  });

  /// Normalizes category to either 'Rumah Tangga' or 'UMKM'
  static String normalizeKategori(String? raw) {
    if (raw == null) return 'Rumah Tangga';
    final upper = raw.toUpperCase().replaceAll('_', ' ');
    if (upper.contains('UMKM')) return 'UMKM';
    return 'Rumah Tangga';
  }

  String get displayKategori => normalizeKategori(kategori);

  factory Pelanggan.fromJson(Map<String, dynamic> json, {String? docId}) {
    DateTime? parsedCreatedAt;
    final rawCreated = json['createdAt'];
    if (rawCreated is Timestamp) {
      parsedCreatedAt = rawCreated.toDate();
    } else if (rawCreated is String) {
      parsedCreatedAt = DateTime.tryParse(rawCreated);
    }

    String? tglLahir;
    final rawTgl = json['tanggalLahir'];
    if (rawTgl is Timestamp) {
      final dt = rawTgl.toDate();
      tglLahir =
          '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } else if (rawTgl is String) {
      tglLahir = rawTgl;
    }

    DateTime? syncedAt;
    final rawLastTransaction = json['lastTransactedAt'];
    DateTime? lastTransactedAt = rawLastTransaction is Timestamp
        ? rawLastTransaction.toDate()
        : rawLastTransaction is String
        ? DateTime.tryParse(rawLastTransaction)
        : null;
    final rawSynced = json['lastSyncedAt'];
    if (rawSynced is Timestamp) syncedAt = rawSynced.toDate();
    if (rawSynced is String) syncedAt = DateTime.tryParse(rawSynced);

    return Pelanggan(
      id: docId ?? json['id'] as String?,
      nik: json['nik'] as String? ?? '',
      nama: json['nama'] as String? ?? '',
      tanggalLahir: tglLahir,
      kategori: json['kategori'] as String? ?? 'Rumah Tangga',
      alamat: json['alamat'] as String?,
      createdAt: parsedCreatedAt,
      registrationId: json['registrationId'] as String?,
      sisaKuotaHarian: (json['sisaKuotaHarian'] as num?)?.toInt() ?? 0,
      sisaKuotaBulanan: (json['sisaKuotaBulanan'] as num?)?.toInt() ?? 0,
      lastTransactedAt: lastTransactedAt,
      lastTransactionPangkalan:
          json['lastTransactionPangkalan'] as String? ??
          json['lastPangkalanName'] as String?,
      sisaKuotaKeluarga: (json['sisaKuotaKeluarga'] as num?)?.toInt(),
      encryptedFamilyId: json['encryptedFamilyId'] as String?,
      lastSyncedAt: syncedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nik': nik,
      'nama': nama,
      if (tanggalLahir != null && tanggalLahir!.isNotEmpty)
        'tanggalLahir': tanggalLahir,
      'kategori': kategori,
      if (alamat != null && alamat!.isNotEmpty) 'alamat': alamat,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'sisaKuotaHarian': sisaKuotaHarian,
      'sisaKuotaBulanan': sisaKuotaBulanan,
      'lastTransactedAt': lastTransactedAt == null
          ? null
          : Timestamp.fromDate(lastTransactedAt!),
      'lastTransactionPangkalan': lastTransactionPangkalan,
      'sisaKuotaKeluarga': sisaKuotaKeluarga,
      'encryptedFamilyId': encryptedFamilyId,
      'lastSyncedAt': lastSyncedAt != null
          ? Timestamp.fromDate(lastSyncedAt!)
          : null,
    };
  }

  Pelanggan copyWith({
    String? id,
    String? nik,
    String? nama,
    String? tanggalLahir,
    String? kategori,
    String? alamat,
    DateTime? createdAt,
    int? sisaKuotaHarian,
    int? sisaKuotaBulanan,
    DateTime? lastTransactedAt,
    String? lastTransactionPangkalan,
    int? sisaKuotaKeluarga,
    String? encryptedFamilyId,
    DateTime? lastSyncedAt,
  }) {
    return Pelanggan(
      id: id ?? this.id,
      nik: nik ?? this.nik,
      nama: nama ?? this.nama,
      tanggalLahir: tanggalLahir ?? this.tanggalLahir,
      kategori: kategori ?? this.kategori,
      alamat: alamat ?? this.alamat,
      createdAt: createdAt ?? this.createdAt,
      sisaKuotaHarian: sisaKuotaHarian ?? this.sisaKuotaHarian,
      sisaKuotaBulanan: sisaKuotaBulanan ?? this.sisaKuotaBulanan,
      lastTransactedAt: lastTransactedAt ?? this.lastTransactedAt,
      lastTransactionPangkalan:
          lastTransactionPangkalan ?? this.lastTransactionPangkalan,
      sisaKuotaKeluarga: sisaKuotaKeluarga ?? this.sisaKuotaKeluarga,
      encryptedFamilyId: encryptedFamilyId ?? this.encryptedFamilyId,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}
