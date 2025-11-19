import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'db/app_database.dart';
import 'services/printer_service.dart';

final dbProvider = Provider<AppDatabase>((ref) => AppDatabase());
final authProvider = StateProvider<bool>((ref) => false);
final printerServiceProvider = Provider<PrinterService>(
  (ref) => PrinterService(),
);

// Auto-connect printer on app startup
final printerAutoConnectProvider = FutureProvider<bool>((ref) async {
  final db = ref.watch(dbProvider);
  final printerService = ref.watch(printerServiceProvider);

  try {
    // Get saved printer settings
    final settings = await db.getSettings();
    if (settings == null ||
        settings.yaziciBluetoothMac == null ||
        settings.yaziciBluetoothMac!.isEmpty) {
      return false;
    }

    // Get bonded devices
    final devices = await printerService.getDevices();
    final savedDevice = devices.firstWhere(
      (device) => device.address == settings.yaziciBluetoothMac,
      orElse: () => throw Exception('Yazıcı bulunamadı'),
    );

    // Connect to printer
    final connected = await printerService.connect(savedDevice);
    return connected;
  } catch (e) {
    // Silent fail - printer not found or not configured
    return false;
  }
});
