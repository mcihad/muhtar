import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers.dart';
import '../../services/printer_service.dart';
import 'abone_form_screen.dart';
import 'abone_detail_screen.dart';

final abonelerProvider = FutureProvider.autoDispose((ref) async {
  final db = ref.read(dbProvider);
  return db.getAboneler();
});

final aboneBorcProvider = FutureProvider.autoDispose
    .family<Map<String, double>, int>((ref, aboneId) async {
      final db = ref.read(dbProvider);
      return db.getAboneBorcBilgileri(aboneId);
    });

class AbonelerListScreen extends ConsumerStatefulWidget {
  const AbonelerListScreen({super.key});

  @override
  ConsumerState<AbonelerListScreen> createState() => _AbonelerListScreenState();
}

class _AbonelerListScreenState extends ConsumerState<AbonelerListScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final abonelerAsync = ref.watch(abonelerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Aboneler'),
        elevation: 0,
        backgroundColor: const Color(0xFF0F4C81),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Arama çubuğu
          Container(
            padding: const EdgeInsets.all(16),
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
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Ad, soyad veya abone no ile ara...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF2196F3)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          // Abone listesi
          Expanded(
            child: abonelerAsync.when(
              data: (list) {
                // Arama filtresi uygula
                final filteredList = list.where((a) {
                  if (_searchQuery.isEmpty) return true;
                  final fullName = '${a.ad}${a.soyad ?? ''}'.toLowerCase();
                  final aboneNo = a.aboneNo.toLowerCase();
                  return fullName.contains(_searchQuery) ||
                      aboneNo.contains(_searchQuery);
                }).toList();

                if (filteredList.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_off,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'Henüz abone eklenmedi'
                              : 'Abone bulunamadı',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(abonelerProvider);
                    await Future.delayed(const Duration(milliseconds: 500));
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final abone = filteredList[index];
                      return _buildAboneCard(abone);
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('Hata: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AboneFormScreen()),
          );
          ref.invalidate(abonelerProvider);
        },
        icon: const Icon(Icons.add),
        label: const Text('Yeni Abone'),
        backgroundColor: const Color(0xFF2196F3),
      ),
    );
  }

  Widget _buildAboneCard(abone) {
    final borcAsync = ref.watch(aboneBorcProvider(abone.id));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AboneDetailScreen(aboneId: abone.id),
            ),
          );
          ref.invalidate(abonelerProvider);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    abone.ad[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Bilgiler
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${abone.ad}${abone.soyad != null ? ' ${abone.soyad}' : ''}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.badge,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          abone.aboneNo,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (abone.saatNo != null) ...[
                          const SizedBox(width: 12),
                          Icon(
                            Icons.speed,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            abone.saatNo!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Borç durumu
                    borcAsync.when(
                      data: (borc) {
                        final kalan = borc['kalan'] ?? 0.0;
                        return Row(
                          children: [
                            Icon(
                              kalan > 0 ? Icons.warning : Icons.check_circle,
                              size: 14,
                              color: kalan > 0 ? Colors.red : Colors.green,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              kalan > 0
                                  ? 'Borç: ${kalan.toStringAsFixed(2)} ₺'
                                  : 'Borç yok',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: kalan > 0 ? Colors.red : Colors.green,
                              ),
                            ),
                          ],
                        );
                      },
                      loading: () => const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      error: (_, __) => const SizedBox(),
                    ),
                  ],
                ),
              ),
              // Action icons: Print and Share
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Print all abone info
                  IconButton(
                    icon: const Icon(Icons.print, size: 20),
                    color: const Color(0xFF0F4C81),
                    onPressed: () => _printAboneBilgileri(abone),
                    tooltip: 'Bilgileri Yazdır',
                  ),
                  // Share all abone info
                  IconButton(
                    icon: const Icon(Icons.share, size: 20),
                    color: const Color(0xFF2196F3),
                    onPressed: () => _shareAboneBilgileri(abone),
                    tooltip: 'Bilgileri Paylaş',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _printAboneBilgileri(abone) async {
    final db = ref.read(dbProvider);
    final ayarlar = await db.getSettings();
    final borcBilgi = await db.getAboneBorcBilgileri(abone.id);
    final kalan = borcBilgi['kalan'] ?? 0.0;

    if (!mounted) return;

    try {
      final printerService = PrinterService();
      if (!printerService.isConnected()) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Yazıcı bağlı değil')));
        return;
      }

      // Create comprehensive info text
      final info = StringBuffer();
      info.writeln('=== ABONE BİLGİLERİ ===');
      info.writeln('');
      info.writeln(
        'Ad: ${abone.ad}${abone.soyad != null ? ' ${abone.soyad}' : ''}',
      );
      info.writeln('Abone No: ${abone.aboneNo}');
      if (abone.tel != null) info.writeln('Tel: ${abone.tel}');
      if (abone.saatNo != null) info.writeln('Sayaç No: ${abone.saatNo}');
      if (abone.adres != null) info.writeln('Adres: ${abone.adres}');
      info.writeln('');
      info.writeln('=== BORÇ DURUMU ===');
      info.writeln(
        'Toplam Borç: ${borcBilgi['toplam_borc']!.toStringAsFixed(2)} ₺',
      );
      info.writeln(
        'Toplam Tahsilat: ${borcBilgi['toplam_tahsilat']!.toStringAsFixed(2)} ₺',
      );
      info.writeln('Kalan: ${kalan.toStringAsFixed(2)} ₺');
      info.writeln('');
      if (ayarlar?.altBilgi != null) {
        info.writeln(ayarlar!.altBilgi);
      }

      await printerService.printText(info.toString());

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Bilgiler yazdırıldı')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  Future<void> _shareAboneBilgileri(abone) async {
    final db = ref.read(dbProvider);
    final ayarlar = await db.getSettings();
    final borcBilgi = await db.getAboneBorcBilgileri(abone.id);
    final kalan = borcBilgi['kalan'] ?? 0.0;
    final muhtarAdi = ayarlar?.muhtarAdi ?? '';
    final muhtarSoyadi = ayarlar?.muhtarSoyadi ?? '';

    final mesaj =
        '''
=== ABONE BİLGİLERİ ===

Ad: ${abone.ad}${abone.soyad != null ? ' ${abone.soyad}' : ''}
Abone No: ${abone.aboneNo}
${abone.tel != null ? 'Tel: ${abone.tel}\n' : ''}${abone.saatNo != null ? 'Sayaç No: ${abone.saatNo}\n' : ''}${abone.adres != null ? 'Adres: ${abone.adres}\n' : ''}
=== BORÇ DURUMU ===

Toplam Borç: ${borcBilgi['toplam_borc']!.toStringAsFixed(2)} TL
Toplam Tahsilat: ${borcBilgi['toplam_tahsilat']!.toStringAsFixed(2)} TL
Kalan: ${kalan.toStringAsFixed(2)} TL

Saygılarımızla,
$muhtarAdi $muhtarSoyadi
Muhtar
''';

    await Share.share(mesaj);
  }
}
