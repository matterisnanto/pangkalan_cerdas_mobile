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
import '../../providers/customer_provider.dart';
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
        backgroundColor: isError
            ? Colors.red.shade800
            : const Color(0xFF00AA5B),
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
      if (!mounted) return;
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

  Future<void> _confirmDeletePelanggan(Pelanggan p) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark
        ? const Color(0xFFF8FAFC)
        : const Color(0xFF0F172A);
    final textSecondary = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF475569);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Hapus Pelanggan?',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        content: Text(
          'Yakin ingin menghapus ${p.nama} (${p.nik})? Data yang dihapus tidak dapat dipulihkan.',
          style: TextStyle(color: textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: Text(
              'Batal',
              style: TextStyle(
                color: textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text(
              'Hapus',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (p.id != null) {
        await _service.deletePelanggan(p.id!);
      } else {
        await _service.deletePelanggan(p.nik);
      }
      _showSnack('Pelanggan telah dihapus');
    }
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
          Navigator.pop(ctx);
          await _confirmDeletePelanggan(p);
        },
      ),
    );
  }

  Widget _filterChip(
    String label, {
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final selected = _selectedKategori == label;
    final chipBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final chipBorder = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFCBD5E1);

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _selectedKategori = label),
      selectedColor: const Color(0xFF00AA5B),
      backgroundColor: chipBg,
      labelStyle: TextStyle(
        color: selected ? Colors.white : textSecondary,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
        fontSize: 12,
      ),
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? const Color(0xFF00AA5B) : chipBorder,
          width: 1.1,
        ),
      ),
    );
  }

  Widget _iconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required bool isDark,
    required Color textPrimary,
    bool loading = false,
  }) {
    final btnBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final btnBorder = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFCBD5E1);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: btnBg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: loading ? null : onTap,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: btnBorder),
            ),
            child: loading
                ? Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: textPrimary,
                      ),
                    ),
                  )
                : Icon(icon, color: textPrimary, size: 19),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar({
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Data Pelanggan',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Master data & kuota LPG 3Kg',
                style: TextStyle(color: textSecondary, fontSize: 12),
              ),
            ],
          ),
          Row(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00AA5B),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isImporting ? null : _handleImport,
                icon: _isImporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.file_upload_outlined,
                        size: 18,
                        color: Colors.white,
                      ),
                label: const Text(
                  'Import Excel',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _iconButton(
                icon: Icons.download_outlined,
                tooltip: 'Ekspor Excel (.xlsx)',
                loading: _isExporting,
                onTap: _handleExport,
                isDark: isDark,
                textPrimary: textPrimary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar({
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final searchBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final searchBorder = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFCBD5E1);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: TextField(
        controller: _searchCtrl,
        style: TextStyle(
          color: textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Cari NIK atau Nama...',
          hintStyle: TextStyle(
            color: textSecondary.withValues(alpha: 0.7),
            fontSize: 14,
          ),
          prefixIcon: Icon(Icons.search, color: textSecondary, size: 20),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.clear, color: textSecondary, size: 18),
                  onPressed: _searchCtrl.clear,
                ),
          filled: true,
          fillColor: searchBg,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: searchBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: searchBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: Color(0xFF00AA5B), width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildQuotaSyncBanner({required bool isDark}) {
    return Consumer<CustomerProvider>(
      builder: (context, provider, child) {
        debugPrint(
          '📊 [UI REBUILD] isSyncing: ${provider.isSyncingQuota} | '
          'Progress: ${provider.syncCurrentIndex} / ${provider.syncTotalCount}',
        );
        if (!provider.isSyncingQuota) return const SizedBox.shrink();
        final total = provider.syncTotalCount;
        final current = provider.syncCurrentIndex;
        final double progress = total > 0
            ? (current / total).clamp(0.0, 1.0).toDouble()
            : 0.0;
        final percent = (progress * 100).round();
        return AnimatedSize(
          duration: const Duration(milliseconds: 220),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF064E3B) : const Color(0xFFE6F4EA),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Memperbarui Kuota: $current / $total Pelanggan ($percent%)',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF14532D),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 9),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: progress),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    builder: (context, animatedProgress, child) =>
                        LinearProgressIndicator(
                          value: animatedProgress,
                          minHeight: 7,
                          backgroundColor: isDark
                              ? Colors.white24
                              : Colors.white,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF00AA5B),
                          ),
                        ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? const Color(0xFFF8FAFC)
        : const Color(0xFF0F172A);
    final textSecondary = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF475569);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openFormDialog(),
        backgroundColor: const Color(0xFF00AA5B),
        elevation: 4,
        icon: const Icon(Icons.person_add_alt_1, color: Colors.white, size: 20),
        label: const Text(
          'Tambah Pelanggan',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTopBar(
              isDark: isDark,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            _buildSearchBar(
              isDark: isDark,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            _buildQuotaSyncBanner(isDark: isDark),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  _filterChip(
                    'Semua',
                    isDark: isDark,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                  const SizedBox(width: 8),
                  _filterChip(
                    'Rumah Tangga',
                    isDark: isDark,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                  const SizedBox(width: 8),
                  _filterChip(
                    'UMKM',
                    isDark: isDark,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
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
                        color: Color(0xFF00AA5B),
                      ),
                    );
                  }
                  final emptyCardBg = isDark
                      ? const Color(0xFF1E293B)
                      : Colors.white;
                  final emptyCardBorder = isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0);

                  if (snapshot.hasError) {
                    return Center(
                      child: Container(
                        margin: const EdgeInsets.all(24),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: emptyCardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFDC2626)),
                        ),
                        child: Text(
                          'Terjadi kesalahan: ${snapshot.error}',
                          style: const TextStyle(color: Color(0xFFDC2626)),
                        ),
                      ),
                    );
                  }
                  final list = snapshot.data ?? [];
                  if (list.isEmpty) {
                    return Center(
                      child: Container(
                        margin: const EdgeInsets.all(24),
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: emptyCardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: emptyCardBorder),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 52,
                              color: textSecondary.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Tidak ada pelanggan ditemukan'
                                  : 'Belum ada data pelanggan',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Impor dari Excel (.xlsx) atau tekan tombol Tambah Pelanggan di bawah.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return RefreshIndicator(
                    color: const Color(0xFF00AA5B),
                    onRefresh: () async {
                      try {
                        await context
                            .read<CustomerProvider>()
                            .syncAllCustomersQuotaFromMyPertamina();
                        _showSnack(
                          'Sisa kuota seluruh pelanggan berhasil diperbarui!',
                        );
                      } catch (e) {
                        _showSnack(
                          e.toString().replaceFirst('Bad state: ', ''),
                          isError: true,
                        );
                      }
                    },
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      itemCount: list.length,
                      itemBuilder: (context, idx) {
                        final p = list[idx];
                        return PelangganCard(
                          pelanggan: p,
                          onTap: () => _openDetailSheet(p),
                          onEdit: () => _openFormDialog(existing: p),
                          onDelete: () => _confirmDeletePelanggan(p),
                          onHistory: () => _openDetailSheet(p),
                        );
                      },
                    ),
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
