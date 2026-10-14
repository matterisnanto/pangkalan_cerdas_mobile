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
    final doc =
        await _db.collection('pangkalan').doc(registrationId).get();
    if (!doc.exists || doc.data() == null) return null;
    return Pangkalan.fromJson(doc.data()!);
  }

  // ─── Pelanggan CRUD (scoped by registrationId) ───

  CollectionReference<Map<String, dynamic>> _pelangganCol(
      String registrationId) {
    return _db
        .collection('pangkalan')
        .doc(registrationId)
        .collection('pelanggan');
  }

  Future<void> savePelanggan(Pelanggan pelanggan) async {
    await _pelangganCol(pelanggan.registrationId)
        .doc(pelanggan.nik)
        .set(pelanggan.toJson(), SetOptions(merge: true));
  }

  Future<void> savePelangganBatch(
      List<Pelanggan> list, String registrationId) async {
    final batch = _db.batch();
    final col = _pelangganCol(registrationId);
    for (final p in list) {
      batch.set(col.doc(p.nik), p.toJson(), SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<List<Pelanggan>> getAllPelanggan(String registrationId) async {
    final snap = await _pelangganCol(registrationId).get();
    return snap.docs.map((d) => Pelanggan.fromJson(d.data())).toList();
  }

  Future<Pelanggan?> getPelanggan(
      String registrationId, String nik) async {
    final doc = await _pelangganCol(registrationId).doc(nik).get();
    if (!doc.exists || doc.data() == null) return null;
    return Pelanggan.fromJson(doc.data()!);
  }

  Future<void> deletePelanggan(String registrationId, String nik) async {
    await _pelangganCol(registrationId).doc(nik).delete();
  }

  Stream<List<Pelanggan>> streamPelanggan(String registrationId) {
    return _pelangganCol(registrationId).snapshots().map(
          (snap) =>
              snap.docs.map((d) => Pelanggan.fromJson(d.data())).toList(),
        );
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
      String registrationId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay
        .add(const Duration(days: 1))
        .subtract(const Duration(milliseconds: 1));

    final snap = await _logCol(registrationId)
        .where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('timestamp',
            isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .get();

    return snap.docs
        .map((d) => LogTransaksi.fromJson(d.data(), docId: d.id))
        .toList();
  }

  Future<List<LogTransaksi>> getAllLogTransaksi(
      String registrationId) async {
    final snap = await _logCol(registrationId)
        .orderBy('timestamp', descending: true)
        .get();
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
