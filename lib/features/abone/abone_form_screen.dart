import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import '../../db/app_database.dart';
import '../../providers.dart';

class AboneFormScreen extends ConsumerStatefulWidget {
  final AbonelerData? abone;

  const AboneFormScreen({super.key, this.abone});

  @override
  ConsumerState<AboneFormScreen> createState() => _AboneFormScreenState();
}

class _AboneFormScreenState extends ConsumerState<AboneFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _adController;
  late TextEditingController _soyadController;
  late TextEditingController _telController;
  late TextEditingController _aboneNoController;
  late TextEditingController _saatNoController;
  late TextEditingController _adresController;
  late TextEditingController _aciklamaController;
  late TextEditingController _ilkEndeksController;

  String _saatDurumu = 'normal';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _adController = TextEditingController(text: widget.abone?.ad ?? '');
    _soyadController = TextEditingController(text: widget.abone?.soyad ?? '');
    _telController = TextEditingController(text: widget.abone?.tel ?? '');
    _aboneNoController = TextEditingController(
      text: widget.abone?.aboneNo ?? '',
    );
    _saatNoController = TextEditingController(text: widget.abone?.saatNo ?? '');
    _adresController = TextEditingController(text: widget.abone?.adres ?? '');
    _aciklamaController = TextEditingController(
      text: widget.abone?.aciklama ?? '',
    );
    _ilkEndeksController = TextEditingController();
    _saatDurumu = widget.abone?.saatDurumu ?? 'normal';
  }

  @override
  void dispose() {
    _adController.dispose();
    _soyadController.dispose();
    _telController.dispose();
    _aboneNoController.dispose();
    _saatNoController.dispose();
    _adresController.dispose();
    _aciklamaController.dispose();
    _ilkEndeksController.dispose();
    super.dispose();
  }

  Future<void> _generateAboneNo() async {
    setState(() => _isLoading = true);
    try {
      final db = ref.read(dbProvider);
      final maxAboneNo = await db.getMaxAboneNo();
      _aboneNoController.text = (maxAboneNo + 1).toString();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final db = ref.read(dbProvider);

      if (widget.abone == null) {
        // Yeni abone - ilk endeks zorunlu
        if (_ilkEndeksController.text.isEmpty) {
          throw Exception('İlk endeks girilmelidir');
        }

        await db.createAboneFull(
          ad: _adController.text,
          soyad: _soyadController.text.isEmpty ? null : _soyadController.text,
          tel: _telController.text.isEmpty ? null : _telController.text,
          aboneNo: _aboneNoController.text,
          saatNo: _saatNoController.text.isEmpty
              ? null
              : _saatNoController.text,
          saatDurumu: _saatDurumu,
          adres: _adresController.text.isEmpty ? null : _adresController.text,
          aciklama: _aciklamaController.text.isEmpty
              ? null
              : _aciklamaController.text,
          ilkEndeks: double.parse(_ilkEndeksController.text),
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Abone başarıyla eklendi')),
        );
      } else {
        // Güncelleme
        await db.updateAbone(
          widget.abone!.id,
          AbonelerCompanion(
            ad: Value(_adController.text),
            soyad: Value(
              _soyadController.text.isEmpty ? null : _soyadController.text,
            ),
            tel: Value(
              _telController.text.isEmpty ? null : _telController.text,
            ),
            aboneNo: Value(_aboneNoController.text),
            saatNo: Value(
              _saatNoController.text.isEmpty ? null : _saatNoController.text,
            ),
            saatDurumu: Value(_saatDurumu),
            adres: Value(
              _adresController.text.isEmpty ? null : _adresController.text,
            ),
            aciklama: Value(
              _aciklamaController.text.isEmpty
                  ? null
                  : _aciklamaController.text,
            ),
          ),
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Abone başarıyla güncellendi')),
        );
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF2196F3)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2196F3), width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.abone != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(isEdit ? 'Abone Düzenle' : 'Yeni Abone'),
        backgroundColor: const Color(0xFF2196F3),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Temel Bilgiler Kartı
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.person, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    const Text(
                      'Temel Bilgiler',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextFormField(
                    controller: _adController,
                    decoration: _buildInputDecoration(
                      'Ad *',
                      Icons.person_outline,
                    ),
                    validator: (v) => v?.isEmpty ?? true ? 'Ad gerekli' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _soyadController,
                    decoration: _buildInputDecoration(
                      'Soyad',
                      Icons.person_outline,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _telController,
                    decoration: _buildInputDecoration('Telefon', Icons.phone),
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Sayaç Bilgileri Kartı
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF388E3C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.speed, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    const Text(
                      'Sayaç Bilgileri',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _aboneNoController,
                          decoration: _buildInputDecoration(
                            'Abone No *',
                            Icons.tag,
                          ),
                          validator: (v) =>
                              v?.isEmpty ?? true ? 'Abone no gerekli' : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _generateAboneNo,
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('Otomatik'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 20,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _saatNoController,
                    decoration: _buildInputDecoration(
                      'Saat No',
                      Icons.watch_later_outlined,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonFormField<String>(
                      value: _saatDurumu,
                      decoration: InputDecoration(
                        labelText: 'Saat Durumu',
                        prefixIcon: const Icon(
                          Icons.settings,
                          color: Color(0xFF4CAF50),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'normal',
                          child: Text('Normal'),
                        ),
                        DropdownMenuItem(
                          value: 'ters',
                          child: Text('Ters Çalışıyor'),
                        ),
                        DropdownMenuItem(
                          value: 'ariza',
                          child: Text('Arızalı'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _saatDurumu = v!),
                    ),
                  ),
                  if (!isEdit) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _ilkEndeksController,
                      decoration: _buildInputDecoration(
                        'İlk Endeks *',
                        Icons.speed,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (v) =>
                          v?.isEmpty ?? true ? 'İlk endeks gerekli' : null,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Adres ve Notlar Kartı
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF9800), Color(0xFFF57C00)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Adres ve Notlar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextFormField(
                    controller: _adresController,
                    decoration: _buildInputDecoration('Adres', Icons.home),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _aciklamaController,
                    decoration: _buildInputDecoration('Açıklama', Icons.note),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    isEdit ? 'GÜNCELLE' : 'KAYDET',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
