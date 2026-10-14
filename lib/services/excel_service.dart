import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import '../models/pelanggan.dart';
import '../models/log_transaksi.dart';

class ExcelService {
  /// Request storage permissions for Android
  static Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.manageExternalStorage.request();
      if (status.isGranted) return true;
      final storageStatus = await Permission.storage.request();
      return storageStatus.isGranted;
    }
    return true;
  }

  /// Get Download directory path
  static Future<String> getDownloadPath() async {
    if (Platform.isAndroid) {
      return '/storage/emulated/0/Download';
    }
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  /// Import pelanggan from .xlsx file in Download folder.
  /// Supports columns:
  /// Format: [NIK, Nama, Tanggal Lahir, Kategori, Alamat] OR [NIK, Nama, Kategori] for legacy files.
  static Future<List<Pelanggan>> importPelanggan({
    required String filePath,
    String? registrationId,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File tidak ditemukan: $filePath');
    }

    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);
    final List<Pelanggan> result = [];

    for (final table in excel.tables.keys) {
      final sheet = excel.tables[table]!;
      // Skip header row (row 0)
      for (int i = 1; i < sheet.maxRows; i++) {
        final row = sheet.row(i);
        if (row.isEmpty) continue;

        final col0 = _cellValue(row, 0);
        final col1 = _cellValue(row, 1);
        final col2 = _cellValue(row, 2);
        final col3 = _cellValue(row, 3);
        final col4 = _cellValue(row, 4);

        if (col0.isEmpty || col0.length < 16) continue;

        String nik = col0;
        String nama = col1;
        String? tanggalLahir;
        String kategori;
        String? alamat;

        // Check if col2 looks like a date (e.g. 1990-01-01 or 01/01/1990)
        final isCol2Date =
            col2.contains('-') ||
            col2.contains('/') ||
            RegExp(r'^\d{4}').hasMatch(col2);
        final isCol2Kategori =
            col2.toUpperCase().contains('RUMAH') ||
            col2.toUpperCase().contains('UMKM');

        if (isCol2Date) {
          tanggalLahir = _normalizeDateString(col2);
          kategori = col3.isNotEmpty ? col3 : 'Rumah Tangga';
          alamat = col4.isNotEmpty ? col4 : null;
        } else if (isCol2Kategori) {
          kategori = col2;
          tanggalLahir = col3.isNotEmpty ? _normalizeDateString(col3) : null;
          alamat = col4.isNotEmpty ? col4 : null;
        } else {
          kategori = col2.isNotEmpty ? col2 : 'Rumah Tangga';
          tanggalLahir = col3.isNotEmpty ? _normalizeDateString(col3) : null;
          alamat = col4.isNotEmpty ? col4 : null;
        }

        result.add(
          Pelanggan(
            nik: nik,
            nama: nama,
            tanggalLahir: tanggalLahir,
            kategori: Pelanggan.normalizeKategori(kategori),
            alamat: alamat,
            registrationId: registrationId,
            createdAt: DateTime.now(),
          ),
        );
      }
      break; // Only read first sheet
    }

    return result;
  }

  /// Export master data pelanggan to .xlsx file in Download folder
  static Future<String> exportPelanggan({
    required List<Pelanggan> pelangganList,
  }) async {
    final hasPermission = await requestStoragePermission();
    if (!hasPermission) {
      throw Exception('Izin penyimpanan ditolak');
    }

    final excel = Excel.createExcel();
    final sheet = excel['Master Pelanggan'];

    // Header row
    sheet.appendRow([
      TextCellValue('No'),
      TextCellValue('NIK'),
      TextCellValue('Nama'),
      TextCellValue('Tanggal Lahir'),
      TextCellValue('Kategori'),
      TextCellValue('No HP'),
      TextCellValue('Alamat'),
      TextCellValue('Tanggal Dibuat'),
    ]);

    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    for (int i = 0; i < pelangganList.length; i++) {
      final p = pelangganList[i];
      sheet.appendRow([
        IntCellValue(i + 1),
        TextCellValue(p.nik),
        TextCellValue(p.nama),
        TextCellValue(p.tanggalLahir ?? '-'),
        TextCellValue(p.kategori),
        TextCellValue(p.alamat ?? '-'),
        TextCellValue(
          p.createdAt != null ? dateFormat.format(p.createdAt!) : '-',
        ),
      ]);
    }

    // Remove default Sheet1
    if (excel.tables.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final downloadPath = await getDownloadPath();
    final now = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'Master_Pelanggan_$now.xlsx';
    final filePath = '$downloadPath/$fileName';

    final fileBytes = excel.encode();
    if (fileBytes == null) throw Exception('Gagal encode file Excel');

    final file = File(filePath);
    await file.writeAsBytes(fileBytes);

    return filePath;
  }

  static String _normalizeDateString(String raw) {
    raw = raw.trim();
    if (raw.isEmpty) return '';
    try {
      if (raw.contains('/')) {
        final parts = raw.split('/');
        if (parts.length == 3) {
          // If DD/MM/YYYY
          if (parts[2].length == 4) {
            return '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
          }
        }
      }
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) {
        return '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
      }
    } catch (_) {}
    return raw;
  }

  /// Export log transaksi to .xlsx file in Download folder
  static Future<String> exportLogTransaksi({
    required List<LogTransaksi> logs,
    required String storeName,
  }) async {
    final hasPermission = await requestStoragePermission();
    if (!hasPermission) {
      throw Exception('Izin penyimpanan ditolak');
    }

    final excel = Excel.createExcel();
    final sheet = excel['Laporan Transaksi'];

    // Header row
    sheet.appendRow([
      TextCellValue('No'),
      TextCellValue('NIK'),
      TextCellValue('Nama'),
      TextCellValue('Kategori'),
      TextCellValue('Jumlah Tabung'),
      TextCellValue('Status'),
      TextCellValue('Ref No'),
      TextCellValue('Pesan Error'),
      TextCellValue('Waktu'),
    ]);

    final dateFormat = DateFormat('dd/MM/yyyy HH:mm:ss');

    for (int i = 0; i < logs.length; i++) {
      final log = logs[i];
      sheet.appendRow([
        IntCellValue(i + 1),
        TextCellValue(log.nik),
        TextCellValue(log.nama),
        TextCellValue(log.kategori),
        IntCellValue(log.jumlahTabung),
        TextCellValue(log.status),
        TextCellValue(log.refNo ?? '-'),
        TextCellValue(log.pesanError ?? '-'),
        TextCellValue(dateFormat.format(log.timestamp)),
      ]);
    }

    // Remove default Sheet1
    if (excel.tables.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final downloadPath = await getDownloadPath();
    final now = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'Laporan_${storeName.replaceAll(' ', '_')}_$now.xlsx';
    final filePath = '$downloadPath/$fileName';

    final fileBytes = excel.encode();
    if (fileBytes == null) throw Exception('Gagal encode file Excel');

    final file = File(filePath);
    await file.writeAsBytes(fileBytes);

    return filePath;
  }

  static String _cellValue(List<Data?> row, int index) {
    if (index >= row.length || row[index] == null) return '';
    return row[index]!.value?.toString().trim() ?? '';
  }
}
