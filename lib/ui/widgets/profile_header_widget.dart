import 'package:flutter/material.dart';

class ProfileHeaderWidget extends StatelessWidget {
  final String storeName;
  final String registrationId;
  final int stockAvailable;

  const ProfileHeaderWidget({
    super.key,
    required this.storeName,
    required this.registrationId,
    required this.stockAvailable,
  });

  @override
  Widget build(BuildContext context) {
    final hasData = registrationId.isNotEmpty;

    return Card(
      elevation: 3,
      color: Colors.blue.shade800,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: hasData
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.store, color: Colors.white, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          storeName.isEmpty ? 'Pangkalan' : storeName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('ID: $registrationId',
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('Stok Tersedia: $stockAvailable tabung',
                      style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ],
              )
            : const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white70),
                  SizedBox(width: 10),
                  Text('Belum login. Buka WebView untuk login.',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
      ),
    );
  }
}
