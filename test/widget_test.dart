import 'package:flutter_test/flutter_test.dart';
import 'package:pangkalan_cerdas_mobile/models/log_transaksi.dart';
import 'package:pangkalan_cerdas_mobile/models/pelanggan.dart';
import 'package:pangkalan_cerdas_mobile/models/pangkalan.dart';
import 'package:pangkalan_cerdas_mobile/services/quota_rule_engine.dart';

void main() {
  group('QuotaRuleEngine Tests (FASE 4)', () {
    const nik = '1234567890123456';

    test('Rumah Tangga: allow up to 2 tabung/day', () {
      final res = QuotaRuleEngine.validateLocalQuota(
        nik: nik,
        kategori: 'RUMAH_TANGGA',
        jumlahTabungAkanDibeli: 2,
        transaksiHariIni: [],
      );
      expect(res.isValid, isTrue);
      expect(res.maxKuota, 2);
    });

    test('Rumah Tangga: reject > 2 tabung/day', () {
      final res = QuotaRuleEngine.validateLocalQuota(
        nik: nik,
        kategori: 'RUMAH_TANGGA',
        jumlahTabungAkanDibeli: 3,
        transaksiHariIni: [],
      );
      expect(res.isValid, isFalse);
      expect(res.errorMessage, contains('maksimal 2 tabung/hari'));
    });

    test('Rumah Tangga: reject when accumulated with existing transactions > 2', () {
      final existingLogs = [
        LogTransaksi(
          id: '1',
          nik: nik,
          nama: 'Budi',
          kategori: 'RUMAH_TANGGA',
          jumlahTabung: 1,
          status: 'BERHASIL',
          registrationId: 'reg123',
          timestamp: DateTime.now(),
        ),
      ];

      final res = QuotaRuleEngine.validateLocalQuota(
        nik: nik,
        kategori: 'RUMAH_TANGGA',
        jumlahTabungAkanDibeli: 2,
        transaksiHariIni: existingLogs,
      );
      expect(res.isValid, isFalse);
      expect(res.tabungHariIni, 1);
    });

    test('UMKM: allow up to 5 tabung/day', () {
      final res = QuotaRuleEngine.validateLocalQuota(
        nik: nik,
        kategori: 'UMKM',
        jumlahTabungAkanDibeli: 5,
        transaksiHariIni: [],
      );
      expect(res.isValid, isTrue);
      expect(res.maxKuota, 5);
    });

    test('UMKM: reject > 5 tabung/day', () {
      final res = QuotaRuleEngine.validateLocalQuota(
        nik: nik,
        kategori: 'UMKM',
        jumlahTabungAkanDibeli: 6,
        transaksiHariIni: [],
      );
      expect(res.isValid, isFalse);
      expect(res.errorMessage, contains('maksimal 5 tabung/hari'));
    });
  });

  group('Model Serialization Tests (FASE 3)', () {
    test('Pelanggan toJson and fromJson', () {
      final p = Pelanggan(
        nik: '1234567890123456',
        nama: 'Ahmad',
        kategori: 'RUMAH_TANGGA',
        registrationId: 'reg001',
      );
      final json = p.toJson();
      expect(json['nik'], '1234567890123456');
      expect(json['nama'], 'Ahmad');

      final restored = Pelanggan.fromJson(json);
      expect(restored.nik, p.nik);
      expect(restored.nama, p.nama);
      expect(restored.kategori, p.kategori);
    });

    test('Pangkalan toJson and fromJson', () {
      final p = Pangkalan(
        registrationId: '316920704188009',
        storeName: 'M. LUKMAN',
        stockAvailable: 78,
        sold: 822,
      );
      final json = p.toJson();
      expect(json['storeName'], 'M. LUKMAN');

      final restored = Pangkalan.fromJson(json);
      expect(restored.registrationId, p.registrationId);
      expect(restored.stockAvailable, 78);
      expect(restored.sold, 822);
    });
  });
}

