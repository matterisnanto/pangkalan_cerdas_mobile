import 'package:flutter/material.dart';
import '../../models/pelanggan_model.dart';
import '../../services/pelanggan_service.dart';
import 'glass_card.dart';

class PelangganPickerDialog extends StatefulWidget {
  final ValueChanged<Pelanggan> onSelected;

  const PelangganPickerDialog({super.key, required this.onSelected});

  @override
  State<PelangganPickerDialog> createState() => _PelangganPickerDialogState();
}

class _PelangganPickerDialogState extends State<PelangganPickerDialog> {
  final PelangganService _service = PelangganService();
  final _nikCtrl = TextEditingController();
  final _namaCtrl = TextEditingController();
  final _tglCtrl = TextEditingController();
  final _kategoriCtrl = TextEditingController(text: 'Rumah Tangga');
  final _formKey = GlobalKey<FormState>();

  List<Pelanggan> _masterList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMaster();
  }

  Future<void> _loadMaster() async {
    final list = await _service.getAllPelanggan();
    if (mounted) {
      setState(() {
        _masterList = list;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _nikCtrl.dispose();
    _namaCtrl.dispose();
    _tglCtrl.dispose();
    _kategoriCtrl.dispose();
    super.dispose();
  }

  void _applyPelanggan(Pelanggan p) {
    setState(() {
      _nikCtrl.text = p.nik;
      _namaCtrl.text = p.nama;
      _tglCtrl.text = p.tanggalLahir ?? '';
      _kategoriCtrl.text = p.kategori;
    });
  }

  Widget _fieldRow(
    String label,
    TextEditingController ctrl,
    IconData icon, {
    bool isRequired = false,
  }) {
    return TextFormField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      validator: isRequired
          ? (v) => (v == null || v.trim().isEmpty) ? '$label wajib diisi' : null
          : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: 13,
        ),
        prefixIcon: Icon(icon, color: Colors.white70, size: 20),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF06B6D4), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
    );
  }

  Widget _buildAutocomplete() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF06B6D4)),
      );
    }
    return Autocomplete<Pelanggan>(
      displayStringForOption: (p) => '${p.nama} (${p.nik})',
      optionsBuilder: (val) {
        if (val.text.isEmpty) return _masterList.take(5);
        final q = val.text.toLowerCase();
        return _masterList.where(
          (p) => p.nama.toLowerCase().contains(q) || p.nik.contains(q),
        );
      },
      onSelected: _applyPelanggan,
      fieldViewBuilder: (ctx, textCtrl, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: textCtrl,
          focusNode: focusNode,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            labelText: 'Cari Master Pelanggan (Nama / NIK)',
            labelStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
            ),
            prefixIcon: const Icon(
              Icons.search,
              color: Color(0xFF06B6D4),
              size: 20,
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.08),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: Color(0xFF06B6D4),
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: GlassCard(
        margin: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        padding: const EdgeInsets.all(20),
        borderRadius: BorderRadius.circular(24),
        backgroundColor: const Color(0xFF1E1B4B).withValues(alpha: 0.95),
        borderColor: Colors.white.withValues(alpha: 0.35),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Pilih dari Master Pelanggan',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildAutocomplete(),
                const SizedBox(height: 14),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 14),
                _fieldRow(
                  'NIK',
                  _nikCtrl,
                  Icons.badge_outlined,
                  isRequired: true,
                ),
                const SizedBox(height: 10),
                _fieldRow(
                  'Nama',
                  _namaCtrl,
                  Icons.person_outline,
                  isRequired: true,
                ),
                const SizedBox(height: 10),
                _fieldRow('Tanggal Lahir', _tglCtrl, Icons.cake_outlined),
                const SizedBox(height: 10),
                _fieldRow(
                  'Kategori',
                  _kategoriCtrl,
                  Icons.category_outlined,
                  isRequired: true,
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF06B6D4),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.playlist_add, size: 20),
                  label: const Text(
                    'Salin ke Antrean Transaksi',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  onPressed: () {
                    if (!_formKey.currentState!.validate()) return;
                    final selected = Pelanggan(
                      nik: _nikCtrl.text.trim(),
                      nama: _namaCtrl.text.trim(),
                      tanggalLahir: _tglCtrl.text.trim().isNotEmpty
                          ? _tglCtrl.text.trim()
                          : null,
                      kategori: _kategoriCtrl.text.trim().isNotEmpty
                          ? _kategoriCtrl.text.trim()
                          : 'Rumah Tangga',
                    );
                    Navigator.pop(context);
                    widget.onSelected(selected);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
