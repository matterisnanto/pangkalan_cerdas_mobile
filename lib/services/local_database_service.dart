import 'dart:developer' as developer;

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class LocalDatabaseService {
  LocalDatabaseService._();
  static final instance = LocalDatabaseService._();

  Database? _database;
  Future<Database>? _openingDatabase;

  Future<Database> get database async {
    final current = _database;
    if (current != null && current.isOpen) return current;
    return _openingDatabase ??= _openWithRecovery().whenComplete(() {
      _openingDatabase = null;
    });
  }

  Future<Database> _openWithRecovery() async {
    final dbPath = join(await getDatabasesPath(), 'pangkalan_cerdas.db');
    try {
      _database = await _openDatabase(dbPath);
      return _database!;
    } catch (error, stack) {
      developer.log('SQLite open error: $error', error: error, stackTrace: stack);
      await _database?.close();
      _database = null;
      try {
        await deleteDatabase(dbPath);
      } catch (deleteError, deleteStack) {
        developer.log('SQLite recovery delete error: $deleteError',
            error: deleteError, stackTrace: deleteStack);
      }
      _database = await _openDatabase(dbPath);
      return _database!;
    }
  }

  Future<Database> _openDatabase(String dbPath) => openDatabase(
        dbPath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''CREATE TABLE customers (
            nik TEXT PRIMARY KEY,
            nama TEXT,
            category TEXT,
            familyId TEXT,
            remainingQuota INTEGER DEFAULT 0,
            isEnriched INTEGER DEFAULT 0,
            updatedAt TEXT
          )''');
          await db.execute('''CREATE TABLE transactions (
            id TEXT PRIMARY KEY,
            registrationId TEXT,
            customerReportId TEXT,
            nationalityId TEXT,
            name TEXT,
            categories TEXT,
            totalQuantity INTEGER DEFAULT 0,
            createdAt TEXT
          )''');
          await db.execute(
              'CREATE INDEX idx_transactions_registration ON transactions(registrationId)');
        },
      );

  Future<void> upsertCustomer(Map<String, dynamic> data) async {
    print('💾 [SQLITE STEP 1] Membuka koneksi database...');
    final row = Map<String, dynamic>.from(data);
    final nik = '${row['nik'] ?? ''}'.trim();
    if (nik.isEmpty) throw ArgumentError('Customer NIK wajib diisi');
    row['nik'] = nik;
    row['category'] = row['category'] ?? row['kategori'] ?? 'Rumah Tangga';
    row['remainingQuota'] = (row['remainingQuota'] ?? row['sisaKuota'] ?? 0) is num
        ? ((row['remainingQuota'] ?? row['sisaKuota'] ?? 0) as num).toInt()
        : int.tryParse('${row['remainingQuota'] ?? row['sisaKuota'] ?? 0}') ?? 0;
    row['isEnriched'] = row['isEnriched'] == true || row['isEnriched'] == 1 ? 1 : 0;
    row['updatedAt'] ??= DateTime.now().toIso8601String();
    print('💾 [SQLITE STEP 2] CONFLICT_REPLACE NIK: ${row['nik']} | Row: $row');
    try {
      final result = await (await database).insert('customers', row,
          conflictAlgorithm: ConflictAlgorithm.replace);
      print('✅ [SQLITE STEP 3] Insert/Replace berhasil. Row ID: $result');
    } catch (e, stack) {
      print('❌ [SQLITE EXCEPTION] Gagal insert customers: $e\n$stack');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getCustomers({String? search, String? category}) async {
    final where = <String>[];
    final args = <Object?>[];
    if (search != null && search.trim().isNotEmpty) {
      where.add('(nik LIKE ? OR nama LIKE ?)');
      args..add('%${search.trim()}%')..add('%${search.trim()}%');
    }
    if (category != null && category.isNotEmpty && category.toUpperCase() != 'SEMUA') {
      where.add('category = ?');
      args.add(category);
    }
    return (await database).query('customers',
        where: where.isEmpty ? null : where.join(' AND '),
        whereArgs: args,
        orderBy: 'nama COLLATE NOCASE ASC');
  }

  Future<void> upsertTransaction(Map<String, dynamic> data) async {
    final row = Map<String, dynamic>.from(data);
    final registrationId = '${row['registrationId'] ?? ''}'.trim();
    final nationalityId = '${row['nationalityId'] ?? ''}'.trim();
    final createdAt = '${row['createdAt'] ?? ''}'.trim();
    final id = '${row['id'] ?? '${registrationId}_${nationalityId}_$createdAt'}';
    if (id.trim().isEmpty) throw ArgumentError('Transaction ID wajib diisi');
    row['id'] = id;
    row['totalQuantity'] = (row['totalQuantity'] ?? row['total'] ?? 0) is num
        ? ((row['totalQuantity'] ?? row['total'] ?? 0) as num).toInt()
        : int.tryParse('${row['totalQuantity'] ?? row['total'] ?? 0}') ?? 0;
    await (await database).insert('transactions', row,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getTransactions(String registrationId,
      {String? search, bool? uniqueCustomer}) async {
    final rows = await (await database).query('transactions',
        where: 'registrationId = ?', whereArgs: [registrationId], orderBy: 'createdAt DESC');
    final filtered = search == null || search.trim().isEmpty
        ? rows
        : rows.where((row) => '${row['name']}'.toLowerCase().contains(search.toLowerCase()) ||
              '${row['nationalityId']}'.contains(search)).toList();
    if (uniqueCustomer != true) return filtered;
    final seen = <String>{};
    return filtered.where((row) => seen.add('${row['nationalityId']}')).toList();
  }

  Future<void> autoCleanDuplicateTransactions(String registrationId) async {
    final db = await database;
    final rows = await db.query('transactions',
        columns: ['id', 'nationalityId', 'createdAt'],
        where: 'registrationId = ?', whereArgs: [registrationId], orderBy: 'createdAt DESC');
    final seen = <String>{};
    for (final row in rows) {
      final key = '${row['nationalityId']}_${row['createdAt']}';
      if (!seen.add(key)) await db.delete('transactions', where: 'id = ?', whereArgs: [row['id']]);
    }
  }
}
