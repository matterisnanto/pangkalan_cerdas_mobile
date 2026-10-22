import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/pelanggan_model.dart';
import '../../models/log_transaksi.dart';
import '../../services/pelanggan_service.dart';

class PelangganDetailModal extends StatelessWidget {
  final Pelanggan pelanggan;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const PelangganDetailModal({
    super.key,
    required this.pelanggan,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final modalBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final modalBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final isUmkm = pelanggan.kategori.toLowerCase().contains('umkm') ||
        pelanggan.kategori.toLowerCase().contains('usaha');
    final service = PelangganService();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      decoration: BoxDecoration(
        color: modalBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: modalBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pelanggan.nama,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'NIK: ${pelanggan.nik}',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 13,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _badge(
                  icon: isUmkm ? Icons.storefront : Icons.home,
                  text: pelanggan.kategori,
                  color: isUmkm
                      ? const Color(0xFF8B5CF6)
                      : const Color(0xFF0063F7),
                ),
                if (pelanggan.tanggalLahir != null &&
                    pelanggan.tanggalLahir!.isNotEmpty)
                  _badge(
                    icon: Icons.cake_outlined,
                    text: pelanggan.tanggalLahir!,
                    color: const Color(0xFF0284C7),
                  ),
              ],
            ),
            if (pelanggan.alamat != null && pelanggan.alamat!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    color: textSecondary,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      pelanggan.alamat!,
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            Divider(color: modalBorder, height: 24),
            Row(
              children: [
                const Icon(Icons.history, color: Color(0xFF0063F7), size: 18),
                const SizedBox(width: 8),
                Text(
                  'Riwayat Transaksi LPG 3Kg',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<LogTransaksi>>(
                future: service.getCustomerTransactions(pelanggan.nik),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF0063F7),
                      ),
                    );
                  }
                  final logs = snapshot.data ?? [];
                  if (logs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Belum ada riwayat transaksi LPG untuk pelanggan ini',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }

                  final df = DateFormat('dd MMM yyyy, HH:mm');
                  final logBg = isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF8FAFC);

                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: logs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, idx) {
                      final log = logs[idx];
                      final isSuccess = log.isSuccess;
                      final statusColor = isSuccess
                          ? (isDark ? const Color(0xFF34D399) : const Color(0xFF059669))
                          : (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626));

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: logBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSuccess
                                ? statusColor.withValues(alpha: 0.3)
                                : statusColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSuccess ? Icons.check_circle : Icons.error,
                              color: statusColor,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${log.jumlahTabung} Tabung • ${log.status}',
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (log.pesanError != null &&
                                      log.pesanError!.isNotEmpty)
                                    Text(
                                      log.pesanError!,
                                      style: TextStyle(
                                        color: textSecondary,
                                        fontSize: 11,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  Text(
                                    df.format(log.timestamp),
                                    style: TextStyle(
                                      color: textSecondary.withValues(alpha: 0.7),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(
                        color: Color(0xFFDC2626),
                        width: 1.2,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Hapus'),
                    onPressed: onDelete,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00AA5B),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.edit, size: 18, color: Colors.white),
                    label: const Text(
                      'Edit Data',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    onPressed: onEdit,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
