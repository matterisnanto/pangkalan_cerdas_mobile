import '../models/pelanggan_model.dart';
import '../models/log_transaksi.dart';
import 'local_database_service.dart';

class PelangganService {
  final LocalDatabaseService _db = LocalDatabaseService.instance;

  Map<String, dynamic> _toRow(Pelanggan p) => {
        'nik': p.nik,
        'nama': p.nama,
        'category': p.kategori,
        'familyId': p.familyIdEncrypted ?? p.encryptedFamilyId,
        'remainingQuota': p.sisaKuotaBulanan,
        'isEnriched': (p.familyIdEncrypted ?? p.encryptedFamilyId)?.isNotEmpty == true ? 1 : 0,
        'updatedAt': (p.lastSyncedAt ?? p.lastQuotaUpdate ?? p.createdAt ?? DateTime.now()).toIso8601String(),
      };

  Pelanggan _fromRow(Map<String, dynamic> row) => Pelanggan(
        id: '${row['nik']}',
        nik: '${row['nik'] ?? ''}',
        nama: '${row['nama'] ?? ''}',
        kategori: '${row['category'] ?? 'Rumah Tangga'}',
        familyIdEncrypted: row['familyId'] as String?,
        encryptedFamilyId: row['familyId'] as String?,
        sisaKuota: (row['remainingQuota'] as num? ?? 0).toInt(),
        sisaKuotaBulanan: (row['remainingQuota'] as num? ?? 0).toInt(),
        lastSyncedAt: DateTime.tryParse('${row['updatedAt'] ?? ''}'),
      );

  Stream<List<Pelanggan>> streamPelanggan({String? search, String? kategori}) async* {
    yield (await _db.getCustomers(search: search, category: kategori))
        .map(_fromRow).toList();
  }

  Future<List<Pelanggan>> getAllPelanggan() async =>
      (await _db.getCustomers()).map(_fromRow).toList();

  Future<Pelanggan?> getPelangganById(String id) async => getPelangganByNik(id);

  Future<Pelanggan?> getPelangganByNik(String nik) async {
    final rows = await _db.getCustomers(search: nik);
    for (final row in rows) {
      if (row['nik'] == nik) return _fromRow(row);
    }
    return null;
  }

  Future<String> addPelanggan(Pelanggan pelanggan) async {
    await _db.upsertCustomer(_toRow(pelanggan));
    return pelanggan.nik;
  }

  Future<void> updatePelanggan(Pelanggan pelanggan) async {
    await _db.upsertCustomer(_toRow(pelanggan));
  }

  Future<void> deletePelanggan(String id) async {
    final db = await _db.database;
    await db.delete('customers', where: 'nik = ?', whereArgs: [id]);
  }

  Future<int> importBatch(List<Pelanggan> list) async {
    for (final customer in list) {
      if (customer.nik.trim().isNotEmpty) await _db.upsertCustomer(_toRow(customer));
    }
    return list.where((p) => p.nik.trim().isNotEmpty).length;
  }

  Future<List<LogTransaksi>> getCustomerTransactions(String nik) async => [];
}
