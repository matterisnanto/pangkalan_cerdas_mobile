import 'package:flutter/material.dart';
import '../../providers/transaction_queue_provider.dart';

class QueueProgressWidget extends StatelessWidget {
  final TransactionQueueProvider txQueue;

  const QueueProgressWidget({super.key, required this.txQueue});

  @override
  Widget build(BuildContext context) {
    if (txQueue.status == QueueStatus.idle && txQueue.totalQueue == 0) {
      return const SizedBox.shrink();
    }
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Antrean: ${txQueue.currentIndex}/${txQueue.totalQueue}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(value: txQueue.progress),
            const SizedBox(height: 6),
            Row(
              children: [
                _chip('Berhasil', txQueue.successCount, Colors.green),
                const SizedBox(width: 8),
                _chip('Gagal', txQueue.failCount, Colors.red),
                const Spacer(),
                Text(
                  txQueue.status.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    color: txQueue.needsTokenRefresh
                        ? Colors.red
                        : Colors.blue.shade800,
                  ),
                ),
              ],
            ),
            if (txQueue.lastError != null) ...[
              const SizedBox(height: 4),
              Text(
                txQueue.lastError!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, int count, Color color) {
    return Chip(
      label: Text(
        '$label: $count',
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      backgroundColor: color,
      visualDensity: VisualDensity.compact,
    );
  }
}
