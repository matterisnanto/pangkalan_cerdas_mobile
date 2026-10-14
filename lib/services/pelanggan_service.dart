import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pelanggan_model.dart';
import '../models/log_transaksi.dart';

class PelangganService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection('pelanggan');

  /// Stream of all customers with optional search and category filters
  Stream<List<Pelanggan>> streamPelanggan({String? search, String? kategori}) {
    Query<Map<String, dynamic>> query = _collection;

    if (kategori != null &&
        kategori.isNotEmpty &&
        kategori != 'Semua' &&
        kategori != 'SEMUA') {
      final normalized = Pelanggan.normalizeKategori(kategori);
      query = query.where('kategori', isEqualTo: normalized);
    }

    return query.snapshots().map((snapshot) {
      final list = snapshot.docs.map((doc) {
        return Pelanggan.fromJson(doc.data(), docId: doc.id);
      }).toList();

      // Local search filtering (by NIK or Nama)
      if (search != null && search.trim().isNotEmpty) {
        final q = search.trim().toLowerCase();
        return list.where((p) {
          final nikMatch = p.nik.toLowerCase().contains(q);
          final namaMatch = p.nama.toLowerCase().contains(q);
          return nikMatch || namaMatch;
        }).toList();
      }

      list.sort((a, b) => a.nama.toLowerCase().compareTo(b.nama.toLowerCase()));
      return list;
    });
  }

  /// Get all customers as a Future list
  Future<List<Pelanggan>> getAllPelanggan() async {
    final snap = await _collection.get();
    final list = snap.docs
        .map((d) => Pelanggan.fromJson(d.data(), docId: d.id))
        .toList();
    list.sort((a, b) => a.nama.toLowerCase().compareTo(b.nama.toLowerCase()));
    return list;
  }

  /// Get single customer by Firestore doc ID
  Future<Pelanggan?> getPelangganById(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return Pelanggan.fromJson(doc.data()!, docId: doc.id);
  }

  /// Get single customer by NIK
  Future<Pelanggan?> getPelangganByNik(String nik) async {
    final snap = await _collection.where('nik', isEqualTo: nik).limit(1).get();
    if (snap.docs.isEmpty) return null;
    final d = snap.docs.first;
    return Pelanggan.fromJson(d.data(), docId: d.id);
  }

  /// Add new customer to centralized 'pelanggan' collection
  Future<String> addPelanggan(Pelanggan pelanggan) async {
    // If document with same NIK exists, update it, else add
    final existing = await _collection
        .where('nik', isEqualTo: pelanggan.nik)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      final docId = existing.docs.first.id;
      await _collection
          .doc(docId)
          .set(pelanggan.toJson(), SetOptions(merge: true));
      return docId;
    }
    final docRef = await _collection.add(pelanggan.toJson());
    return docRef.id;
  }

  /// Update existing customer
  Future<void> updatePelanggan(Pelanggan pelanggan) async {
    if (pelanggan.id != null && pelanggan.id!.isNotEmpty) {
      await _collection
          .doc(pelanggan.id)
          .set(pelanggan.toJson(), SetOptions(merge: true));
    } else {
      // Find by NIK
      final snap = await _collection
          .where('nik', isEqualTo: pelanggan.nik)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        await _collection
            .doc(snap.docs.first.id)
            .set(pelanggan.toJson(), SetOptions(merge: true));
      } else {
        await _collection.add(pelanggan.toJson());
      }
    }
  }

  /// Delete customer by ID or NIK
  Future<void> deletePelanggan(String id) async {
    await _collection.doc(id).delete();
  }

  /// Batch import customers into Firestore
  Future<int> importBatch(List<Pelanggan> list) async {
    if (list.isEmpty) return 0;
    final batch = _db.batch();
    int count = 0;

    for (final p in list) {
      if (p.nik.trim().isEmpty) continue;
      // Use NIK as doc ID for deterministic upsert in batch
      final docRef = _collection.doc(p.nik.trim());
      batch.set(docRef, p.toJson(), SetOptions(merge: true));
      count++;
    }

    await batch.commit();
    return count;
  }

  /// Fetch transaction history for this customer by NIK
  Future<List<LogTransaksi>> getCustomerTransactions(String nik) async {
    final List<LogTransaksi> logs = [];
    try {
      // Query collectionGroup or root collections for log_transaksi matching NIK
      final snap = await _db
          .collectionGroup('log_transaksi')
          .where('nik', isEqualTo: nik)
          .get();

      for (final doc in snap.docs) {
        logs.add(LogTransaksi.fromJson(doc.data(), docId: doc.id));
      }
    } catch (_) {
      // Fallback if collectionGroup index is not built yet: try pangkalan log collections
      try {
        final pangkalanSnap = await _db.collection('pangkalan').get();
        for (final pDoc in pangkalanSnap.docs) {
          final subSnap = await pDoc.reference
              .collection('log_transaksi')
              .where('nik', isEqualTo: nik)
              .get();
          for (final doc in subSnap.docs) {
            logs.add(LogTransaksi.fromJson(doc.data(), docId: doc.id));
          }
        }
      } catch (_) {}
    }

    logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return logs;
  }
}
