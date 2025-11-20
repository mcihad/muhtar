import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:drift/drift.dart' hide Column;
import '../../providers.dart';
import '../../widgets/printer_status_widget.dart';
import '../../db/app_database.dart';
import '../abone/aboneler_list_screen.dart';
import '../donem/donem_list_screen.dart';
import '../settings/settings_screen.dart';
import '../tahakkuk/tahakkuk_list_screen.dart';
import '../reports/reports_screen.dart';
import '../help/help_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _scanQRCode(BuildContext context, WidgetRef ref) async {
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
        if (!context.mounted) return;
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
        if (!context.mounted) return;
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
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bu fiş zaten tahsil edilmiş'),
            backgroundColor: Colors.green,
          ),
        );
        return;
      }

      // Show payment dialog
      if (!context.mounted) return;

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
                        _buildInfoRow(
                          'Abone',
                          '${aboneInfo?.ad ?? '-'} ${aboneInfo?.soyad ?? ''}',
                        ),
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
                              color: Colors.white,
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
        if (!context.mounted) return;
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

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tahsilat başarılı: ${tutar.toStringAsFixed(2)} ₺'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  static Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Colors.black87),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(
                8.0,
              ), // Adjust radius as needed
              child: Image.asset(
                'assets/images/logo.png',
                height: 32,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.water_drop),
              ),
            ),
            const SizedBox(width: 12),
            const Text('Su Abone Takip'),
          ],
        ),
        elevation: 0,
        actions: [
          const PrinterStatusIcon(),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Çıkış',
            onPressed: () {
              showDialog(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Çıkış Yap'),
                  content: const Text(
                    'Çıkış yapmak istediğinize emin misiniz?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('İptal'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: () {
                        Navigator.pop(c);
                        ref.read(authProvider.notifier).state = false;
                      },
                      child: const Text(
                        'Çıkış Yap',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF5F7FA), Color(0xFFE8EEF2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: GridView.count(
                crossAxisCount: 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: [
                  _buildGridButton(
                    context,
                    icon: Icons.people,
                    label: 'Aboneler',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AbonelerListScreen(),
                        ),
                      );
                    },
                  ),
                  _buildGridButton(
                    context,
                    icon: Icons.calendar_today,
                    label: 'Dönemler',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DonemListScreen(),
                        ),
                      );
                    },
                  ),
                  _buildGridButton(
                    context,
                    icon: Icons.receipt_long,
                    label: 'Tahakkuklar',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TahakkukListScreen(),
                        ),
                      );
                    },
                  ),
                  _buildGridButton(
                    context,
                    icon: Icons.qr_code_scanner,
                    label: 'QR Oku',
                    onTap: () => _scanQRCode(context, ref),
                  ),
                  _buildGridButton(
                    context,
                    icon: Icons.assessment,
                    label: 'Raporlar',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ReportsScreen(),
                        ),
                      );
                    },
                  ),
                  _buildGridButton(
                    context,
                    icon: Icons.settings,
                    label: 'Ayarlar',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                  _buildGridButton(
                    context,
                    icon: Icons.help_outline,
                    label: 'Yardım',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const HelpScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
            // Footer
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Sivas Belediyesi Akıllı Şehir ve Kent Bilgi Sistemleri Müdürlüğü tarafından geliştirilmiştir',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    // Her buton için farklı renk
    final Color buttonColor;
    switch (label) {
      case 'Aboneler':
        buttonColor = const Color(0xFF2196F3);
        break;
      case 'Dönemler':
        buttonColor = const Color(0xFF9C27B0);
        break;
      case 'Tahakkuklar':
        buttonColor = const Color(0xFFE91E63);
        break;
      case 'Raporlar':
        buttonColor = const Color(0xFF4CAF50);
        break;
      case 'Ayarlar':
        buttonColor = const Color(0xFFFF9800);
        break;
      default:
        buttonColor = const Color(0xFF0F4C81);
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [buttonColor, buttonColor.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: buttonColor.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 36),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
