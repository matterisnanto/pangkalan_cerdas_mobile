import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pangkalan.dart';
import '../models/pelanggan.dart';
import '../models/log_transaksi.dart';

class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── Pangkalan CRUD ───

  Future<void> savePangkalan(Pangkalan pangkalan) async {
    await _db
        .collection('pangkalan')
        .doc(pangkalan.registrationId)
        .set(pangkalan.toJson(), SetOptions(merge: true));
  }

  Future<Pangkalan?> getPangkalan(String registrationId) async {
    final doc = await _db.collection('pangkalan').doc(registrationId).get();
    if (!doc.exists || doc.data() == null) return null;
    return Pangkalan.fromJson(doc.data()!);
  }

  // ─── Pelanggan CRUD (scoped by registrationId & centralized) ───

  CollectionReference<Map<String, dynamic>> _pelangganCol(
    String registrationId,
  ) {
    return _db
        .collection('pangkalan')
        .doc(registrationId)
        .collection('pelanggan');
  }

  Future<void> savePelanggan(
    Pelanggan pelanggan, [
    String? registrationId,
  ]) async {
    final regId = pelanggan.registrationId ?? registrationId;
    if (regId != null && regId.isNotEmpty) {
      await _pelangganCol(
        regId,
      ).doc(pelanggan.nik).set(pelanggan.toJson(), SetOptions(merge: true));
    }
    // Save to centralized collection
    await _db
        .collection('pelanggan')
        .doc(pelanggan.nik)
        .set(pelanggan.toJson(), SetOptions(merge: true));
  }

  Future<void> savePelangganBatch(
    List<Pelanggan> list,
    String registrationId,
  ) async {
    final batch = _db.batch();
    final col = _pelangganCol(registrationId);
    final centralCol = _db.collection('pelanggan');
    for (final p in list) {
      final docPangkalan = col.doc(p.nik);
      final docCentral = centralCol.doc(p.nik);
      batch.set(docPangkalan, p.toJson(), SetOptions(merge: true));
      batch.set(docCentral, p.toJson(), SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<List<Pelanggan>> getAllPelanggan([String? registrationId]) async {
    if (registrationId != null && registrationId.isNotEmpty) {
      final snap = await _pelangganCol(registrationId).get();
      if (snap.docs.isNotEmpty) {
        return snap.docs
            .map((d) => Pelanggan.fromJson(d.data(), docId: d.id))
            .toList();
      }
    }
    final snap = await _db.collection('pelanggan').get();
    return snap.docs
        .map((d) => Pelanggan.fromJson(d.data(), docId: d.id))
        .toList();
  }

  Future<Pelanggan?> getPelanggan(String registrationId, String nik) async {
    final doc = await _pelangganCol(registrationId).doc(nik).get();
    if (doc.exists && doc.data() != null) {
      return Pelanggan.fromJson(doc.data()!, docId: doc.id);
    }
    final centralDoc = await _db.collection('pelanggan').doc(nik).get();
    if (!centralDoc.exists || centralDoc.data() == null) return null;
    return Pelanggan.fromJson(centralDoc.data()!, docId: centralDoc.id);
  }

  Future<void> deletePelanggan(String registrationId, String nik) async {
    if (registrationId.isNotEmpty) {
      await _pelangganCol(registrationId).doc(nik).delete();
    }
    await _db.collection('pelanggan').doc(nik).delete();
  }

  Stream<List<Pelanggan>> streamPelanggan([String? registrationId]) {
    if (registrationId != null && registrationId.isNotEmpty) {
      return _pelangganCol(registrationId).snapshots().map(
        (snap) => snap.docs
            .map((d) => Pelanggan.fromJson(d.data(), docId: d.id))
            .toList(),
      );
    }
    return _db
        .collection('pelanggan')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => Pelanggan.fromJson(d.data(), docId: d.id))
              .toList(),
        );
  }

  Future<void> saveInterceptedTransaction({
    required String registrationId,
    required Map<String, dynamic> payload,
  }) async {
    final data = Map<String, dynamic>.from(payload);
    final id = data['transactionId']?.toString() ?? data['id']?.toString();
    final ref = id == null || id.isEmpty
        ? _db.collection('riwayat_transaksi').doc()
        : _db.collection('riwayat_transaksi').doc(id);
    data['registrationId'] = registrationId;
    data['capturedAt'] = FieldValue.serverTimestamp();
    await ref.set(data, SetOptions(merge: true));
    final nik =
        data['NIK']?.toString() ??
        data['nik']?.toString() ??
        data['nationalityId']?.toString();
    final name = data['customerName']?.toString() ?? data['name']?.toString();
    if (nik != null && nik.isNotEmpty && name != null && name.isNotEmpty) {
      await _pelangganCol(registrationId).doc(nik).set({
        'nik': nik,
        'nama': name,
        'kategori': data['category']?.toString() ?? 'Rumah Tangga',
        'registrationId': registrationId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _db.collection('pelanggan').doc(nik).set({
        'nik': nik,
        'nama': name,
        'kategori': data['category']?.toString() ?? 'Rumah Tangga',
        'registrationId': registrationId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> updatePelangganQuota({required String nik, required String registrationId, required String encryptedFamilyId, required int daily, required int monthly, required int family}) async {
    final data = {
      'encryptedFamilyId': encryptedFamilyId,
      'sisaKuotaHarian': daily,
      'sisaKuotaBulanan': monthly,
      'sisaKuotaKeluarga': family,
      'lastSyncedAt': FieldValue.serverTimestamp(),
    };
    await _db.collection('pelanggan').doc(nik).set(data, SetOptions(merge: true));
    if (registrationId.isNotEmpty) await _pelangganCol(registrationId).doc(nik).set(data, SetOptions(merge: true));
  }

  // ─── Log Transaksi (scoped by registrationId) ───

  CollectionReference<Map<String, dynamic>> _logCol(String registrationId) {
    return _db
        .collection('pangkalan')
        .doc(registrationId)
        .collection('log_transaksi');
  }

  Future<void> saveLogTransaksi(LogTransaksi log) async {
    if (log.id.isEmpty) {
      final docRef = _logCol(log.registrationId).doc();
      final updated = LogTransaksi(
        id: docRef.id,
        nik: log.nik,
        nama: log.nama,
        kategori: log.kategori,
        jumlahTabung: log.jumlahTabung,
        status: log.status,
        pesanError: log.pesanError,
        refNo: log.refNo,
        registrationId: log.registrationId,
        timestamp: log.timestamp,
      );
      await docRef.set(updated.toJson());
    } else {
      await _logCol(log.registrationId).doc(log.id).set(log.toJson());
    }
  }

  Future<List<LogTransaksi>> getLogTransaksiHariIni(
    String registrationId,
  ) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay
        .add(const Duration(days: 1))
        .subtract(const Duration(milliseconds: 1));

    final snap = await _logCol(registrationId)
        .where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .get();

    return snap.docs
        .map((d) => LogTransaksi.fromJson(d.data(), docId: d.id))
        .toList();
  }

  Future<List<LogTransaksi>> getAllLogTransaksi(String registrationId) async {
    final snap = await _logCol(
      registrationId,
    ).orderBy('timestamp', descending: true).get();
    return snap.docs
        .map((d) => LogTransaksi.fromJson(d.data(), docId: d.id))
        .toList();
  }

  Stream<List<LogTransaksi>> streamLogTransaksi(String registrationId) {
    return _logCol(registrationId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => LogTransaksi.fromJson(d.data(), docId: d.id))
              .toList(),
        );
  }

  Future<List<LogTransaksi>> getLogGagal(String registrationId) async {
    final snap = await _logCol(registrationId)
        .where('status', isEqualTo: 'GAGAL')
        .orderBy('timestamp', descending: true)
        .get();
    return snap.docs
        .map((d) => LogTransaksi.fromJson(d.data(), docId: d.id))
        .toList();
  }
}
