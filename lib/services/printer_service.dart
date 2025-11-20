import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import 'bixolon_slcs.dart';

class PrinterDevice {
  final String name;
  final String address;
  final bool bonded;

  const PrinterDevice({
    required this.name,
    required this.address,
    this.bonded = true,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PrinterDevice && other.address == address;
  }

  @override
  int get hashCode => address.hashCode;
}

class PrinterService {
  // Singleton pattern
  static final PrinterService _instance = PrinterService._internal();
  factory PrinterService() => _instance;
  PrinterService._internal();

  final FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;
  BluetoothConnection? _connection;
  PrinterDevice? _connectedDevice;
  bool _isConnecting = false;

  /// Eşleştirilmiş Bluetooth cihazlarını listele
  Future<List<PrinterDevice>> getDevices() async {
    try {
      await _ensurePermissions();
      await _ensureBluetoothEnabled();
      final bondedDevices = await _bluetooth.getBondedDevices();
      return bondedDevices
          .where((device) => device.address.isNotEmpty)
          .map(
            (device) => PrinterDevice(
              name: device.name ?? 'Bilinmeyen Cihaz',
              address: device.address,
              bonded: true,
            ),
          )
          .toList();
    } catch (e) {
      throw Exception('Cihazlar alınamadı: $e');
    }
  }

  /// Yazıcıya bağlan
  Future<bool> connect(PrinterDevice device) async {
    if (_isConnecting) {
      return false;
    }

    if (isConnected() && _connectedDevice?.address == device.address) {
      return true;
    }

    _isConnecting = true;
    try {
      await _ensurePermissions();
      await _ensureBluetoothEnabled();

      await disconnect();
      final connection = await BluetoothConnection.toAddress(device.address);
      _connection = connection;
      _connectedDevice = device;

      // Dinleyici bağlantı koptuğunda state'i temizlesin
      connection.input?.listen(
        (_) {},
        onDone: () {
          _connectedDevice = null;
          _connection = null;
        },
      );

      return true;
    } catch (e) {
      _connectedDevice = null;
      _connection = null;
      rethrow;
    } finally {
      _isConnecting = false;
    }
  }

  /// Yazıcı bağlantısını kes
  Future<void> disconnect() async {
    try {
      await _connection?.close();
      _connection?.dispose();
    } catch (_) {
      // Ignore dispose errors
    } finally {
      _connection = null;
      _connectedDevice = null;
    }
  }

  /// Bağlı mı kontrol et
  bool isConnected() {
    return _connection?.isConnected ?? false;
  }

  /// Bağlı cihaz
  PrinterDevice? get connectedDevice => _connectedDevice;

  Future<void> _ensurePermissions() async {
    if (!Platform.isAndroid) return;

    final permissions = <Permission>[
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.location,
      Permission.locationWhenInUse,
    ];

    final results = await permissions.request();
    final denied = results.values.any(
      (status) =>
          status.isDenied || status.isPermanentlyDenied || status.isRestricted,
    );

    if (denied) {
      throw Exception('Bluetooth izinleri verilmedi');
    }
  }

  Future<void> _ensureBluetoothEnabled() async {
    final state = await _bluetooth.state;
    if (state == BluetoothState.STATE_OFF) {
      final enabled = await _bluetooth.requestEnable();
      if (enabled != true) {
        throw Exception('Bluetooth açılamadı');
      }
    }
  }

  /// Veri gönder
  Future<void> _sendData(Uint8List data) async {
    final connection = _connection;
    if (connection == null || !connection.isConnected) {
      throw Exception('Yazıcı bağlı değil');
    }

    try {
      connection.output.add(data);
      await connection.output.allSent;
      await Future.delayed(const Duration(milliseconds: 200));
    } catch (e) {
      throw Exception('Veri gönderilemedi: $e');
    }
  }

  // -----------------------------------------------------
  //  MAKBUZ
  // -----------------------------------------------------

  Future<void> printMakbuz({
    required String antetBaslik,
    required String antetAdres,
    required String altBilgi,
    required String aboneAd,
    required String aboneNo,
    required String donem,
    required double ilkEndeks,
    required double sonEndeks,
    required double tuketim,
    required double birimFiyat,
    required double tutar,
    required double odenen,
    required double kalan,
    required String tarih,
    String? tahakkukUuid,
  }) async {
    if (!isConnected()) {
      throw Exception("Yazıcı bağlı değil");
    }

    final bixolon = BixolonSlcsGenerator(pageWidthDots: 550);

    // ------------ Üst Başlık ------------
    bixolon.addText(antetBaslik, fontType: 2, bold: true, align: 'C');
    bixolon.addText(antetAdres, fontType: 1, bold: false, align: 'C');

    bixolon.addText(
      "SU TÜKETİM İHBARNAMESİ",
      fontType: 3,
      bold: true,
      align: 'C',
    );
    bixolon.addFeed(20);

    // ------------ Genel Bilgiler ------------
    bixolon.addText(
      "Tarih:".padRight(20) + tarih,
      fontType: 1,
      bold: false,
      align: 'L',
    );
    bixolon.addText(
      "Abone:".padRight(20) + aboneAd,
      fontType: 1,
      bold: false,
      align: 'L',
    );
    bixolon.addText(
      "Abone No:".padRight(20) + aboneNo,
      fontType: 1,
      bold: false,
      align: 'L',
    );
    bixolon.addText(
      "Donem:".padRight(20) + donem,
      fontType: 1,
      bold: false,
      align: 'L',
    );

    bixolon.drawLine();

    // ------------ Endeks Bilgileri ------------
    bixolon.addText(
      "Ilk Endeks:".padRight(20) + ilkEndeks.toStringAsFixed(2),
      fontType: 1,
      bold: false,
      align: 'L',
    );
    bixolon.addText(
      "Son Endeks:".padRight(20) + sonEndeks.toStringAsFixed(2),
      fontType: 1,
      bold: false,
      align: 'L',
    );
    bixolon.addText(
      "Tuketim:".padRight(20) + tuketim.toStringAsFixed(2) + " m3",
      fontType: 1,
      bold: false,
      align: 'L',
    );
    bixolon.addText(
      "Birim Fiyat:".padRight(20) + birimFiyat.toStringAsFixed(2) + " TL",
      fontType: 1,
      bold: false,
      align: 'L',
    );

    bixolon.drawLine();

    // ------------ Tutar Bilgileri ------------
    bixolon.addText(
      "Toplam Tutar   : ${tutar.toStringAsFixed(2)} TL",
      fontType: 2,
      bold: true,
      align: 'L',
    );
    bixolon.addText(
      "Odenen         : ${odenen.toStringAsFixed(2)} TL",
      fontType: 2,
      bold: false,
      align: 'L',
    );
    bixolon.addText(
      "Kalan          : ${kalan.toStringAsFixed(2)} TL",
      fontType: 2,
      bold: true,
      align: 'L',
    );

    bixolon.addFeed(15);

    // ------------ Alt Bilgi ------------
    bixolon.addText(altBilgi, fontType: 1, bold: false, align: 'C');
    bixolon.addFeed(5);

    // QR Code with tahakkuk UUID
    if (tahakkukUuid != null && tahakkukUuid.isNotEmpty) {
      bixolon.addQRCode(tahakkukUuid);
    } else {
      // Fallback to random UUID if not provided
      var uid = const Uuid().v4();
      bixolon.addQRCode(uid);
    }

    // Yazdır
    final bytes = bixolon.getBytes();
    await _sendData(bytes);
  }

  // -----------------------------------------------------
  //  İHBARNAME
  // -----------------------------------------------------

  Future<void> printIhbarname({
    required String antetBaslik,
    required String antetAdres,
    required String aboneAd,
    required String aboneNo,
    required String donem,
    required double kalan,
    required String sonOdemeTarihi,
  }) async {
    if (!isConnected()) {
      throw Exception("Yazıcı bağlı değil");
    }

    final bixolon = BixolonSlcsGenerator(pageWidthDots: 550);

    bixolon.addText(antetBaslik, fontType: 2, bold: true, align: 'C');
    bixolon.addText(antetAdres, fontType: 1, bold: false, align: 'C');
    bixolon.addFeed(10);

    bixolon.addText("IHBARNAME", fontType: 3, bold: true, align: 'C');
    bixolon.addFeed(10);

    bixolon.addText("Abone: $aboneAd", fontType: 1, bold: false, align: 'L');
    bixolon.addText("Abone No: $aboneNo", fontType: 1, bold: false, align: 'L');
    bixolon.addText("Donem: $donem", fontType: 1, bold: false, align: 'L');

    bixolon.drawLine();

    bixolon.addText(
      "Borc: ${kalan.toStringAsFixed(2)} TL",
      fontType: 2,
      bold: true,
      align: 'L',
    );
    bixolon.addText(
      "Son Odeme: $sonOdemeTarihi",
      fontType: 1,
      bold: false,
      align: 'L',
    );

    bixolon.addFeed(10);

    bixolon.addText(
      "Lutfen borcunuzu son odeme tarihine kadar yatiriniz.",
      fontType: 1,
      bold: false,
      align: 'C',
    );

    bixolon.addFeed(5);

    final bytes = bixolon.getBytes();
    await _sendData(bytes);
  }

  // -----------------------------------------------------
  //  GÉNÉRİK METNİ YAZDIR
  // -----------------------------------------------------

  Future<void> printText(String text) async {
    if (!isConnected()) {
      throw Exception("Yazıcı bağlı değil");
    }

    final bixolon = BixolonSlcsGenerator(pageWidthDots: 550);

    // Split text into lines and print each
    final lines = text.split('\n');
    for (final line in lines) {
      if (line.trim().isEmpty) {
        bixolon.addFeed(5);
      } else if (line.startsWith('===')) {
        bixolon.addText(line, fontType: 2, bold: true, align: 'C');
      } else {
        bixolon.addText(line, fontType: 1, bold: false, align: 'L');
      }
    }

    bixolon.addFeed(10);

    final bytes = bixolon.getBytes();
    await _sendData(bytes);
  }

  // -----------------------------------------------------
  //  TEST YAZDIR
  // -----------------------------------------------------

  Future<void> printTestTicket() async {
    if (!isConnected()) {
      throw Exception("Yazıcı bağlı değil");
    }

    final bixolon = BixolonSlcsGenerator(pageWidthDots: 550);

    bixolon.addText("T.C.", fontType: 2, bold: true, align: 'C');
    bixolon.addText("BASYAYLA KOYU", fontType: 2, bold: true, align: 'C');
    bixolon.addText("MUHTARLIGI", fontType: 2, bold: true, align: 'C');
    bixolon.addFeed(10);

    bixolon.addText(
      "Turkce Karakterler: ÇĞIÖŞÜ çğıöşü",
      fontType: 1,
      bold: false,
      align: 'C',
    );
    bixolon.addFeed(5);

    bixolon.addText("Bold text", fontType: 1, bold: true, align: 'L');
    bixolon.addText("Normal text", fontType: 1, bold: false, align: 'L');
    bixolon.addText("Center align", fontType: 1, bold: false, align: 'C');
    bixolon.addText("Right align", fontType: 1, bold: false, align: 'R');

    bixolon.drawLine();

    bixolon.addText(
      "Abone Adi      : Cihad GUNDOGDU",
      fontType: 1,
      bold: false,
      align: 'L',
    );
    bixolon.addText(
      "Kimlik No      : 62389268914",
      fontType: 1,
      bold: false,
      align: 'L',
    );
    bixolon.addText(
      "Ilk Endeks     : 100",
      fontType: 1,
      bold: false,
      align: 'L',
    );
    bixolon.addText(
      "Son Endeks     : 250",
      fontType: 1,
      bold: false,
      align: 'L',
    );
    bixolon.addText(
      "Tuketim        : 150 m3",
      fontType: 1,
      bold: false,
      align: 'L',
    );
    bixolon.addText(
      "Toplam Tutar   : 450.00 TL",
      fontType: 1,
      bold: false,
      align: 'L',
    );

    bixolon.drawLine();

    bixolon.addText("Test basarili!", fontType: 2, bold: true, align: 'C');
    bixolon.addFeed(5);

    final bytes = bixolon.getBytes();
    await _sendData(bytes);
  }
}
