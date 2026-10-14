import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/log_transaksi.dart';

class LogTransaksiTable extends StatelessWidget {
  final List<LogTransaksi> logs;
  final Function(LogTransaksi) onRetrySingle;

  const LogTransaksiTable({
    super.key,
    required this.logs,
    required this.onRetrySingle,
  });

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: const Text(
          'Belum ada log transaksi',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final dateFormat = DateFormat('dd/MM HH:mm');

    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: logs.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final log = logs[index];
          final isBerhasil = log.isBerhasil;

          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: isBerhasil ? Colors.green : Colors.red,
              child: Icon(
                isBerhasil ? Icons.check : Icons.close,
                color: Colors.white,
                size: 16,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    log.nama.isEmpty ? log.nik : log.nama,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  dateFormat.format(log.timestamp),
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NIK: ${log.nik} | ${log.kategori} | ${log.jumlahTabung} Tabung',
                  style: const TextStyle(fontSize: 11),
                ),
                if (!isBerhasil && log.pesanError != null)
                  Text(
                    log.pesanError!,
                    style: const TextStyle(color: Colors.red, fontSize: 11),
                  ),
                if (isBerhasil && log.refNo != null)
                  Text(
                    'Ref: ${log.refNo}',
                    style: const TextStyle(color: Colors.green, fontSize: 11),
                  ),
              ],
            ),
            trailing: !isBerhasil
                ? IconButton(
                    icon: const Icon(
                      Icons.refresh,
                      color: Colors.orange,
                      size: 20,
                    ),
                    tooltip: 'Retry NIK ini',
                    onPressed: () => onRetrySingle(log),
                  )
                : null,
          );
        },
      ),
    );
  }
}
