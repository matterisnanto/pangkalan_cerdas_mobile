import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/pelanggan_model.dart';
import '../theme/app_theme.dart';

class PelangganFormDialog extends StatefulWidget {
  final Pelanggan? existing;
  final ValueChanged<Pelanggan> onSave;

  const PelangganFormDialog({super.key, this.existing, required this.onSave});

  @override
  State<PelangganFormDialog> createState() => _PelangganFormDialogState();
}

class _PelangganFormDialogState extends State<PelangganFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nikCtrl;
  late final TextEditingController _namaCtrl;
  late final TextEditingController _tglCtrl;
  late final TextEditingController _alamatCtrl;
  late String _kategori;

  @override
  void initState() {
    super.initState();
    _nikCtrl = TextEditingController(text: widget.existing?.nik ?? '');
    _namaCtrl = TextEditingController(text: widget.existing?.nama ?? '');
    _tglCtrl = TextEditingController(text: widget.existing?.tanggalLahir ?? '');
    _alamatCtrl = TextEditingController(text: widget.existing?.alamat ?? '');
    _kategori = widget.existing?.kategori ?? 'Rumah Tangga';
  }

  @override
  void dispose() {
    _nikCtrl.dispose();
    _namaCtrl.dispose();
    _tglCtrl.dispose();
    _alamatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
                      Text(
                        isEdit ? 'Edit Pelanggan' : 'Tambah Pelanggan Baru',
                        style: const TextStyle(
                          color: AppTheme.ink,
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
                  _field(
                    _nikCtrl,
                    'NIK (16 Digit)',
                    '3201...',
                    Icons.badge_outlined,
                    keyboard: TextInputType.number,
                    formatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(16),
                    ],
                    validator: (v) => (v == null || v.trim().length != 16)
                        ? 'NIK harus 16 digit angka'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  _field(
                    _namaCtrl,
                    'Nama Lengkap',
                    'Nama sesuai KTP',
                    Icons.person_outline,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Nama wajib diisi'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  _field(
                    _tglCtrl,
                    'Tanggal Lahir (YYYY-MM-DD)',
                    'Pilih dari kalender',
                    Icons.cake_outlined,
                    readOnly: true,
                    onTap: _pickDate,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Kategori Pelanggan',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(child: _catPill('Rumah Tangga')),
                      const SizedBox(width: 8),
                      Expanded(child: _catPill('UMKM')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _field(
                    _alamatCtrl,
                    'Alamat (Opsional)',
                    'Jl. Melati No. 12',
                    Icons.home_outlined,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: BorderSide(
                              color: Colors.white.withOpacity(0.3),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Batal'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF06B6D4),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _submit,
                          child: Text(
                            isEdit ? 'Simpan' : 'Tambah',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _catPill(String cat) {
    final isSelected = _kategori == cat;
    return GestureDetector(
      onTap: () => setState(() => _kategori = cat),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF06B6D4).withOpacity(0.3)
              : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF06B6D4)
                : Colors.white.withOpacity(0.2),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Center(
          child: Text(
            cat,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white60,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    DateTime initial = DateTime(1990, 1, 1);
    if (_tglCtrl.text.isNotEmpty) {
      final parsed = DateTime.tryParse(_tglCtrl.text);
      if (parsed != null) initial = parsed;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF06B6D4),
            onPrimary: Colors.black,
            surface: Color(0xFF1E1B4B),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _tglCtrl.text =
            '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final p = Pelanggan(
      id: widget.existing?.id,
      nik: _nikCtrl.text.trim(),
      nama: _namaCtrl.text.trim(),
      tanggalLahir: _tglCtrl.text.trim().isNotEmpty
          ? _tglCtrl.text.trim()
          : null,
      kategori: _kategori,
      alamat: _alamatCtrl.text.trim().isNotEmpty
          ? _alamatCtrl.text.trim()
          : null,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );
    Navigator.pop(context);
    widget.onSave(p);
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String hint,
    IconData icon, {
    bool readOnly = false,
    VoidCallback? onTap,
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      keyboardType: keyboard,
      inputFormatters: formatters,
      validator: validator,
      maxLines: maxLines,
      style: const TextStyle(color: AppTheme.ink, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(0.7),
          fontSize: 13,
        ),
        hintStyle: TextStyle(
          color: Colors.white.withOpacity(0.3),
          fontSize: 13,
        ),
        prefixIcon: Icon(icon, color: Colors.white70, size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
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
}
