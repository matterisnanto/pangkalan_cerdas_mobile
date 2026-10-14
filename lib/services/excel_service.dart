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
  /// Expected columns: NIK, Nama, Kategori (RUMAH_TANGGA / UMKM)
  static Future<List<Pelanggan>> importPelanggan({
    required String filePath,
    required String registrationId,
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

        final nik = _cellValue(row, 0);
        final nama = _cellValue(row, 1);
        final kategori = _cellValue(row, 2).toUpperCase();

        if (nik.isEmpty || nik.length < 16) continue;

        final normalizedKategori =
            kategori.contains('UMKM') ? 'UMKM' : 'RUMAH_TANGGA';

        result.add(Pelanggan(
          nik: nik,
          nama: nama,
          kategori: normalizedKategori,
          registrationId: registrationId,
          createdAt: DateTime.now(),
        ));
      }
      break; // Only read first sheet
    }

    return result;
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
