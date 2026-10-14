import 'package:flutter/material.dart';
import '../../models/pelanggan_model.dart';
import '../theme/app_theme.dart';

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
    final q = pelanggan.sisaKuotaBulanan;
    final status = q <= 0
        ? 'Habis'
        : q <= 2
        ? 'Kepepet'
        : 'Aman';
    final color = q <= 0
        ? Colors.red
        : q <= 2
        ? Colors.amber.shade800
        : AppTheme.emerald;
    final initial = pelanggan.nama.trim().isEmpty
        ? '?'
        : pelanggan.nama.trim()[0].toUpperCase();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200, width: 1.2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.emerald.withValues(alpha: .12),
                    foregroundColor: AppTheme.emerald,
                    child: Text(
                      initial,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      pelanggan.nama,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  _pill(pelanggan.displayKategori, AppTheme.indigo),
                ],
              ),
              const SizedBox(height: 10),
              _info(Icons.badge_outlined, 'NIK: ${pelanggan.nik}'),
              if (pelanggan.tanggalLahir?.isNotEmpty == true)
                _info(Icons.cake_outlined, pelanggan.tanggalLahir!),
              if (pelanggan.alamat?.isNotEmpty == true)
                _info(Icons.location_on_outlined, pelanggan.alamat!),
              const SizedBox(height: 8),
              _pill('Sisa Kuota: $q Tabung • $status', color),
            ],
          ),
        ),
      ),
    );
  }

  Widget _info(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Icon(icon, size: 15, color: Colors.black54),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    ),
  );
  Widget _pill(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
    ),
  );
}
