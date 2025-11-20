import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../db/app_database.dart';
import '../../providers.dart';
import '../../services/printer_service.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  int _selectedReportIndex = 0;

  final List<Map<String, dynamic>> _reportTypes = [
    {
      'title': 'Son Endeks',
      'icon': Icons.water_drop,
      'color': const Color(0xFF2196F3),
    },
    {
      'title': 'Toplam Borç',
      'icon': Icons.account_balance_wallet,
      'color': const Color(0xFFE91E63),
    },
    {
      'title': 'Tahakkuk Oranları',
      'icon': Icons.pie_chart,
      'color': const Color(0xFF9C27B0),
    },
    {
      'title': 'Gecikmiş Ödemeler',
      'icon': Icons.schedule,
      'color': const Color(0xFFFF9800),
    },
    {
      'title': 'Su Tüketim',
      'icon': Icons.show_chart,
      'color': const Color(0xFF4CAF50),
    },
  ];

  @override
  Widget build(BuildContext context) {
    final db = ref.read(dbProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Raporlar'),
        elevation: 0,
        backgroundColor: const Color(0xFF0F4C81),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Rapor türleri - yatay scroll
          Container(
            height: 90,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              itemCount: _reportTypes.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _buildReportTypeCard(index),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // Rapor içeriği
          Expanded(child: _buildReportContent(db, _selectedReportIndex)),
        ],
      ),
    );
  }

  Widget _buildReportTypeCard(int index) {
    final report = _reportTypes[index];
    final isSelected = _selectedReportIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedReportIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 110,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    report['color'] as Color,
                    (report['color'] as Color).withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? report['color'] as Color : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (report['color'] as Color).withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              report['icon'] as IconData,
              size: 20,
              color: isSelected ? Colors.white : report['color'] as Color,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                report['title'] as String,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportContent(AppDatabase db, int reportIndex) {
    switch (reportIndex) {
      case 0:
        return _buildLastIndexReport(db);
      case 1:
        return _buildDebtReport(db);
      case 2:
        return _buildBillingRatiosReport(db);
      case 3:
        return _buildOverduePaymentsReport(db);
      case 4:
        return _buildConsumptionReport(db);
      default:
        return const SizedBox();
    }
  }

  // 1. Son Endeks Raporu
  Widget _buildLastIndexReport(AppDatabase db) {
    return FutureBuilder<List<AbonelerData>>(
      future: db.getAboneler(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final aboneler = snapshot.data ?? [];
        return FutureBuilder<List<EndekslerData>>(
          future: db.getAllEndeksler(),
          builder: (context, endeksSnapshot) {
            if (!endeksSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final endeksler = endeksSnapshot.data ?? [];

            final reportData = <Map<String, dynamic>>[];
            for (var abone in aboneler) {
              final sonEndeks = endeksler
                  .where((e) => e.aboneId == abone.id)
                  .fold<double?>(null, (prev, e) => e.endeks);
              if (sonEndeks != null) {
                reportData.add({
                  'ad': '${abone.ad} ${abone.soyad ?? ''}',
                  'aboneNo': abone.aboneNo,
                  'endeks': sonEndeks,
                });
              }
            }

            return _buildReportListView(
              reportData,
              ['Ad', 'Abone No', 'Son Endeks'],
              'Son Endeks Raporu',
              _exportLastIndexReport(reportData),
              onPrint: _printLastIndexReport(reportData),
            );
          },
        );
      },
    );
  }

  // 2. Toplam Borç Raporu
  Widget _buildDebtReport(AppDatabase db) {
    return FutureBuilder<List<AbonelerData>>(
      future: db.getAboneler(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final aboneler = snapshot.data ?? [];

        return FutureBuilder<List>(
          future: Future.wait(
            aboneler.map((a) => db.getAboneBorcBilgileri(a.id)).toList(),
          ),
          builder: (context, borcSnapshot) {
            if (!borcSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final reportData = <Map<String, dynamic>>[];
            double toplamBorcAll = 0;

            for (int i = 0; i < aboneler.length; i++) {
              final borcBilgi = borcSnapshot.data?[i] as Map<String, double>?;
              final borc = borcBilgi?['kalan'] ?? 0.0;
              if (borc > 0) {
                toplamBorcAll += borc;
                reportData.add({
                  'ad': '${aboneler[i].ad} ${aboneler[i].soyad ?? ''}',
                  'aboneNo': aboneler[i].aboneNo,
                  'borc': borc,
                });
              }
            }

            reportData.sort(
              (a, b) => (b['borc'] as double).compareTo(a['borc'] as double),
            );

            return _buildReportListView(
              reportData,
              ['Ad', 'Abone No', 'Borç'],
              'Toplam Borç: ${toplamBorcAll.toStringAsFixed(2)} ₺',
              _exportDebtReport(reportData, toplamBorcAll),
            );
          },
        );
      },
    );
  }

  // 3. Tahakkuk ve Tahsilat Oranları
  Widget _buildBillingRatiosReport(AppDatabase db) {
    return FutureBuilder<List<DonemlerData>>(
      future: db.getDonemler(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final donemler = snapshot.data ?? [];

        return FutureBuilder<List<TahakkuklarData>>(
          future: db.getAllTahakkuklar(),
          builder: (context, tahakkukSnapshot) {
            if (!tahakkukSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final tahakkuklar = tahakkukSnapshot.data ?? [];

            final reportData = <Map<String, dynamic>>[];
            double toplamTahakkuk = 0;

            for (var donem in donemler) {
              final donemTahakkuk = tahakkuklar
                  .where((t) => t.donemId == donem.id)
                  .fold<double>(0, (sum, t) => sum + t.tutar);
              toplamTahakkuk += donemTahakkuk;

              reportData.add({'donem': donem.ad, 'tahakkuk': donemTahakkuk});
            }

            return _buildReportListView(
              reportData,
              ['Dönem', 'Tahakkuk'],
              'Toplam Tahakkuk: ${toplamTahakkuk.toStringAsFixed(2)} ₺',
              _exportBillingRatiosReport(reportData, toplamTahakkuk),
            );
          },
        );
      },
    );
  }

  // 4. Gecikmeli Ödeme Raporu
  Widget _buildOverduePaymentsReport(AppDatabase db) {
    return FutureBuilder<List>(
      future: Future.wait([
        db.getAboneler(),
        db.getTahakkuklarByAbone(-1).catchError((_) => <TahakkuklarData>[]),
        db.getDonemler(),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return FutureBuilder<List<TahakkuklarData>>(
          future: db.getAllTahakkuklar(),
          builder: (context, tahakkukSnapshot) {
            if (!tahakkukSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final aboneler = snapshot.data?[0] as List<AbonelerData>? ?? [];
            final donemler = snapshot.data?[2] as List<DonemlerData>? ?? [];
            final tahakkuklar = tahakkukSnapshot.data ?? [];

            final reportData = <Map<String, dynamic>>[];
            final now = DateTime.now();

            for (var tahakkuk in tahakkuklar) {
              final donem = donemler.firstWhere(
                (d) => d.id == tahakkuk.donemId,
                orElse: () => DonemlerData(
                  id: -1,
                  ad: 'Bilinmiyor',
                  baslangicTarihi: '',
                  bitisTarihi: '',
                ),
              );

              if (donem.sonOdemeTarihi != null) {
                try {
                  final sonOdemeDate = DateTime.parse(donem.sonOdemeTarihi!);
                  if (now.isAfter(sonOdemeDate)) {
                    final abone = aboneler.firstWhere(
                      (a) => a.id == tahakkuk.aboneId,
                      orElse: () => AbonelerData(
                        id: -1,
                        ad: 'Bilinmiyor',
                        aboneNo: '-',
                        aktif: 0,
                      ),
                    );
                    final kalanBorc = tahakkuk.tutar - 0; // Simplified
                    if (kalanBorc > 0) {
                      reportData.add({
                        'ad': '${abone.ad} ${abone.soyad ?? ''}',
                        'aboneNo': abone.aboneNo,
                        'donem': donem.ad,
                        'sonOdeme': donem.sonOdemeTarihi!,
                        'borc': kalanBorc,
                      });
                    }
                  }
                } catch (e) {
                  debugPrint('Error parsing date: $e');
                }
              }
            }

            return _buildReportListView(
              reportData,
              ['Ad', 'Dönem', 'Son Ödeme', 'Borç'],
              'Gecikmiş Ödemeler: ${reportData.length}',
              _exportOverdueReport(reportData),
            );
          },
        );
      },
    );
  }

  // 5. Su Tüketim Raporu
  Widget _buildConsumptionReport(AppDatabase db) {
    return FutureBuilder<List<TahakkuklarData>>(
      future: db.getAllTahakkuklar(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final tahakkuklar = snapshot.data ?? [];

        return FutureBuilder<List<AbonelerData>>(
          future: db.getAboneler(),
          builder: (context, aboneSnapshot) {
            if (!aboneSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final aboneler = aboneSnapshot.data ?? [];

            final reportData = <Map<String, dynamic>>[];
            double toplamTuketim = 0;

            for (var abone in aboneler) {
              final abonetahaakuk = tahakkuklar
                  .where((t) => t.aboneId == abone.id)
                  .fold<double>(0, (sum, t) => sum + (t.tuketimM3 ?? 0));
              toplamTuketim += abonetahaakuk;

              reportData.add({
                'ad': '${abone.ad} ${abone.soyad ?? ''}',
                'aboneNo': abone.aboneNo,
                'tuketim': abonetahaakuk,
              });
            }

            reportData.sort(
              (a, b) =>
                  (b['tuketim'] as double).compareTo(a['tuketim'] as double),
            );

            return _buildReportListView(
              reportData,
              ['Ad', 'Abone No', 'Tüketim (m³)'],
              'Toplam Tüketim: ${toplamTuketim.toStringAsFixed(2)} m³',
              _exportConsumptionReport(reportData, toplamTuketim),
            );
          },
        );
      },
    );
  }

  Widget _buildReportListView(
    List<Map<String, dynamic>> data,
    List<String> columns,
    String title,
    Function() onShare, {
    Function()? onPrint,
  }) {
    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.insert_chart_outlined,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz veri yok',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Başlık ve aksiyon butonları
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _reportTypes[_selectedReportIndex]['color'] as Color,
                (_reportTypes[_selectedReportIndex]['color'] as Color)
                    .withOpacity(0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: (_reportTypes[_selectedReportIndex]['color'] as Color)
                    .withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _reportTypes[_selectedReportIndex]['title'] as String,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        if (onPrint != null)
                          IconButton(
                            icon: const Icon(Icons.print, color: Colors.white),
                            tooltip: 'Yazdır',
                            onPressed: () => onPrint(),
                          ),
                        IconButton(
                          icon: const Icon(Icons.share, color: Colors.white),
                          tooltip: 'Paylaş',
                          onPressed: () => onShare(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.assessment,
                    size: 16,
                    color: Colors.white.withOpacity(0.8),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${data.length} kayıt',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.white.withOpacity(0.8),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('dd.MM.yyyy').format(DateTime.now()),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Liste
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: data.length,
            itemBuilder: (context, index) {
              final row = data[index];
              return _buildEnhancedReportCard(row, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedReportCard(Map<String, dynamic> row, int index) {
    final color = _reportTypes[_selectedReportIndex]['color'] as Color;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // İndeks göstergesi
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // İçerik
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row['ad'] ?? row.values.first.toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.badge, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        'Abone: ${row['aboneNo'] ?? '-'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (row.containsKey('donem')) ...[
                        const SizedBox(width: 12),
                        Icon(
                          Icons.calendar_month,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          row['donem'],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (row.containsKey('sonOdeme')) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 14,
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Son Ödeme: ${row['sonOdeme']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Değer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _formatValue(row),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatValue(Map<String, dynamic> row) {
    if (row.containsKey('borc')) {
      return '${(row['borc'] as double).toStringAsFixed(2)} ₺';
    } else if (row.containsKey('tuketim')) {
      return '${(row['tuketim'] as double).toStringAsFixed(2)} m³';
    } else if (row.containsKey('endeks')) {
      return '${(row['endeks'] as double).toStringAsFixed(2)}';
    } else if (row.containsKey('tahakkuk')) {
      return '${(row['tahakkuk'] as double).toStringAsFixed(2)} ₺';
    }
    return '-';
  }

  Function() _exportLastIndexReport(List<Map<String, dynamic>> data) {
    return () async {
      final buffer = StringBuffer();
      buffer.writeln('SON ENDEKSLERRaporu');
      buffer.writeln(
        'Tarih: ${DateFormat('dd.MM.yyyy').format(DateTime.now())}',
      );
      buffer.writeln('---');
      for (var row in data) {
        buffer.writeln('${row['ad']} (${row['aboneNo']}): ${row['endeks']}');
      }
      _shareReport(buffer.toString(), 'son_endeks_raporu.txt');
    };
  }

  Function() _printLastIndexReport(List<Map<String, dynamic>> data) {
    return () async {
      try {
        final printerService = PrinterService();
        if (!printerService.isConnected()) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Yazıcı bağlı değil'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        final db = ref.read(dbProvider);
        final ayarlar = await db.getSettings();
        if (ayarlar == null) {
          throw Exception('Ayarlar yüklenemedi');
        }

        // Başlık ve tarih bilgisi
        final buffer = StringBuffer();
        buffer.writeln('${ayarlar.antetBaslik}');
        buffer.writeln('${ayarlar.antetAdres}');
        buffer.writeln('');
        buffer.writeln('SON ENDEKS RAPORU');
        buffer.writeln(
          'Tarih: ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())}',
        );
        buffer.writeln('');

        // Tablo başlığı
        buffer.writeln('Abone  Ad Soyad                        Endeks');
        buffer.writeln('---------------------------------------------');

        // Endeks listesi - tablo formatında
        for (var row in data) {
          final aboneNo = (row['aboneNo'] as String).padRight(
            7,
          ); // 6 + 1 boşluk
          final adSoyad = (row['ad'] as String);
          final endeks = (row['endeks'] as double)
              .toStringAsFixed(2)
              .padLeft(10);

          // Ad Soyad'ı 30 karaktere sığdır
          String adSoyadFormatted;
          if (adSoyad.length > 30) {
            adSoyadFormatted = '${adSoyad.substring(0, 27)}...'.padRight(
              31,
            ); // 30 + 1 boşluk
          } else {
            adSoyadFormatted = adSoyad.padRight(31); // 30 + 1 boşluk
          }

          buffer.writeln('$aboneNo$adSoyadFormatted$endeks');
        }

        buffer.writeln('');
        buffer.writeln('Toplam Abone: ${data.length}');
        buffer.writeln('');
        buffer.writeln('${ayarlar.altBilgi}');

        await printerService.printText(buffer.toString());

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Rapor yazdırılıyor...'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Yazdırma hatası: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    };
  }

  Function() _exportDebtReport(
    List<Map<String, dynamic>> data,
    double toplamBorc,
  ) {
    return () async {
      final buffer = StringBuffer();
      buffer.writeln('TOPLAM BORÇ RAPORU');
      buffer.writeln(
        'Tarih: ${DateFormat('dd.MM.yyyy').format(DateTime.now())}',
      );
      buffer.writeln('---');
      for (var row in data) {
        buffer.writeln(
          '${row['ad']} (${row['aboneNo']}): ${(row['borc'] as double).toStringAsFixed(2)} ₺',
        );
      }
      buffer.writeln('---');
      buffer.writeln('TOPLAM BORÇ: ${toplamBorc.toStringAsFixed(2)} ₺');
      _shareReport(buffer.toString(), 'toplam_borc_raporu.txt');
    };
  }

  Function() _exportBillingRatiosReport(
    List<Map<String, dynamic>> data,
    double toplamTahakkuk,
  ) {
    return () async {
      final buffer = StringBuffer();
      buffer.writeln('TAHAKKUK VE TAHSİLAT ORANI RAPORU');
      buffer.writeln(
        'Tarih: ${DateFormat('dd.MM.yyyy').format(DateTime.now())}',
      );
      buffer.writeln('---');
      for (var row in data) {
        buffer.writeln(
          '${row['donem']}: ${(row['tahakkuk'] as double).toStringAsFixed(2)} ₺',
        );
      }
      buffer.writeln('---');
      buffer.writeln('TOPLAM: ${toplamTahakkuk.toStringAsFixed(2)} ₺');
      _shareReport(buffer.toString(), 'tahakkuk_raporu.txt');
    };
  }

  Function() _exportOverdueReport(List<Map<String, dynamic>> data) {
    return () async {
      final buffer = StringBuffer();
      buffer.writeln('GECİKMİŞ ÖDEME RAPORU');
      buffer.writeln(
        'Tarih: ${DateFormat('dd.MM.yyyy').format(DateTime.now())}',
      );
      buffer.writeln('---');
      for (var row in data) {
        buffer.writeln('${row['ad']} (${row['aboneNo']})');
        buffer.writeln('  Dönem: ${row['donem']}');
        buffer.writeln('  Son Ödeme: ${row['sonOdeme']}');
        buffer.writeln(
          '  Borç: ${(row['borc'] as double).toStringAsFixed(2)} ₺',
        );
      }
      _shareReport(buffer.toString(), 'geciknis_odeme_raporu.txt');
    };
  }

  Function() _exportConsumptionReport(
    List<Map<String, dynamic>> data,
    double toplamTuketim,
  ) {
    return () async {
      final buffer = StringBuffer();
      buffer.writeln('SU TÜKETIM RAPORU');
      buffer.writeln(
        'Tarih: ${DateFormat('dd.MM.yyyy').format(DateTime.now())}',
      );
      buffer.writeln('---');
      for (var row in data) {
        buffer.writeln(
          '${row['ad']} (${row['aboneNo']}): ${(row['tuketim'] as double).toStringAsFixed(2)} m³',
        );
      }
      buffer.writeln('---');
      buffer.writeln('TOPLAM TÜKETİM: ${toplamTuketim.toStringAsFixed(2)} m³');
      _shareReport(buffer.toString(), 'tuketim_raporu.txt');
    };
  }

  Future<void> _shareReport(String content, String fileName) async {
    await Share.share(content, subject: fileName);
  }
}
