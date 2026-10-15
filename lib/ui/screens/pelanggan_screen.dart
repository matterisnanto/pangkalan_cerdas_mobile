import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../models/pelanggan_model.dart';
import '../../services/pelanggan_service.dart';
import '../../services/excel_service.dart';
import '../../services/firebase_service.dart';
import '../../services/batch_verification_service.dart';
import '../../services/mypertamina_api_service.dart';
import '../../providers/auth_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/pelanggan_card.dart';
import '../widgets/pelanggan_form_dialog.dart';
import '../widgets/pelanggan_detail_modal.dart';

class PelangganScreen extends StatefulWidget {
  const PelangganScreen({super.key});

  @override
  State<PelangganScreen> createState() => _PelangganScreenState();
}

class _PelangganScreenState extends State<PelangganScreen> {
  final PelangganService _service = PelangganService();
  final TextEditingController _searchCtrl = TextEditingController();

  String _searchQuery = '';
  String _selectedKategori = 'Semua';
  bool _isExporting = false;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text;
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade800 : Colors.teal.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _handleExport() async {
    setState(() => _isExporting = true);
    try {
      final list = await _service.getAllPelanggan();
      if (list.isEmpty) {
        _showSnack('Tidak ada data pelanggan untuk diekspor', isError: true);
        return;
      }
      final path = await ExcelService.exportPelanggan(pelangganList: list);
      _showSnack('Berhasil diekspor: $path');
    } catch (e) {
      _showSnack('Gagal ekspor: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _handleImport() async {
    setState(() => _isImporting = true);
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'csv'],
        withData: false,
      );
      final path = picked?.files.single.path;
      if (path == null) {
        _showSnack('Pemilihan file dibatalkan', isError: true);
        return;
      }
      final auth = context.read<AuthProvider>();
      if (auth.registrationId.isEmpty) {
        _showSnack('Profil pangkalan belum tersedia', isError: true);
        return;
      }
      final list = await ExcelService.importPelanggan(
        filePath: path,
        registrationId: auth.registrationId,
      );
      if (list.isEmpty) {
        _showSnack('File .xlsx tidak memuat data yang valid', isError: true);
        return;
      }

      final result =
          await BatchVerificationService(
            api: MyPertaminaApiService(auth.apiClient),
            firebase: FirebaseService(),
          ).batchVerifyAndSyncWithMyPertamina(
            customers: list,
            registrationId: auth.registrationId,
          );
      _showSnack(
        'Import selesai: ${result.verified} terverifikasi, ${result.failed} gagal',
      );
    } catch (e) {
      _showSnack('Gagal import: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  void _openFormDialog({Pelanggan? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PelangganFormDialog(
        existing: existing,
        onSave: (pelanggan) async {
          try {
            if (existing != null) {
              await _service.updatePelanggan(pelanggan);
              _showSnack('Data pelanggan berhasil diperbarui');
            } else {
              await _service.addPelanggan(pelanggan);
              _showSnack('Pelanggan berhasil ditambahkan');
            }
          } catch (e) {
            _showSnack('Gagal menyimpan: $e', isError: true);
          }
        },
      ),
    );
  }

  void _openDetailSheet(Pelanggan p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PelangganDetailModal(
        pelanggan: p,
        onEdit: () {
          Navigator.pop(ctx);
          _openFormDialog(existing: p);
        },
        onDelete: () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (dCtx) => AlertDialog(
              backgroundColor: const Color(0xFF1E1B4B),
              title: const Text(
                'Hapus Pelanggan?',
                style: TextStyle(color: Colors.white),
              ),
              content: Text(
                'Yakin ingin menghapus ${p.nama} (${p.nik})?',
                style: const TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dCtx, false),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => Navigator.pop(dCtx, true),
                  child: const Text(
                    'Hapus',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          );
          if (confirm == true) {
            if (ctx.mounted) Navigator.pop(ctx);
            if (p.id != null) {
              await _service.deletePelanggan(p.id!);
            } else {
              await _service.deletePelanggan(p.nik);
            }
            _showSnack('Pelanggan telah dihapus');
          }
        },
      ),
    );
  }

  Widget _filterChip(String label) {
    final selected = _selectedKategori == label;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _selectedKategori = label),
      selectedColor: const Color(0xFF00AA5B),
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.black87,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      shape: const StadiumBorder(side: BorderSide(color: Color(0xFFE0E0E0))),
    );
  }

  Widget _iconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool loading = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: loading ? null : onTap,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.25)),
            ),
            child: loading
                ? const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  )
                : Icon(icon, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Data Pelanggan',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Master data & kuota LPG 3Kg',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
          Row(
            children: [
              _iconButton(
                icon: Icons.upload_file,
                tooltip: 'Import Excel',
                loading: _isImporting,
                onTap: _handleImport,
              ),
              const SizedBox(width: 6),
              _iconButton(
                icon: Icons.download,
                tooltip: 'Ekspor Excel',
                loading: _isExporting,
                onTap: _handleExport,
              ),
              const SizedBox(width: 6),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF06B6D4),
                  foregroundColor: Colors.black,
                  elevation: 4,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text(
                  'Tambah',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                onPressed: () => _openFormDialog(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: TextField(
        controller: _searchCtrl,
        decoration: InputDecoration(
          hintText: 'Cari NIK atau Nama...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: _searchCtrl.clear,
                ),
          filled: true,
          fillColor: const Color(0xFFF1F3F5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTopBar(),
            _buildSearchBar(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  _filterChip('Semua'),
                  const SizedBox(width: 8),
                  _filterChip('Rumah Tangga'),
                  const SizedBox(width: 8),
                  _filterChip('UMKM'),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Pelanggan>>(
                stream: _service.streamPelanggan(
                  search: _searchQuery,
                  kategori: _selectedKategori,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF06B6D4),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: GlassCard(
                        margin: const EdgeInsets.all(24),
                        child: Text(
                          'Terjadi kesalahan: ${snapshot.error}',
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    );
                  }
                  final list = snapshot.data ?? [];
                  if (list.isEmpty) {
                    return Center(
                      child: GlassCard(
                        margin: const EdgeInsets.all(24),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 48,
                              color: Colors.white.withOpacity(0.4),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Tidak ada pelanggan ditemukan'
                                  : 'Belum ada data pelanggan',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Impor dari Excel (.xlsx) atau tambahkan secara manual.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: list.length,
                    itemBuilder: (context, idx) {
                      final p = list[idx];
                      return PelangganCard(
                        pelanggan: p,
                        onTap: () => _openDetailSheet(p),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
