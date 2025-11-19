import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers.dart';
import '../../widgets/printer_status_widget.dart';
import '../abone/aboneler_list_screen.dart';
import '../donem/donem_list_screen.dart';
import '../settings/settings_screen.dart';
import '../tahakkuk/tahakkuk_list_screen.dart';
import '../reports/reports_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Muhtar - Su Takip'),
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
                  MaterialPageRoute(builder: (_) => const AbonelerListScreen()),
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
                  MaterialPageRoute(builder: (_) => const DonemListScreen()),
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
                  MaterialPageRoute(builder: (_) => const TahakkukListScreen()),
                );
              },
            ),
            _buildGridButton(
              context,
              icon: Icons.assessment,
              label: 'Raporlar',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReportsScreen()),
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
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
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
