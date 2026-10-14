import 'package:flutter/material.dart';
import '../../models/pelanggan_model.dart';
import 'glass_card.dart';

class PelangganCard extends StatelessWidget {
  final Pelanggan pelanggan;
  final VoidCallback onTap;

  const PelangganCard({
    super.key,
    required this.pelanggan,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isUmkm = pelanggan.kategori == 'UMKM';

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      borderRadius: BorderRadius.circular(18),
      backgroundColor: Colors.white.withOpacity(0.12),
      borderColor: Colors.white.withOpacity(0.25),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: isUmkm
                    ? [const Color(0xFFA855F7), const Color(0xFF6366F1)]
                    : [const Color(0xFF06B6D4), const Color(0xFF3B82F6)],
              ),
            ),
            child: Icon(
              isUmkm ? Icons.storefront : Icons.person,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        pelanggan.nama,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isUmkm
                            ? const Color(0xFFA855F7).withOpacity(0.2)
                            : const Color(0xFF06B6D4).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isUmkm
                              ? const Color(0xFFA855F7).withOpacity(0.5)
                              : const Color(0xFF06B6D4).withOpacity(0.5),
                        ),
                      ),
                      child: Text(
                        pelanggan.kategori,
                        style: TextStyle(
                          color: isUmkm
                              ? const Color(0xFFC084FC)
                              : const Color(0xFF67E8F9),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'NIK: ${pelanggan.nik}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                _quotaBadge(),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (pelanggan.tanggalLahir != null &&
                        pelanggan.tanggalLahir!.isNotEmpty) ...[
                      Icon(
                        Icons.cake_outlined,
                        size: 13,
                        color: Colors.white.withOpacity(0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        pelanggan.tanggalLahir!,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.65),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            Icons.chevron_right,
            color: Colors.white.withOpacity(0.4),
            size: 20,
          ),
        ],
      ),
    );
  Widget _quotaBadge() {
    final value = pelanggan.sisaKuotaBulanan;
    final color = value == null || value > 0 ? const Color(0xFF34D399) : const Color(0xFFF87171);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(0.16), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.45))),
      child: Text(value == null ? 'Kuota belum disinkronkan' : 'Sisa Kuota Bulanan: $value Tabung', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}
