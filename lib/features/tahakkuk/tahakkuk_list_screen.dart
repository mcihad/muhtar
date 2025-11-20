import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../db/app_database.dart';
import '../../providers.dart';
import '../../services/printer_service.dart';
import 'package:intl/intl.dart';

class TahakkukListScreen extends ConsumerStatefulWidget {
  const TahakkukListScreen({super.key});
  @override
  ConsumerState<TahakkukListScreen> createState() => _TahakkukListScreenState();
}

class _TahakkukListScreenState extends ConsumerState<TahakkukListScreen> {
  List<TahakkuklarData> _allTahakkuklar = [];
  List<TahakkuklarData> _filteredTahakkuklar = [];
  Map<int, AbonelerData> _aboneler = {};
  Map<int, DonemlerData> _donemler = {};
  bool _loading = true;
  String _searchQuery = '';
  int? _selectedYear;
  int? _selectedDonemId;
  List<DonemlerData> _allDonemler = [];
  Set<int> _availableYears = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = ref.read(dbProvider);
    final tahakkuklar = await db.getAllTahakkuklar();
    final aboneler = await db.getAboneler();
    final donemler = await db.getDonemler();

    // Extract years from donemler
    final years = <int>{};
    for (var d in donemler) {
      try {
        final date = DateTime.parse(d.baslangicTarihi);
        years.add(date.year);
      } catch (e) {
        debugPrint('Error parsing date: $e');
      }
    }

    if (mounted) {
      setState(() {
        _allTahakkuklar = tahakkuklar;
        _aboneler = {for (var a in aboneler) a.id: a};
        _donemler = {for (var d in donemler) d.id: d};
        _allDonemler = donemler;
        _availableYears = years;

        // Default: show current year
        if (_availableYears.isNotEmpty) {
          _selectedYear = DateTime.now().year;
          if (_availableYears.contains(_selectedYear)) {
            // Filter donemler by year
            _filterByYearAndDonem();
          }
        }

        _loading = false;
      });
    }
  }

  void _filterByYearAndDonem() {
    var filtered = _allTahakkuklar;

    // Filter by year
    if (_selectedYear != null) {
      filtered = filtered.where((t) {
        final donem = _donemler[t.donemId];
        if (donem == null) return false;
        try {
          final date = DateTime.parse(donem.baslangicTarihi);
          return date.year == _selectedYear;
        } catch (e) {
          return false;
        }
      }).toList();
    }

    // Filter by donem
    if (_selectedDonemId != null) {
      filtered = filtered.where((t) => t.donemId == _selectedDonemId).toList();
    }

    // Filter by search
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((t) {
        final abone = _aboneler[t.aboneId];
        if (abone == null) return false;
        final fullName = '${abone.ad} ${abone.soyad ?? ''}'.toLowerCase();
        final aboneNo = abone.aboneNo.toLowerCase();
        return fullName.contains(_searchQuery.toLowerCase()) ||
            aboneNo.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    setState(() {
      _filteredTahakkuklar = filtered;
    });
  }

  Future<void> _printMakbuz(TahakkuklarData tahakkuk) async {
    final db = ref.read(dbProvider);
    final settings = await db.getSettings();
    final abone = _aboneler[tahakkuk.aboneId];
    final donem = _donemler[tahakkuk.donemId];

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    if (settings == null || abone == null || donem == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Veri eksik')));
      return;
    }

    final kalan = await db.getKalanBakiye(tahakkuk.id);
    final odenen = tahakkuk.tutar - kalan;

    try {
      final printerService = PrinterService();
      if (!printerService.isConnected()) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Yazıcı bağlı değil')),
        );
        return;
      }

      // Print makbuz (receipt) - her durumda makbuz yazdır
      await printerService.printMakbuz(
        antetBaslik: settings.antetBaslik ?? 'MUHTAR',
        antetAdres: settings.antetAdres ?? '',
        altBilgi: settings.altBilgi ?? 'Teşekkür ederiz',
        aboneAd: '${abone.ad} ${abone.soyad ?? ''}',
        aboneNo: abone.aboneNo,
        donem: donem.ad,
        ilkEndeks: tahakkuk.ilkEndeks ?? 0.0,
        sonEndeks: tahakkuk.sonEndeks ?? 0.0,
        tuketim: tahakkuk.tuketimM3 ?? 0.0,
        birimFiyat: tahakkuk.birimFiyat,
        tutar: tahakkuk.tutar,
        odenen: odenen,
        kalan: kalan,
        tarih: DateFormat('dd.MM.yyyy').format(DateTime.now()),
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            kalan > 0
                ? 'Fiş yazdırıldı (Kalan: ${kalan.toStringAsFixed(2)} ₺)'
                : 'Fiş yazdırıldı',
          ),
          backgroundColor: kalan > 0 ? Colors.orange : Colors.green,
        ),
      );
    } catch (e) {
      debugPrintStack(label: 'Yazdırma hatası: $e');
      messenger.showSnackBar(SnackBar(content: Text('Yazıcı hatası: $e')));
    }
  }

  Future<void> _shareBorcMesaji(
    TahakkuklarData tahakkuk,
    AbonelerData? abone,
    double kalan,
  ) async {
    if (abone == null) return;

    final db = ref.read(dbProvider);
    final ayarlar = await db.getSettings();
    final muhtarAdi = ayarlar?.muhtarAdi ?? '';
    final muhtarSoyadi = ayarlar?.muhtarSoyadi ?? '';
    final donem = _donemler[tahakkuk.donemId];

    final mesaj =
        '''
Sayın ${abone.ad}${abone.soyad != null ? ' ${abone.soyad}' : ''},

${donem?.ad ?? 'Mevcut dönem'} için köy muhtarlığımıza ${kalan.toStringAsFixed(2)} ₺ borcunuz bulunmaktadır.

Borcunuzun en kısa sürede ödenmesini rica ederiz.

Saygılarımızla,
$muhtarAdi $muhtarSoyadi
Muhtar
''';

    await Share.share(mesaj);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tahakkuklar'), elevation: 0),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Arama ve Filtreler
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
                  child: Column(
                    children: [
                      // Arama çubuğu
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Ad, soyad veya abone no ara...',
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Color(0xFF0F4C81),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF0F4C81),
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                          _filterByYearAndDonem();
                        },
                      ),
                      const SizedBox(height: 12),
                      // Yıl ve Dönem Filtreleri
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              decoration: InputDecoration(
                                labelText: 'Yıl',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                              ),
                              value: _selectedYear,
                              items: [null, ..._availableYears.toList()].map((
                                year,
                              ) {
                                return DropdownMenuItem(
                                  value: year,
                                  child: Text(
                                    year == null ? 'Tüm Yıllar' : '$year',
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedYear = value;
                                  _selectedDonemId = null;
                                });
                                _filterByYearAndDonem();
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              decoration: InputDecoration(
                                labelText: 'Dönem',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                              ),
                              value: _selectedDonemId,
                              items: [null, ..._getFilteredDonemler()].map((
                                donem,
                              ) {
                                return DropdownMenuItem(
                                  value: donem?.id,
                                  child: Text(
                                    donem == null ? 'Tüm Dönemler' : donem.ad,
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedDonemId = value;
                                });
                                _filterByYearAndDonem();
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Tahakkuk Listesi
                Expanded(
                  child: _filteredTahakkuklar.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 80,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Tahakkuk bulunamadı',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredTahakkuklar.length,
                          itemBuilder: (c, i) {
                            final t = _filteredTahakkuklar[i];
                            final abone = _aboneler[t.aboneId];
                            final donem = _donemler[t.donemId];
                            return _buildTahakkukCard(t, abone, donem);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  List<DonemlerData> _getFilteredDonemler() {
    if (_selectedYear == null) {
      return _allDonemler;
    }
    return _allDonemler.where((d) {
      try {
        final date = DateTime.parse(d.baslangicTarihi);
        return date.year == _selectedYear;
      } catch (e) {
        return false;
      }
    }).toList();
  }

  Widget _buildTahakkukCard(
    TahakkuklarData tahakkuk,
    AbonelerData? abone,
    DonemlerData? donem,
  ) {
    final db = ref.read(dbProvider);

    // Durum rengi ve ikonu
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
        durumText = 'Kısmi';
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: durumColor.withOpacity(0.3), width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Detay görüntüleme eklenebilir
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Üst kısım: Abone adı ve durum badge
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF0F4C81),
                    child: Text(
                      abone?.ad[0].toUpperCase() ?? 'A',
                      style: const TextStyle(
                        color: Colors.white,
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
                          abone != null
                              ? '${abone.ad}${abone.soyad != null ? ' ${abone.soyad}' : ''}'
                              : 'Abone #${tahakkuk.aboneId}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Abone No: ${abone?.aboneNo ?? '-'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: durumColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: durumColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(durumIcon, size: 14, color: durumColor),
                        const SizedBox(width: 4),
                        Text(
                          durumText,
                          style: TextStyle(
                            color: durumColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              // Orta kısım: Dönem ve tüketim bilgileri
              Row(
                children: [
                  Expanded(
                    child: _buildInfoColumn(
                      Icons.calendar_month,
                      'Dönem',
                      donem?.ad ?? 'Bilinmeyen',
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInfoColumn(
                      Icons.water_drop,
                      'Tüketim',
                      '${tahakkuk.tuketimM3?.toStringAsFixed(1) ?? '0'}',
                      Colors.teal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Alt kısım: Tutar bilgileri ve aksiyonlar
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Toplam Tutar',
                          style: TextStyle(fontSize: 14, color: Colors.black54),
                        ),
                        Text(
                          '${tahakkuk.tutar.toStringAsFixed(2)} ₺',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<double>(
                      future: db.getKalanBakiye(tahakkuk.id),
                      builder: (context, snapshot) {
                        final kalan = snapshot.data ?? 0;
                        final odenen = tahakkuk.tutar - kalan;

                        return Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Ödenen',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                                Text(
                                  '${odenen.toStringAsFixed(2)} ₺',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.green,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Kalan',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                                Text(
                                  '${kalan.toStringAsFixed(2)} ₺',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: kalan > 0
                                        ? Colors.red
                                        : Colors.green,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Aksiyon butonları
              FutureBuilder<double>(
                future: db.getKalanBakiye(tahakkuk.id),
                builder: (context, snapshot) {
                  final kalan = snapshot.data ?? 0;

                  return Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _printMakbuz(tahakkuk),
                          icon: const Icon(Icons.print, size: 16),
                          label: const Text(
                            'Yazdır',
                            style: TextStyle(fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F4C81),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      if (kalan > 0) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                _shareBorcMesaji(tahakkuk, abone, kalan),
                            icon: const Icon(Icons.share, size: 16),
                            label: const Text(
                              'Paylaş',
                              style: TextStyle(fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE91E63),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoColumn(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: color.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
