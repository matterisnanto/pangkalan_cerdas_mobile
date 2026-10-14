import 'package:cloud_firestore/cloud_firestore.dart';

class Pangkalan {
  final String registrationId;
  final String storeName;
  int stockAvailable;
  int sold;
  DateTime? lastTokenUpdate;
  DateTime? lastSyncAt;

  Pangkalan({
    required this.registrationId,
    required this.storeName,
    this.stockAvailable = 0,
    this.sold = 0,
    this.lastTokenUpdate,
    this.lastSyncAt,
  });

  factory Pangkalan.fromJson(Map<String, dynamic> json) {
    return Pangkalan(
      registrationId: json['registrationId'] as String? ?? '',
      storeName: json['storeName'] as String? ?? '',
      stockAvailable: (json['stockAvailable'] as num?)?.toInt() ?? 0,
      sold: (json['sold'] as num?)?.toInt() ?? 0,
      lastTokenUpdate: json['lastTokenUpdate'] is Timestamp
          ? (json['lastTokenUpdate'] as Timestamp).toDate()
          : json['lastTokenUpdate'] is String
          ? DateTime.tryParse(json['lastTokenUpdate'] as String)
          : null,
      lastSyncAt: json['lastSyncAt'] is Timestamp
          ? (json['lastSyncAt'] as Timestamp).toDate()
          : json['lastSyncAt'] is String
          ? DateTime.tryParse(json['lastSyncAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'registrationId': registrationId,
      'storeName': storeName,
      'stockAvailable': stockAvailable,
      'sold': sold,
      'lastTokenUpdate': lastTokenUpdate != null
          ? Timestamp.fromDate(lastTokenUpdate!)
          : null,
      'lastSyncAt': lastSyncAt != null ? Timestamp.fromDate(lastSyncAt!) : null,
    };
  }
}
