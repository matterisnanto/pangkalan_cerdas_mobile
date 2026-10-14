import 'package:cloud_firestore/cloud_firestore.dart';

class Pelanggan {
  final String nik;
  final String nama;
  final String kategori; // "RUMAH_TANGGA" | "UMKM"
  final String registrationId;
  int totalBeliBulanIni;
  DateTime? terakhirTransaksi;
  DateTime? createdAt;

  Pelanggan({
    required this.nik,
    required this.nama,
    required this.kategori,
    required this.registrationId,
    this.totalBeliBulanIni = 0,
    this.terakhirTransaksi,
    this.createdAt,
  });

  factory Pelanggan.fromJson(Map<String, dynamic> json) {
    return Pelanggan(
      nik: json['nik'] as String? ?? '',
      nama: json['nama'] as String? ?? '',
      kategori: json['kategori'] as String? ?? 'RUMAH_TANGGA',
      registrationId: json['registrationId'] as String? ?? '',
      totalBeliBulanIni: (json['totalBeliBulanIni'] as num?)?.toInt() ?? 0,
      terakhirTransaksi: json['terakhirTransaksi'] is Timestamp
          ? (json['terakhirTransaksi'] as Timestamp).toDate()
          : json['terakhirTransaksi'] is String
              ? DateTime.tryParse(json['terakhirTransaksi'] as String)
              : null,
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : json['createdAt'] is String
              ? DateTime.tryParse(json['createdAt'] as String)
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nik': nik,
      'nama': nama,
      'kategori': kategori,
      'registrationId': registrationId,
      'totalBeliBulanIni': totalBeliBulanIni,
      'terakhirTransaksi': terakhirTransaksi != null
          ? Timestamp.fromDate(terakhirTransaksi!)
          : null,
      'createdAt':
          createdAt != null ? Timestamp.fromDate(createdAt!) : null,
    };
  }
}
