import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bluetooth_classic/models/device.dart';
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
  List<Device> _devices = [];
  bool _isLoading = false;
  Device? _selectedDevice;

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

  Future<void> _connectToDevice(Device device) async {
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
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        children: [
          // Handle bar
          Container(
            padding: const EdgeInsets.only(top: 12),
            child: Center(
              child: Container(
                width: 40,
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
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.bluetooth,
                  color: isConnected ? Colors.green : Colors.grey,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Yazıcı Bağlantısı',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isConnected ? 'Yazıcı bağlı' : 'Yazıcı bağlı değil',
                        style: TextStyle(
                          color: isConnected
                              ? Colors.green.shade600
                              : Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isConnected)
                  IconButton(
                    icon: const Icon(Icons.close),
                    color: Colors.red,
                    onPressed: _disconnect,
                    tooltip: 'Bağlantıyı Kes',
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Content
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                // Status card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isConnected
                        ? Colors.green.shade50
                        : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isConnected
                          ? Colors.green.shade200
                          : Colors.blue.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isConnected ? Icons.check_circle : Icons.info_outline,
                        color: isConnected
                            ? Colors.green.shade700
                            : Colors.blue.shade700,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isConnected
                              ? 'Yazıcı bağlı, yazdırma için hazır'
                              : 'Aşağıdan yazıcı seçerek bağlayın',
                          style: TextStyle(
                            color: isConnected
                                ? Colors.green.shade700
                                : Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Devices section header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Eşleştirilmiş Yazıcılar',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (!_isLoading)
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _loadDevices,
                        tooltip: 'Yenile',
                      ),
                  ],
                ),
                // Devices list
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  )
                else if (_devices.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.bluetooth_disabled,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Eşleştirilmiş yazıcı bulunamadı',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Bluetooth ayarlarından yazıcıyı eşleştirdikten sonra burada görünecek',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _devices.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final device = _devices[index];
                      final isConnecting = _selectedDevice == device;

                      return Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: Icon(
                            Icons.print,
                            color: Colors.grey.shade600,
                          ),
                          title: Text(
                            device.name ?? 'Bilinmeyen Cihaz',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            device.address,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          trailing: isConnecting
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : ElevatedButton(
                                  onPressed: _selectedDevice != null
                                      ? null
                                      : () => _connectToDevice(device),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0F4C81),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                  ),
                                  child: const Text(
                                    'Bağlan',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
