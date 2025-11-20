import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/printer_service.dart';

// Yazıcı bağlantı durumu provider'ı
final printerConnectionProvider =
    StateNotifierProvider<PrinterConnectionNotifier, bool>((ref) {
      return PrinterConnectionNotifier();
    });

class PrinterConnectionNotifier extends StateNotifier<bool> {
  final PrinterService _printerService = PrinterService();

  PrinterConnectionNotifier() : super(false) {
    _checkConnection();
  }

  void _checkConnection() {
    state = _printerService.isConnected();
  }

  void updateStatus(bool connected) {
    state = connected;
  }

  void refresh() {
    _checkConnection();
  }
}

// AppBar'da kullanılacak yazıcı durumu widget'ı
class PrinterStatusIcon extends ConsumerWidget {
  const PrinterStatusIcon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected = ref.watch(printerConnectionProvider);

    return IconButton(
      icon: Stack(
        children: [
          Icon(
            Icons.bluetooth,
            color: isConnected
                ? const Color.fromARGB(255, 32, 196, 26)
                : const Color.fromARGB(179, 190, 39, 39),
          ),
          if (isConnected)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
      tooltip: isConnected ? 'Yazıcı bağlı' : 'Yazıcı bağlı değil',
      onPressed: () {
        _showPrinterDialog(context, ref);
      },
    );
  }

  void _showPrinterDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => PrinterConnectionSheet(),
    );
  }
}

// Yazıcı bağlantı BottomSheet
class PrinterConnectionSheet extends ConsumerStatefulWidget {
  const PrinterConnectionSheet({super.key});

  @override
  ConsumerState<PrinterConnectionSheet> createState() =>
      _PrinterConnectionSheetState();
}

class _PrinterConnectionSheetState
    extends ConsumerState<PrinterConnectionSheet> {
  final PrinterService _printerService = PrinterService();
  List<PrinterDevice> _devices = [];
  bool _isLoading = false;
  PrinterDevice? _selectedDevice;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final devices = await _printerService.getDevices();
      setState(() {
        _devices = devices;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Cihazlar alınamadı: $e')));
      }
    }
  }

  Future<void> _connectToDevice(PrinterDevice device) async {
    setState(() {
      _selectedDevice = device;
    });

    try {
      final result = await _printerService.connect(device);

      if (result) {
        ref.read(printerConnectionProvider.notifier).updateStatus(true);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Yazıcı başarıyla bağlandı'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Yazıcıya bağlanılamadı'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bağlantı hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _selectedDevice = null;
        });
      }
    }
  }

  Future<void> _disconnect() async {
    try {
      await _printerService.disconnect();
      ref.read(printerConnectionProvider.notifier).updateStatus(false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Yazıcı bağlantısı kesildi'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bağlantı kesilemedi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = ref.watch(printerConnectionProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.8,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isConnected
                          ? Colors.green.shade50
                          : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                      color: isConnected
                          ? Colors.green.shade600
                          : Colors.blue.shade600,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Yazıcı Bağlantısı',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        Text(
                          isConnected ? 'Bağlı' : 'Bağlı değil',
                          style: TextStyle(
                            color: isConnected
                                ? Colors.green.shade600
                                : Colors.grey.shade500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isConnected)
                    IconButton(
                      icon: const Icon(Icons.power_off, size: 20),
                      color: Colors.red.shade400,
                      onPressed: _disconnect,
                      tooltip: 'Bağlantıyı Kes',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Content
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  // Status indicator
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isConnected
                          ? Colors.green.shade50
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isConnected
                            ? Colors.green.shade200
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isConnected ? Icons.check_circle : Icons.info,
                          color: isConnected
                              ? Colors.green.shade600
                              : Colors.grey.shade600,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isConnected ? 'Yazıcı hazır' : 'Yazıcı seçin',
                            style: TextStyle(
                              color: isConnected
                                  ? Colors.green.shade700
                                  : Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Devices section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Eşleştirilmiş Yazıcılar',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      if (!_isLoading)
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 20),
                          onPressed: _loadDevices,
                          tooltip: 'Yenile',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Devices list
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  else if (_devices.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.bluetooth_disabled,
                            size: 32,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Yazıcı bulunamadı',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._devices.map((device) {
                      final isConnecting = _selectedDevice == device;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.print,
                              color: Colors.grey.shade600,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            device.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                            ),
                          ),
                          subtitle: Text(
                            device.address,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                              fontFamily: 'monospace',
                            ),
                          ),
                          trailing: isConnecting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : SizedBox(
                                  width: 80,
                                  height: 32,
                                  child: ElevatedButton(
                                    onPressed: _selectedDevice != null
                                        ? null
                                        : () => _connectToDevice(device),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0F4C81),
                                      padding: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text(
                                      'Bağlan',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ),
                          dense: true,
                        ),
                      );
                    }),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
