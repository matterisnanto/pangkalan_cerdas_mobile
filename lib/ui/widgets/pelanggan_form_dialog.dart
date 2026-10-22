import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/pelanggan_model.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final modalBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF);
    final modalBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final fieldFill = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
    final primaryColor = const Color(0xFF00AA5B);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: modalBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(
            top: BorderSide(color: modalBorder, width: 1.5),
            left: BorderSide(color: modalBorder, width: 1.5),
            right: BorderSide(color: modalBorder, width: 1.5),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
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
                          isEdit ? 'Edit Data Pelanggan' : 'Tambah Pelanggan Baru',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: textSecondary, size: 22),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _field(
                      _nikCtrl,
                      'NIK Pelanggan (16 Digit)',
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
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      fieldFill: fieldFill,
                      primaryColor: primaryColor,
                    ),
                    const SizedBox(height: 12),
                    _field(
                      _namaCtrl,
                      'Nama Lengkap Pelanggan',
                      'Nama sesuai KTP...',
                      Icons.person_outline,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Nama wajib diisi'
                          : null,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      fieldFill: fieldFill,
                      primaryColor: primaryColor,
                    ),
                    const SizedBox(height: 12),
                    _dropdownKategori(
                      isDark: isDark,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      fieldFill: fieldFill,
                      modalBorder: modalBorder,
                      primaryColor: primaryColor,
                    ),
                    const SizedBox(height: 12),
                    _field(
                      _alamatCtrl,
                      'Alamat Lengkap Pelanggan',
                      'Jl. Nama Jalan, RT/RW, dsb...',
                      Icons.home_outlined,
                      maxLines: 2,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      fieldFill: fieldFill,
                      primaryColor: primaryColor,
                    ),
                    const SizedBox(height: 12),
                    _field(
                      _tglCtrl,
                      'Tanggal Lahir (Opsional)',
                      'Pilih tanggal lahir...',
                      Icons.cake_outlined,
                      readOnly: true,
                      onTap: () => _pickDate(isDark, modalBg, textPrimary, primaryColor),
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      fieldFill: fieldFill,
                      primaryColor: primaryColor,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: textSecondary,
                              side: BorderSide(color: modalBorder, width: 1.2),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              'Batal',
                              style: TextStyle(
                                color: textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00AA5B),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.save_outlined, size: 18, color: Colors.white),
                            label: const Text(
                              'Simpan Data Pelanggan',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: Colors.white,
                              ),
                            ),
                            onPressed: _submit,
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
      ),
    );
  }

  Widget _dropdownKategori({
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required Color fieldFill,
    required Color modalBorder,
    required Color primaryColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kategori Pelanggan',
          style: TextStyle(
            color: textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: fieldFill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: modalBorder, width: 1.1),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _kategori.toLowerCase().contains('umkm') ||
                      _kategori.toLowerCase().contains('usaha')
                  ? 'UMKM'
                  : 'Rumah Tangga',
              isExpanded: true,
              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              icon: Icon(Icons.keyboard_arrow_down, color: textSecondary),
              style: TextStyle(
                color: textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              items: [
                DropdownMenuItem(
                  value: 'Rumah Tangga',
                  child: Row(
                    children: [
                      const Icon(Icons.home, size: 18, color: Color(0xFF00AA5B)),
                      const SizedBox(width: 10),
                      Text('Rumah Tangga', style: TextStyle(color: textPrimary)),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'UMKM',
                  child: Row(
                    children: [
                      const Icon(Icons.storefront, size: 18, color: Color(0xFF7C3AED)),
                      const SizedBox(width: 10),
                      Text('Usaha Mikro / UMKM', style: TextStyle(color: textPrimary)),
                    ],
                  ),
                ),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _kategori = val);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate(
    bool isDark,
    Color surfaceColor,
    Color textPrimary,
    Color primaryColor,
  ) async {
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
        data: (isDark ? ThemeData.dark() : ThemeData.light()).copyWith(
          colorScheme: ColorScheme(
            brightness: isDark ? Brightness.dark : Brightness.light,
            primary: primaryColor,
            onPrimary: Colors.white,
            surface: surfaceColor,
            onSurface: textPrimary,
            secondary: primaryColor,
            onSecondary: Colors.white,
            error: Colors.red,
            onError: Colors.white,
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
    required Color textPrimary,
    required Color textSecondary,
    required Color fieldFill,
    required Color primaryColor,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      keyboardType: keyboard,
      inputFormatters: formatters,
      validator: validator,
      maxLines: maxLines,
      style: TextStyle(
        color: textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
          color: textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: TextStyle(
          color: textSecondary.withValues(alpha: 0.6),
          fontSize: 13,
        ),
        prefixIcon: Icon(icon, color: textSecondary, size: 20),
        filled: true,
        fillColor: fieldFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: textSecondary.withValues(alpha: 0.2),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: textSecondary.withValues(alpha: 0.25),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
    );
  }
}
