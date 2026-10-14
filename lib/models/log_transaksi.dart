import 'package:cloud_firestore/cloud_firestore.dart';

class LogTransaksi {
  final String id;
  final String nik;
  final String nama;
  final String kategori; // "RUMAH_TANGGA" | "UMKM"
  final int jumlahTabung;
  final String status; // "BERHASIL" | "GAGAL"
  final String? pesanError;
  final String? refNo;
  final String registrationId;
  final DateTime timestamp;

  LogTransaksi({
    required this.id,
    required this.nik,
    required this.nama,
    required this.kategori,
    required this.jumlahTabung,
    required this.status,
    this.pesanError,
    this.refNo,
    required this.registrationId,
    required this.timestamp,
  });

  bool get isBerhasil => status == 'BERHASIL';
  bool get isSuccess => isBerhasil;
  bool get isGagal => status == 'GAGAL';

  factory LogTransaksi.fromJson(Map<String, dynamic> json, {String? docId}) {
    return LogTransaksi(
      id: docId ?? json['id'] as String? ?? '',
      nik: json['nik'] as String? ?? '',
      nama: json['nama'] as String? ?? '',
      kategori: json['kategori'] as String? ?? 'RUMAH_TANGGA',
      jumlahTabung: (json['jumlahTabung'] as num?)?.toInt() ?? 1,
      status: json['status'] as String? ?? 'GAGAL',
      pesanError: json['pesanError'] as String?,
      refNo: json['refNo'] as String?,
      registrationId: json['registrationId'] as String? ?? '',
      timestamp: json['timestamp'] is Timestamp
          ? (json['timestamp'] as Timestamp).toDate()
          : json['timestamp'] is String
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nik': nik,
      'nama': nama,
      'kategori': kategori,
      'jumlahTabung': jumlahTabung,
      'status': status,
      'pesanError': pesanError,
      'refNo': refNo,
      'registrationId': registrationId,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
