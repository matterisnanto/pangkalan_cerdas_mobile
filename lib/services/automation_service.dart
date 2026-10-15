import '../models/pelanggan_model.dart';
import 'firebase_service.dart';

class SmartQueueEntry {
  final Pelanggan pelanggan;
  final bool aman;
  const SmartQueueEntry({required this.pelanggan, required this.aman});
}

class SmartQueueResult {
  final List<SmartQueueEntry> entries;
  const SmartQueueResult(this.entries);
  int get totalTabung => entries.length;
  int get amanCount => entries.where((e) => e.aman).length;
  int get kepepetCount => entries.length - amanCount;
}

class AutomationService {
  final FirebaseService firebase;
  AutomationService({FirebaseService? firebase})
    : firebase = firebase ?? FirebaseService();

  Future<SmartQueueResult> generateSmartQueue({
    required int targetStock,
    required String registrationId,
  }) async {
    if (targetStock <= 0 || registrationId.isEmpty)
      return const SmartQueueResult([]);
    final customers = await firebase.getAllPelanggan(registrationId);
    final today = DateTime.now();
    final startToday = DateTime(today.year, today.month, today.day);
    final eligible = <Pelanggan>[];
    for (final customer in customers) {
      if (customer.sisaKuotaHarian <= 0 || customer.sisaKuotaBulanan <= 0) {
        continue;
      }
      final last = customer.lastTransactedAt;
      final samePangkalan = customer.lastTransactionPangkalan == registrationId;
      if (samePangkalan && last != null) {
        final days = startToday
            .difference(DateTime(last.year, last.month, last.day))
            .inDays;
        if (days < 2) continue;
      }
      eligible.add(customer);
    }
    eligible.sort((a, b) => a.sisaKuotaHarian.compareTo(b.sisaKuotaHarian));
    final selected = <SmartQueueEntry>[];
    for (final customer in eligible) {
      if (selected.length >= targetStock) break;
      selected.add(SmartQueueEntry(pelanggan: customer, aman: true));
    }
    return SmartQueueResult(selected);
  }
}
