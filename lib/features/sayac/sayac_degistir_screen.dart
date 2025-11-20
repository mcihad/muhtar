import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import '../../db/app_database.dart';
import '../../providers.dart';

class SayacDegistirScreen extends ConsumerStatefulWidget {
  final AbonelerData abone;

  const SayacDegistirScreen({super.key, required this.abone});

  @override
  ConsumerState<SayacDegistirScreen> createState() =>
      _SayacDegistirScreenState();
}

class _SayacDegistirScreenState extends ConsumerState<SayacDegistirScreen> {
  final _formKey = GlobalKey<FormState>();
  final _eskiSonEndeksController = TextEditingController();
  final _yeniSaatNoController = TextEditingController();
  final _yeniEndeksController = TextEditingController();
  bool _isLoading = false;
  EndekslerData? _lastEndeks;

  @override
  void initState() {
    super.initState();
    _loadLastEndeks();
  }

  Future<void> _loadLastEndeks() async {
    final db = ref.read(dbProvider);
    final lastEndeks = await db.getLastEndeks(widget.abone.id);
    setState(() {
      _lastEndeks = lastEndeks;
    });
  }

  @override
  void dispose() {
    _eskiSonEndeksController.dispose();
    _yeniSaatNoController.dispose();
    _yeniEndeksController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final db = ref.read(dbProvider);

      final eskiSonEndeks = double.parse(_eskiSonEndeksController.text);
      final yeniSaatNo = _yeniSaatNoController.text;
      final yeniEndeks = double.parse(_yeniEndeksController.text);
      final tarih = DateTime.now().toIso8601String();

      // Tüm işlemleri tek bir transaction içinde yap
      await db.transaction(() async {
        // Eski sayaç bilgilerini sayaclar tablosuna arşivle
        if (widget.abone.saatNo != null && widget.abone.saatNo!.isNotEmpty) {
          await db
              .into(db.sayaclar)
              .insert(
                SayaclarCompanion.insert(
                  aboneId: widget.abone.id,
                  saatNo: widget.abone.saatNo!,
                  baslangicEndeks: 0.0,
                  baslangicTarihi: tarih,
                  bitisEndeks: Value(eskiSonEndeks),
                  bitisTarihi: Value(tarih),
                  aktif: const Value(0),
                  aciklama: const Value('Sayaç değişimi nedeniyle arşivlendi'),
                ),
              );
        }

        // Önceki endeks değerini al (tahakkuk hesabı için)
        final oncekiEndeks = await db.getLastEndeks(widget.abone.id);
        final ilkEndeks = oncekiEndeks?.endeks ?? 0.0;

        // Eski sayacın son endeksini kaydet
        await db
            .into(db.endeksler)
            .insert(
              EndekslerCompanion.insert(
                aboneId: widget.abone.id,
                tarih: tarih,
                endeks: eskiSonEndeks,
                okuyanKisi: const Value('Sistem'),
                aciklama: const Value(
                  'Sayaç değişimi - Eski sayaç son endeksi (tahmini)',
                ),
              ),
            );

        // Tüketim hesapla: sayaç durumuna göre
        double tuketim;
        final saatDurumu = widget.abone.saatDurumu;
        if (saatDurumu == 'ters') {
          tuketim = ilkEndeks - eskiSonEndeks;
        } else {
          tuketim = eskiSonEndeks - ilkEndeks;
        }

        // Negatif tüketimi önle
        if (tuketim < 0) tuketim = 0;

        // Aktif dönemi al
        final ayarlar = await db.getSettings();
        final donemler = await db.getDonemler();

        if (donemler.isNotEmpty && ayarlar != null) {
          // İlk dönemi veya varsayılan dönemi kullan
          final aktifDonem = ayarlar.varsayilanDonemId != null
              ? donemler.firstWhere(
                  (d) => d.id == ayarlar.varsayilanDonemId,
                  orElse: () => donemler.first,
                )
              : donemler.first;

          final birimFiyat = ayarlar.suM3Fiyat;
          final tutar = tuketim * birimFiyat;

          // Tahakkuk oluştur
          await db
              .into(db.tahakkuklar)
              .insert(
                TahakkuklarCompanion.insert(
                  aboneId: widget.abone.id,
                  donemId: aktifDonem.id,
                  ilkEndeks: Value(ilkEndeks),
                  sonEndeks: Value(eskiSonEndeks),
                  tuketimM3: Value(tuketim),
                  birimFiyat: birimFiyat,
                  tutar: tutar,
                  olusturmaTarihi: tarih,
                  durum: const Value('beklemede'),
                ),
              );
        }

        // Abone bilgilerini güncelle (yeni sayaç numarası)
        await db.updateAbone(
          widget.abone.id,
          AbonelerCompanion(saatNo: Value(yeniSaatNo)),
        );

        // Yeni sayacın ilk endeksini kaydet
        await db
            .into(db.endeksler)
            .insert(
              EndekslerCompanion.insert(
                aboneId: widget.abone.id,
                tarih: tarih,
                endeks: yeniEndeks,
                okuyanKisi: const Value('Sistem'),
                aciklama: const Value(
                  'Sayaç değişimi - Yeni sayaç ilk endeksi',
                ),
              ),
            );
      });

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sayaç değişimi başarıyla tamamlandı'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Sayaç Değiştir'),
        backgroundColor: const Color(0xFFF44336),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Abone bilgi kartı
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF44336), Color(0xFFE53935)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      child: Text(
                        widget.abone.ad[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.abone.ad}${widget.abone.soyad != null ? ' ${widget.abone.soyad}' : ''}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Abone No: ${widget.abone.aboneNo}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                          if (widget.abone.saatNo != null)
                            Text(
                              'Mevcut Sayaç: ${widget.abone.saatNo}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Eski sayaç başlığı
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6F00), Color(0xFFE65100)],
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
                      'Eski Sayaç',
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
              margin: const EdgeInsets.only(bottom: 24),
              child: TextFormField(
                controller: _eskiSonEndeksController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Son Endeks *',
                  hintText: 'Eski sayacın son endeksi',
                  prefixIcon: const Icon(
                    Icons.water_drop,
                    color: Color(0xFFFF6F00),
                  ),
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
                    borderSide: const BorderSide(
                      color: Color(0xFFFF6F00),
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Son endeks giriniz';
                  }
                  final eskiSonEndeks = double.tryParse(value);
                  if (eskiSonEndeks == null) {
                    return 'Geçerli sayı giriniz';
                  }

                  // Önceki endeks kontrolü
                  if (_lastEndeks != null) {
                    final saatDurumu = widget.abone.saatDurumu;

                    if (saatDurumu == 'ters') {
                      // Ters sayaçta: eski sayacın son endeksi önceki endeksten küçük olmalı
                      if (eskiSonEndeks >= _lastEndeks!.endeks) {
                        return 'Ters sayaçta son endeks önceki endeksten (${_lastEndeks!.endeks.toStringAsFixed(0)}) küçük olmalı';
                      }
                    } else {
                      // Normal ve arızalı sayaçta: eski sayacın son endeksi önceki endeksten büyük olmalı
                      if (eskiSonEndeks < _lastEndeks!.endeks) {
                        return 'Son endeks önceki endeksten (${_lastEndeks!.endeks.toStringAsFixed(0)}) küçük olamaz';
                      }
                    }

                    // Sayacın içi aynı olamaz
                    if (eskiSonEndeks == _lastEndeks!.endeks) {
                      return 'Sayacın içi aynı olamaz (${_lastEndeks!.endeks.toStringAsFixed(0)})';
                    }
                  }

                  return null;
                },
              ),
            ),

            // Yeni sayaç başlığı
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
                    const Icon(Icons.fiber_new, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    const Text(
                      'Yeni Sayaç',
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
                    controller: _yeniSaatNoController,
                    decoration: InputDecoration(
                      labelText: 'Yeni Sayaç Numarası *',
                      hintText: 'Yeni sayaç numarası',
                      prefixIcon: const Icon(
                        Icons.numbers,
                        color: Color(0xFF4CAF50),
                      ),
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
                        borderSide: const BorderSide(
                          color: Color(0xFF4CAF50),
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Sayaç numarası giriniz';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _yeniEndeksController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Yeni Sayaç İlk Endeks *',
                      hintText: 'Yeni sayacın ilk endeksi',
                      prefixIcon: const Icon(
                        Icons.water_drop,
                        color: Color(0xFF4CAF50),
                      ),
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
                        borderSide: const BorderSide(
                          color: Color(0xFF4CAF50),
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'İlk endeks giriniz';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Geçerli sayı giriniz';
                      }
                      return null;
                    },
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
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: const Color(0xFFF44336),
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
                : const Text(
                    'DEĞİŞTİR',
                    style: TextStyle(
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
