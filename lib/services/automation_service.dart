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
    final now = DateTime.now();
    final aman = <Pelanggan>[];
    final kepepet = <Pelanggan>[];
    for (final customer in customers) {
      if (customer.sisaKuotaHarian <= 0 || customer.sisaKuotaBulanan <= 0)
        continue;
      final last = customer.lastTransactedAt;
      final days = last == null
          ? null
          : DateTime(
              now.year,
              now.month,
              now.day,
            ).difference(DateTime(last.year, last.month, last.day)).inDays;
      (days == null || days >= 2 ? aman : kepepet).add(customer);
    }
    final selected = <SmartQueueEntry>[];
    for (final customer in [...aman, ...kepepet]) {
      if (selected.length >= targetStock) break;
      selected.add(
        SmartQueueEntry(pelanggan: customer, aman: aman.contains(customer)),
      );
    }
    return SmartQueueResult(selected);
  }
}
