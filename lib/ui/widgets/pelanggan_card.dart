import 'package:flutter/material.dart';
import '../../models/pelanggan_model.dart';
import '../theme/app_theme.dart';

class PelangganCard extends StatelessWidget {
  final Pelanggan pelanggan;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onHistory;

  const PelangganCard({
    super.key,
    required this.pelanggan,
    required this.onTap,
    this.onEdit,
    this.onDelete,
    this.onHistory,
  });
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF);
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    final q = pelanggan.sisaKuotaBulanan;
    final kuotaColor = q <= 0
        ? const Color(0xFFDC2626)
        : q <= 2
            ? const Color(0xFFD97706)
            : const Color(0xFF00AA5B);
    final kuotaStatus = q <= 0
        ? '🔴 Kuota Habis'
        : q <= 2
            ? '🟡 Mode Kepepet'
            : '🟢 Sisa Kuota';

    final isUmkm = pelanggan.kategori.toLowerCase().contains('umkm') ||
        pelanggan.kategori.toLowerCase().contains('usaha');
    final katColor = isUmkm ? const Color(0xFF7C3AED) : const Color(0xFF0063F7);
    final initial = pelanggan.nama.trim().isEmpty ? '?' : pelanggan.nama.trim()[0].toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1.2),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppTheme.emerald.withValues(alpha: isDark ? 0.25 : 0.12),
                      foregroundColor: isDark ? const Color(0xFF10B981) : AppTheme.emerald,
                      child: Text(initial, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pelanggan.nama,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            pelanggan.nik,
                            style: TextStyle(color: textSecondary, fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: katColor.withValues(alpha: isDark ? 0.22 : 0.10),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: katColor.withValues(alpha: 0.35)),
                      ),
                      child: Text(pelanggan.displayKategori, style: TextStyle(color: katColor, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (pelanggan.tanggalLahir != null && pelanggan.tanggalLahir!.isNotEmpty)
                  _info(Icons.cake_outlined, 'Lahir: ${pelanggan.tanggalLahir}', textSecondary),
                if (pelanggan.alamat != null && pelanggan.alamat!.isNotEmpty)
                  _info(Icons.location_on_outlined, pelanggan.alamat!, textSecondary),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: kuotaColor.withValues(alpha: isDark ? 0.20 : 0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kuotaColor.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(kuotaStatus, style: TextStyle(color: kuotaColor, fontSize: 12, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 6),
                      Text('• Sisa Kuota: $q Tabung', style: TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Divider(height: 1, color: cardBorder),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _capsule('Riwayat', Icons.receipt_long_outlined, const Color(0xFF0063F7), isDark, onHistory ?? onTap),
                    const SizedBox(width: 8),
                    _capsule('Edit', Icons.edit_outlined, const Color(0xFF00AA5B), isDark, onEdit),
                    const SizedBox(width: 8),
                    _capsule('Hapus', Icons.delete_outline, const Color(0xFFDC2626), isDark, onDelete),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _info(IconData icon, String text, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: color, height: 1.3)),
        ),
      ],
    ),
  );

  Widget _capsule(String label, IconData icon, Color color, bool isDark, VoidCallback? onTap) => Material(
    color: color.withValues(alpha: isDark ? 0.16 : 0.08),
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    ),
  );
}
