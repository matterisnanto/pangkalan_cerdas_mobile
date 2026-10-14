import '../models/pelanggan_model.dart';
import 'firebase_service.dart';
import 'mypertamina_api_service.dart';

class BatchVerificationService {
  final MyPertaminaApiService api;
  final FirebaseService firebase;

  BatchVerificationService({required this.api, FirebaseService? firebase})
    : firebase = firebase ?? FirebaseService();

  Future<BatchVerificationResult> batchVerifyAndSyncWithMyPertamina({
    required List<Pelanggan> customers,
    required String registrationId,
    String? category,
  }) async {
    var verified = 0;
    var failed = 0;
    final errors = <String>[];
    final results = await Future.wait(
      customers.map((customer) async {
        try {
          final result = await api.syncCustomerQuota(
            customer.nik,
            category ?? customer.kategori,
          );
          final verification = result.$1;
          final quota = result.$2;
          final familyId = verification.familyIdEncrypted.isNotEmpty
              ? verification.familyIdEncrypted
              : verification.familyId;
          final updated = Pelanggan(
            nik: customer.nik,
            nama: verification.name.isNotEmpty
                ? verification.name
                : customer.nama,
            tanggalLahir: customer.tanggalLahir,
            kategori: customer.kategori,
            alamat: customer.alamat,
            registrationId: registrationId,
            createdAt: customer.createdAt ?? DateTime.now(),
            encryptedFamilyId: familyId,
            sisaKuotaHarian: quota.dailyAll.toInt(),
            sisaKuotaBulanan: quota.monthly.toInt(),
            sisaKuotaKeluarga: quota.familyQuota.toInt(),
          );
          await firebase.savePelanggan(updated, registrationId);
          return true;
        } catch (error) {
          errors.add('${customer.nik}: $error');
          return false;
        }
      }),
    );
    verified = results.where((value) => value).length;
    failed = results.length - verified;
    return BatchVerificationResult(
      verified: verified,
      failed: failed,
      errors: errors,
    );
  }
}

class BatchVerificationResult {
  final int verified;
  final int failed;
  final List<String> errors;
  const BatchVerificationResult({
    required this.verified,
    required this.failed,
    required this.errors,
  });
}

extension BatchVerificationFirebase on FirebaseService {
  Future<void> savePelanggan(Pelanggan customer, String registrationId) =>
      savePelangganBatch([customer], registrationId);
}
