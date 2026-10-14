import '../models/log_transaksi.dart';

class QuotaValidationResult {
  final bool isValid;
  final String? errorMessage;
  final int tabungHariIni;
  final int maxKuota;

  const QuotaValidationResult({
    required this.isValid,
    this.errorMessage,
    this.tabungHariIni = 0,
    this.maxKuota = 0,
  });
}

class QuotaRuleEngine {
  static const int maxRumahTangga = 2;
  static const int maxUmkm = 5;

  /// Validate local daily quota BEFORE calling external API.
  /// Returns QuotaValidationResult with pass/fail info.
  static QuotaValidationResult validateLocalQuota({
    required String nik,
    required String kategori,
    required int jumlahTabungAkanDibeli,
    required List<LogTransaksi> transaksiHariIni,
  }) {
    // Count successful transactions for this NIK today
    final int tabungHariIni = transaksiHariIni
        .where((t) => t.nik == nik && t.status == 'BERHASIL')
        .fold(0, (sum, item) => sum + item.jumlahTabung);

    final int totalPrediksi = tabungHariIni + jumlahTabungAkanDibeli;

    final int maxKuota =
        kategori == 'UMKM' ? maxUmkm : maxRumahTangga;

    if (totalPrediksi > maxKuota) {
      final label = kategori == 'UMKM' ? 'UMKM' : 'Rumah Tangga';
      return QuotaValidationResult(
        isValid: false,
        errorMessage:
            'Gagal Validasi Lokal: Kategori $label maksimal '
            '$maxKuota tabung/hari. (Sudah beli: $tabungHariIni)',
        tabungHariIni: tabungHariIni,
        maxKuota: maxKuota,
      );
    }

    return QuotaValidationResult(
      isValid: true,
      tabungHariIni: tabungHariIni,
      maxKuota: maxKuota,
    );
  }
}
