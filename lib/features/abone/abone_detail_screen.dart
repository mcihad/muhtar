import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import '../../db/app_database.dart';
import '../../providers.dart';
import '../../services/printer_service.dart';
import 'abone_form_screen.dart';
import '../endeks/endeks_form_screen.dart';
import '../sayac/sayac_degistir_screen.dart';

// Provider'lar
final aboneDetailProvider = FutureProvider.family<AbonelerData?, int>((
  ref,
  id,
) async {
  final db = ref.read(dbProvider);
  return db.getAboneById(id);
});

final aboneEndekslerProvider = FutureProvider.family<List<EndekslerData>, int>((
  ref,
  id,
) async {
  final db = ref.read(dbProvider);
  return db.getEndeksByAbone(id);
});

final aboneTahakkuklarProvider =
    FutureProvider.family<List<TahakkuklarData>, int>((ref, id) async {
      final db = ref.read(dbProvider);
      return db.getTahakkukByAbone(id);
    });

class AboneDetailScreen extends ConsumerStatefulWidget {
  final int aboneId;

  const AboneDetailScreen({super.key, required this.aboneId});

  @override
  ConsumerState<AboneDetailScreen> createState() => _AboneDetailScreenState();
}

class _AboneDetailScreenState extends ConsumerState<AboneDetailScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aboneAsync = ref.watch(aboneDetailProvider(widget.aboneId));
    final db = ref.read(dbProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Abone Detayı'),
        actions: [
          // Düzenle butonu
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final abone = aboneAsync.value;
              if (abone != null) {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AboneFormScreen(abone: abone),
                  ),
                );
                if (result == true) {
                  ref.invalidate(aboneDetailProvider(widget.aboneId));
                }
              }
            },
          ),
        ],
      ),
      body: aboneAsync.when(
        data: (abone) {
          if (abone == null) {
            return const Center(child: Text('Abone bulunamadı'));
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(aboneDetailProvider(widget.aboneId));
              ref.invalidate(aboneTahakkuklarProvider(widget.aboneId));
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: Column(
              children: [
                // Abone bilgi kartı
                _buildAboneInfoCard(abone, db),

                // Action butonları
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceEvenly,
                    spacing: 2,
                    runSpacing: 8,
                    children: [
                      _buildActionButton(
                        icon: Icons.speed,
                        label: 'Sayaç Oku',
                        color: const Color(0xFF0F4C81),
                        onTap: () => _showEndeksDialog(abone),
                      ),
                      _buildActionButton(
                        icon: Icons.payments,
                        label: 'Tahsilat',
                        color: const Color(0xFF2E7D32),
                        onTap: () => _showTahsilatDialog(abone),
                      ),
                      _buildActionButton(
                        icon: Icons.qr_code_scanner,
                        label: 'QR Oku',
                        color: Colors.purple.shade700,
                        onTap: () => _scanQRCode(abone),
                      ),
                      _buildActionButton(
                        icon: Icons.swap_horiz,
                        label: 'Sayaç Değiştir',
                        color: Colors.brown.shade700,
                        onTap: () => _changeMeter(abone),
                      ),
                    ],
                  ),
                ),

                // Tahakkuk ve Tahsilat Listesi
                Expanded(child: _buildTahakkukTahsilatList()),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Hata: $e', style: const TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
              fontSize: isHighlight ? 16 : 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isHighlight ? 16 : 14,
              color: isHighlight ? const Color(0xFF2E7D32) : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEndeksDialog(AbonelerData abone) async {
    // Navigate to full-page endeks entry
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EndeksFormScreen(abone: abone)),
    );

    if (result == true && mounted) {
      // Refresh data
      ref.invalidate(aboneDetailProvider(widget.aboneId));
      ref.invalidate(aboneTahakkuklarProvider(widget.aboneId));
    }
  }

  Future<void> _changeMeter(AbonelerData abone) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SayacDegistirScreen(abone: abone),
      ),
    );

    // Refresh after meter change
    if (result == true && mounted) {
      ref.invalidate(aboneDetailProvider(widget.aboneId));
      ref.invalidate(aboneTahakkuklarProvider(widget.aboneId));
    }
  }

  Future<void> _printTahakkuk(TahakkuklarData tahakkuk) async {
    try {
      final db = ref.read(dbProvider);
      final printerService = PrinterService();

      // Check printer connection
      if (!printerService.isConnected()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Yazıcı bağlı değil. Lütfen ayarlardan yazıcıyı bağlayın.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Get abone info
      final abone = await db.getAboneById(tahakkuk.aboneId);
      if (abone == null) {
        throw Exception('Abone bulunamadı');
      }

      // Get donem
      final donem = await (db.select(
        db.donemler,
      )..where((t) => t.id.equals(tahakkuk.donemId))).getSingleOrNull();

      // Get tahsilatlar
      final tahsilatlar = await db.getTahsilatByTahakkuk(tahakkuk.id);
      final toplamOdeme = tahsilatlar.fold<double>(
        0.0,
        (sum, t) => sum + t.tutar,
      );
      final kalan = tahakkuk.tutar - toplamOdeme;

      // Get settings
      final ayarlar = await db.getSettings();

      // Print
      await printerService.printMakbuz(
        antetBaslik: ayarlar?.antetBaslik ?? 'SU TAKIP SISTEMI',
        antetAdres: ayarlar?.antetAdres ?? '',
        altBilgi: ayarlar?.altBilgi ?? 'Teşekkür ederiz',
        aboneAd: '${abone.ad}${abone.soyad != null ? ' ${abone.soyad}' : ''}',
        aboneNo: abone.aboneNo,
        donem: donem?.ad ?? '-',
        ilkEndeks: tahakkuk.ilkEndeks ?? 0,
        sonEndeks: tahakkuk.sonEndeks ?? 0,
        tuketim: tahakkuk.tuketimM3 ?? 0,
        birimFiyat: tahakkuk.birimFiyat,
        tutar: tahakkuk.tutar,
        odenen: toplamOdeme,
        kalan: kalan,
        tarih: DateFormat('dd/MM/yyyy').format(DateTime.now()),
        tahakkukUuid: tahakkuk.uuid,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Makbuz yazdırıldı'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Yazdırma hatası: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Yazdırma hatası: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _scanQRCode(AbonelerData abone) async {
    try {
      // Import image picker for camera
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (image == null) return;

      // Scan barcode with ML Kit
      final InputImage inputImage = InputImage.fromFilePath(image.path);
      final BarcodeScanner barcodeScanner = BarcodeScanner();
      final List<Barcode> barcodes = await barcodeScanner.processImage(
        inputImage,
      );
      await barcodeScanner.close();

      if (barcodes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('QR kod bulunamadı'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final uuid = barcodes.first.displayValue;
      if (uuid == null || uuid.isEmpty) return;

      final db = ref.read(dbProvider);
      final tahakkuk = await db.getTahakkukByUuid(uuid);

      if (tahakkuk == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tahakkuk bulunamadı'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Check if already paid
      final kalan = await db.getKalanBakiye(tahakkuk.id);

      if (kalan <= 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bu tahakkuk zaten ödenmiş'),
            backgroundColor: Colors.green,
          ),
        );
        return;
      }

      // Show payment dialog
      if (!mounted) return;

      // Get donem and abone info
      final donem = await db.getDonemById(tahakkuk.donemId);
      final aboneInfo = await db.getAboneById(tahakkuk.aboneId);

      final tutarController = TextEditingController(
        text: kalan.toStringAsFixed(2),
      );

      final tutar = await showModalBottomSheet<double>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Title
                  const Text(
                    'Tahsilat',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  // Info cards
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow('Abone', aboneInfo?.ad ?? '-'),
                        const Divider(height: 16),
                        _buildInfoRow('Dönem', donem?.ad ?? '-'),
                        const Divider(height: 16),
                        _buildInfoRow(
                          'Toplam Tutar',
                          '${tahakkuk.tutar.toStringAsFixed(2)} ₺',
                        ),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Kalan Borç',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '${kalan.toStringAsFixed(2)} ₺',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Color(0xFFE91E63),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Input field
                  TextField(
                    controller: tutarController,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Tahsil Edilecek Tutar',
                      suffixText: '₺',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF2E7D32),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: Colors.grey),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('İptal'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            final t = double.tryParse(tutarController.text);
                            Navigator.pop(context, t);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Tahsil Et',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      );

      if (tutar == null || tutar <= 0) return;

      // Validate payment amount
      if (tutar > kalan) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Tahsilat tutarı kalan borçtan (${kalan.toStringAsFixed(2)} ₺) büyük olamaz',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Process payment
      await db.createTahsilat(
        tahakkukId: tahakkuk.id,
        tarih: DateTime.now().toIso8601String(),
        tutar: tutar,
        odemeTipi: 'Nakit',
        aciklama: 'QR kod ile tahsilat',
      );

      // Update tahakkuk status
      final yeniKalan = kalan - tutar;
      final durum = yeniKalan <= 0 ? 'tamamlandi' : 'kismen_odendi';
      await db.updateTahakkuk(
        tahakkuk.id,
        TahakkuklarCompanion(durum: Value(durum)),
      );

      if (mounted) {
        ref.invalidate(aboneTahakkuklarProvider(widget.aboneId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tahsilat başarılı: ${tutar.toStringAsFixed(2)} ₺'),
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
    }
  }

  Future<void> _showTahsilatDialog(AbonelerData abone) async {
    final db = ref.read(dbProvider);

    // Tüm ödenmemiş tahakkukları getir
    final tahakkuklar = await db.getTahakkukByAbone(abone.id);
    final unpaidTahakkuklar = <TahakkuklarData>[];

    for (var t in tahakkuklar) {
      final kalan = await db.getKalanBakiye(t.id);
      if (kalan > 0) {
        unpaidTahakkuklar.add(t);
      }
    }

    if (unpaidTahakkuklar.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ödenecek tahakkuk bulunamadı'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!mounted) return;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _TahsilatBottomSheet(abone: abone, tahakkuklar: unpaidTahakkuklar),
    );

    // Eğer tahsilat başarıyla kaydedildiyse, listeyi yenile
    if (result == true && mounted) {
      setState(() {});
    }
  }

  Widget _buildAboneInfoCard(AbonelerData abone, AppDatabase db) {
    return FutureBuilder<List>(
      future: Future.wait([
        db.getAboneBorcBilgileri(abone.id),
        db.getTahakkukByAbone(abone.id),
        db.getDonemler(),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F4C81), Color(0xFF1E5A8E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final borcBilgi = snapshot.data?[0] as Map<String, double>? ?? {};
        final tahakkuklar = snapshot.data?[1] as List<TahakkuklarData>? ?? [];
        final donemler = snapshot.data?[2] as List<DonemlerData>? ?? [];

        final toplamBorc = borcBilgi['toplam_borc'] ?? 0.0;
        final toplamTahsilat = borcBilgi['toplam_tahsilat'] ?? 0.0;
        final kalan = borcBilgi['kalan'] ?? 0.0;

        // Check if any payment is overdue
        bool isOverdue = false;
        if (kalan > 0 && tahakkuklar.isNotEmpty) {
          final now = DateTime.now();
          for (var tahakkuk in tahakkuklar) {
            final donem = donemler.cast<DonemlerData?>().firstWhere(
              (d) => d?.id == tahakkuk.donemId,
              orElse: () => null,
            );
            if (donem != null && donem.sonOdemeTarihi != null) {
              try {
                final sonOdemeDate = DateTime.parse(donem.sonOdemeTarihi!);
                if (now.isAfter(sonOdemeDate)) {
                  isOverdue = true;
                  break;
                }
              } catch (e) {
                debugPrint('Error parsing date: $e');
              }
            }
          }
        }

        // Determine color based on debt status
        Color gradientStart;
        Color gradientEnd;
        Color shadowColor;
        String statusLabel = '';

        if (kalan <= 0) {
          // Ödenmiş - yeşil
          gradientStart = const Color(0xFF2E7D32);
          gradientEnd = const Color(0xFF388E3C);
          shadowColor = const Color(0xFF2E7D32);
          statusLabel = '✓ Ödeme Yapılmış';
        } else if (isOverdue) {
          // Son ödeme tarihi geçmiş - kırmızı
          gradientStart = const Color(0xFFD32F2F);
          gradientEnd = const Color(0xFFF44336);
          shadowColor = const Color(0xFFD32F2F);
          statusLabel = '⛔ Son Ödeme Geçmiş';
        } else if (kalan > 0) {
          // Kısmı ödenmemiş - sarı
          gradientStart = const Color(0xFFF57F17);
          gradientEnd = const Color(0xFFFBC02D);
          shadowColor = const Color(0xFFF57F17);
          statusLabel = '⚠ Ödenmemiş';
        } else {
          // Varsayılan durum - mavi
          gradientStart = const Color(0xFF0F4C81);
          gradientEnd = const Color(0xFF1E5A8E);
          shadowColor = const Color(0xFF0F4C81);
          statusLabel = 'Bilgiler';
        }

        return Container(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [gradientStart, gradientEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: shadowColor.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Avatar ve ad - Kompakt
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white,
                    child: Text(
                      abone.ad[0].toUpperCase(),
                      style: TextStyle(
                        color: gradientStart,
                        fontSize: 20,
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
                          '${abone.ad}${abone.soyad != null ? ' ${abone.soyad}' : ''}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Abone No: ${abone.aboneNo}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      statusLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const Divider(color: Colors.white30, height: 20),

              // Bilgiler - Kompakt tek satır
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (abone.tel != null && abone.tel!.isNotEmpty)
                    _buildCompactInfo(Icons.phone, abone.tel!),
                  if (abone.saatNo != null && abone.saatNo!.isNotEmpty)
                    _buildCompactInfo(Icons.speed, abone.saatNo!),
                ],
              ),

              const Divider(color: Colors.white30, height: 20),

              // Borç bilgileri - Kompakt
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildCompactBorcBilgi('Borç', toplamBorc),
                  Container(width: 1, height: 24, color: Colors.white30),
                  _buildCompactBorcBilgi('Tahsilat', toplamTahsilat),
                  Container(width: 1, height: 24, color: Colors.white30),
                  _buildCompactBorcBilgi('Kalan', kalan),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompactInfo(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white70),
        const SizedBox(width: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }

  Widget _buildCompactBorcBilgi(String label, double tutar) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          '${tutar.toStringAsFixed(2)} ₺',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTahakkukTahsilatList() {
    final tahakkuklarAsync = ref.watch(
      aboneTahakkuklarProvider(widget.aboneId),
    );

    return Column(
      children: [
        // Tahakkuk listesi
        Expanded(
          child: tahakkuklarAsync.when(
            data: (list) {
              if (list.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long,
                        size: 64,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Henüz tahakkuk kaydı yok',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Tüm tahakkukları göster
              final filteredList = list;

              if (filteredList.isEmpty) {
                return Center(
                  child: Text(
                    'Tahakkuk bulunamadı',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                );
              }

              // Tarihe göre sırala (en yeni önce)
              filteredList.sort((a, b) {
                final aDate = DateTime.tryParse(a.olusturmaTarihi);
                final bDate = DateTime.tryParse(b.olusturmaTarihi);
                if (aDate == null || bDate == null) return 0;
                return bDate.compareTo(aDate);
              });

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredList.length,
                itemBuilder: (context, index) {
                  final tahakkuk = filteredList[index];
                  return _buildTahakkukCard(tahakkuk);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Hata: $e')),
          ),
        ),
      ],
    );
  }

  Widget _buildTahakkukCard(TahakkuklarData tahakkuk) {
    final db = ref.read(dbProvider);
    final tarih = DateTime.tryParse(tahakkuk.olusturmaTarihi);
    final dateStr = tarih != null
        ? DateFormat('dd MMM yyyy').format(tarih)
        : tahakkuk.olusturmaTarihi;

    Color durumColor;
    String durumText;
    IconData durumIcon;

    switch (tahakkuk.durum) {
      case 'tamamlandi':
        durumColor = Colors.green;
        durumText = 'Ödendi';
        durumIcon = Icons.check_circle;
        break;
      case 'kismen_odendi':
        durumColor = Colors.orange;
        durumText = 'Kısmi Ödeme';
        durumIcon = Icons.timelapse;
        break;
      default:
        durumColor = Colors.red;
        durumText = 'Ödenmedi';
        durumIcon = Icons.pending;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: durumColor.withOpacity(0.1),
          child: Icon(durumIcon, color: durumColor),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.print, size: 20),
              onPressed: () => _printTahakkuk(tahakkuk),
              tooltip: 'Makbuz Yazdır',
              color: const Color(0xFF0F4C81),
            ),
            const Icon(Icons.expand_more),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                '${tahakkuk.tutar.toStringAsFixed(2)} ₺',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: durumColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                durumText,
                style: TextStyle(
                  color: durumColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(dateStr),
            const SizedBox(height: 4),
            Text(
              'Tüketim: ${tahakkuk.tuketimM3?.toStringAsFixed(1) ?? '0'} m³ '
              '(${tahakkuk.ilkEndeks?.toStringAsFixed(0) ?? '0'} → ${tahakkuk.sonEndeks?.toStringAsFixed(0) ?? '0'})',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
        children: [
          // Tahsilat listesi
          FutureBuilder<List<TahsilatlarData>>(
            future: db.getTahsilatByTahakkuk(tahakkuk.id),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Henüz tahsilat yapılmamış',
                    style: TextStyle(
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                );
              }

              final tahsilatlar = snapshot.data!;
              double toplamTahsilat = 0;
              for (var t in tahsilatlar) {
                toplamTahsilat += t.tutar;
              }
              final kalan = tahakkuk.tutar - toplamTahsilat;

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tahsilatlar:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...tahsilatlar.map((t) {
                      final tTarih = DateTime.tryParse(t.tarih);
                      final tDateStr = tTarih != null
                          ? DateFormat('dd MMM yyyy').format(tTarih)
                          : t.tarih;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.arrow_forward,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              tDateStr,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 13,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${t.tutar.toStringAsFixed(2)} ₺',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Kalan:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${kalan.toStringAsFixed(2)} ₺',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: kalan > 0 ? Colors.red : Colors.green,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// Tahsilat Dialog
class _TahsilatBottomSheet extends ConsumerStatefulWidget {
  final AbonelerData abone;
  final List<TahakkuklarData> tahakkuklar;

  const _TahsilatBottomSheet({required this.abone, required this.tahakkuklar});

  @override
  ConsumerState<_TahsilatBottomSheet> createState() =>
      _TahsilatBottomSheetState();
}

class _TahsilatBottomSheetState extends ConsumerState<_TahsilatBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _tutarController = TextEditingController();
  int? _selectedTahakkukId;
  bool _isLoading = false;

  @override
  void dispose() {
    _tutarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.read(dbProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Title
                  Row(
                    children: [
                      const Icon(
                        Icons.payments,
                        color: Color(0xFF2E7D32),
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tahsilat - ${widget.abone.ad}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Tahakkuk seç
                  const Text(
                    'Tahakkuk Seçiniz:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F4C81).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DropdownButtonFormField<int>(
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                        filled: true,
                        fillColor: Colors.transparent,
                      ),
                      hint: const Text('Tahakkuk seçiniz'),
                      value: _selectedTahakkukId,
                      items: widget.tahakkuklar.map((t) {
                        return DropdownMenuItem(
                          value: t.id,
                          child: FutureBuilder<double>(
                            future: db.getKalanBakiye(t.id),
                            builder: (context, snapshot) {
                              final kalan = snapshot.data ?? t.tutar;
                              final donem = db.getDonemById(t.donemId);
                              return FutureBuilder<DonemlerData?>(
                                future: donem,
                                builder: (context, donemSnap) {
                                  final donemAd = donemSnap.data?.ad ?? '-';
                                  return SizedBox(
                                    width:
                                        MediaQuery.of(context).size.width - 100,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '$donemAd - ${t.tutar.toStringAsFixed(2)} ₺',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'Kalan: ${kalan.toStringAsFixed(2)} ₺',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: kalan > 0
                                                ? Colors.red
                                                : Colors.green,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedTahakkukId = value;
                        });
                      },
                      validator: (value) {
                        if (value == null) return 'Tahakkuk seçiniz';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Tahsilat Tutarı:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _tutarController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    autofocus: true,
                    style: const TextStyle(fontSize: 18),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF0F4C81)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF0F4C81),
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF0F4C81).withOpacity(0.05),
                      suffixText: '₺',
                      hintText: '0.00',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Tutar giriniz';
                      }
                      final tutar = double.tryParse(value);
                      if (tutar == null || tutar <= 0) {
                        return 'Geçerli tutar giriniz';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('İptal'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _saveTahsilat,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Tahsil Et',
                                  style: TextStyle(color: Colors.white),
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

  Future<void> _saveTahsilat() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final db = ref.read(dbProvider);
      final tutar = double.parse(_tutarController.text);

      // Kalan borcu kontrol et
      final kalan = await db.getKalanBakiye(_selectedTahakkukId!);

      // Tahsilat tutarı kalan borçtan büyük olamaz
      if (tutar > kalan) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Hata'),
              content: Text(
                'Tahsilat tutarı kalan borçtan (${kalan.toStringAsFixed(2)} ₺) büyük olamaz',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Tamam'),
                ),
              ],
            ),
          );
        }
        return;
      }

      await db.createTahsilat(
        tahakkukId: _selectedTahakkukId!,
        tarih: DateTime.now().toIso8601String(),
        tutar: tutar,
        odemeTipi: 'Nakit',
      );

      // Tahakkuk durumunu güncelle
      final yeniKalan = await db.getKalanBakiye(_selectedTahakkukId!);
      final durum = yeniKalan <= 0 ? 'tamamlandi' : 'kismen_odendi';

      await db.updateTahakkuk(
        _selectedTahakkukId!,
        TahakkuklarCompanion(durum: Value(durum)),
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tahsilat başarıyla kaydedildi'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Hata'),
            content: Text('Hata: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tamam'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
