import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide Column;
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

  Future<void> _deleteAbone(AbonelerData? abone) async {
    if (abone == null) return;

    final db = ref.read(dbProvider);

    // Check debt
    final borcBilgi = await db.getAboneBorcBilgileri(abone.id);
    final kalan = borcBilgi['kalan'] ?? 0.0;

    if (kalan > 0) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Silinemez', style: TextStyle(color: Colors.red)),
          content: Text(
            'Bu abonenin ${kalan.toStringAsFixed(2)} ₺ borcu bulunmaktadır.\n\nBorcu olan aboneler silinemez!',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Tamam'),
            ),
          ],
        ),
      );
      return;
    }

    // Get deletion info
    final info = await db.getAboneDeletionInfo(abone.id);
    final tahakkukCount = info['tahakkuk_count'] ?? 0;
    final tahsilatCount = info['tahsilat_count'] ?? 0;

    if (!mounted) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Abone Silme Onayı'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${abone.ad} ${abone.soyad ?? ''} adlı aboneyi silmek istediğinize emin misiniz?',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Silinecek Kayıtlar:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('• $tahakkukCount adet tahakkuk kaydı'),
            Text('• $tahsilatCount adet tahsilat kaydı'),
            const Text('• Tüm endeks kayıtları'),
            const Text('• Tüm sayaç kayıtları'),
            const SizedBox(height: 16),
            const Text(
              'Bu işlem geri alınamaz!',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await db.deleteAbone(abone.id);

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Abone başarıyla silindi'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Hata'),
          content: Text('Abone silinemedi: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Tamam'),
            ),
          ],
        ),
      );
    }
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
          // Sil butonu
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _deleteAbone(aboneAsync.value),
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
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(12, 2, 12, 2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceEvenly,
                    spacing: 8,
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

      // Print makbuz (receipt) - her durumda makbuz yazdır
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

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            TahsilatFormScreen(abone: abone, tahakkuklar: unpaidTahakkuklar),
        fullscreenDialog: true,
      ),
    );

    // Eğer tahsilat başarıyla kaydedildiyse, listeyi yenile
    if (result == true && mounted) {
      // Tahakkuk listesini yenile
      ref.invalidate(aboneTahakkuklarProvider(abone.id));
      setState(() {});
    }
  }

  Widget _buildAboneInfoCard(AbonelerData abone, AppDatabase db) {
    return FutureBuilder<List>(
      future: Future.wait([
        db.getAboneBorcBilgileri(abone.id),
        db.getTahakkukByAbone(abone.id),
        db.getLastEndeks(abone.id),
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
        final lastEndeks = snapshot.data?[2] as EndekslerData?;
        final donemler = snapshot.data?[3] as List<DonemlerData>? ?? [];

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
                  if (lastEndeks != null)
                    _buildCompactInfo(
                      Icons.water_drop,
                      "SE:${lastEndeks.endeks.toStringAsFixed(0)}",
                    ),
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
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactBorcBilgi(String label, double tutar) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        collapsedShape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: durumColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(durumIcon, color: durumColor, size: 16),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.print, size: 18),
              onPressed: () => _printTahakkuk(tahakkuk),
              tooltip: 'Makbuz Yazdır',
              color: const Color(0xFF0F4C81),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            Icon(Icons.expand_more, color: Colors.grey.shade400, size: 18),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                '${tahakkuk.tutar.toStringAsFixed(2)} ₺',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: durumColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                durumText,
                style: TextStyle(
                  color: durumColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              dateStr,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
            ),
            const SizedBox(height: 2),
            Text(
              'Tüketim: ${tahakkuk.tuketimM3?.toStringAsFixed(1) ?? '0'} m³ '
              '(${tahakkuk.ilkEndeks?.toStringAsFixed(0) ?? '0'} → ${tahakkuk.sonEndeks?.toStringAsFixed(0) ?? '0'})',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50.withOpacity(0.3),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tahsilatlar:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...tahsilatlar.map((t) {
                      final tTarih = DateTime.tryParse(t.tarih);
                      final tDateStr = tTarih != null
                          ? DateFormat('dd MMM yyyy').format(tTarih)
                          : t.tarih;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.arrow_forward,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              tDateStr,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 11,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${t.tutar.toStringAsFixed(2)} ₺',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E7D32),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Kalan:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '${kalan.toStringAsFixed(2)} ₺',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: kalan > 0 ? Colors.red : Colors.green,
                            fontSize: 14,
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
class TahsilatFormScreen extends ConsumerStatefulWidget {
  final AbonelerData abone;
  final List<TahakkuklarData> tahakkuklar;

  const TahsilatFormScreen({
    super.key,
    required this.abone,
    required this.tahakkuklar,
  });

  @override
  ConsumerState<TahsilatFormScreen> createState() => _TahsilatFormScreenState();
}

class _TahsilatFormScreenState extends ConsumerState<TahsilatFormScreen> {
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Tahsilat İşlemi'),
        elevation: 0,
        backgroundColor: const Color(0xFF0F4C81),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Abone bilgi kartı
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F4C81), Color(0xFF1E5A8E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F4C81).withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.abone.ad} ${widget.abone.soyad ?? ''}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Abone No: ${widget.abone.aboneNo}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Tahakkuk seçimi
            const Text(
              'Tahakkuk Seçiniz',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Color(0xFF0F4C81),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _showTahakkukDialog,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.receipt_long,
                      color: _selectedTahakkukId != null
                          ? const Color(0xFF0F4C81)
                          : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tahakkuk',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (_selectedTahakkukId != null)
                            FutureBuilder<List>(
                              future: _getSelectedTahakkukInfo(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return Text(
                                    'Yükleniyor...',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade600,
                                    ),
                                  );
                                }
                                final donem = snapshot.data![0] as String;
                                final kalan = snapshot.data![1] as double;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      donem,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black,
                                      ),
                                    ),
                                    Text(
                                      'Kalan: ${kalan.toStringAsFixed(2)} ₺',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            )
                          else
                            Text(
                              'Tahakkuk seçiniz',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Tutar girişi
            const Text(
              'Tahsilat Tutarı',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Color(0xFF0F4C81),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tutarController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autofocus: true,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF2E7D32),
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                suffixIcon: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '₺',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
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
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: const Text(
                      'İptal',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveTahsilat,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
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
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<List> _getSelectedTahakkukInfo() async {
    if (_selectedTahakkukId == null) {
      return ['-', 0.0];
    }
    final db = ref.read(dbProvider);
    final tahakkuk = widget.tahakkuklar.firstWhere(
      (t) => t.id == _selectedTahakkukId,
      orElse: () => throw Exception('Tahakkuk bulunamadı'),
    );
    final kalan = await db.getKalanBakiye(tahakkuk.id);
    final donem = await db.getDonemById(tahakkuk.donemId);
    return [donem?.ad ?? '-', kalan];
  }

  Future<void> _showTahakkukDialog() async {
    final db = ref.read(dbProvider);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tahakkuk Seçiniz'),
        titlePadding: const EdgeInsets.all(20),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 16,
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: widget.tahakkuklar.length,
            itemBuilder: (context, index) {
              final t = widget.tahakkuklar[index];
              return FutureBuilder<List>(
                future: Future.wait([
                  db.getKalanBakiye(t.id),
                  db.getDonemById(t.donemId),
                ]),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }

                  final kalan = snapshot.data![0] as double;
                  final donem = snapshot.data![1] as DonemlerData?;
                  final donemAd = donem?.ad ?? '-';
                  final isSelected = _selectedTahakkukId == t.id;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF0F4C81).withOpacity(0.1)
                          : Colors.white,
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF0F4C81)
                            : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: kalan <= 0
                              ? Colors.green.shade50
                              : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isSelected ? Icons.check_circle : Icons.receipt_long,
                          color: kalan <= 0
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                      ),
                      title: Text(
                        donemAd,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            'Tutar: ${t.tutar.toStringAsFixed(2)} ₺',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            'Kalan: ${kalan.toStringAsFixed(2)} ₺',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: kalan <= 0
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                      onTap: () {
                        setState(() {
                          _selectedTahakkukId = t.id;
                          _tutarController.text = kalan.toStringAsFixed(2);
                        });
                        Navigator.pop(context);
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
        actionsPadding: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _saveTahsilat() async {
    if (!_formKey.currentState!.validate()) return;

    // Tahakkuk seçimi kontrol et
    if (_selectedTahakkukId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen tahakkuk seçiniz'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

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
