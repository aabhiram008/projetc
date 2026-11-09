import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:usb_serial/usb_serial.dart';

class UsbSerialService {
  UsbPort? _port;
  StreamSubscription<Uint8List>? _subscription;
  void Function(String message)? onMessage;
  String status = 'USB disconnected';
  bool get connected => _port != null;

  Future<String> connect() async {
    await disconnect();
    try {
      final devices = await UsbSerial.listDevices();
      if (devices.isEmpty) return status = 'No USB serial device found';
      final port = await devices.first.create();
      if (port == null) return status = 'Could not create USB port';
      if (!await port.open()) return status = 'Could not open USB port';
      await port.setPortParameters(
        115200,
        UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1,
        UsbPort.PARITY_NONE,
      );
      _port = port;
      _subscription = port.inputStream?.listen((bytes) {
        final text = utf8.decode(bytes, allowMalformed: true).trim();
        if (text.isNotEmpty) onMessage?.call(text);
      });
      return status = 'USB connected';
    } catch (error) {
      await disconnect();
      return status = 'USB error: $error';
    }
  }

  Future<bool> send(String command) async {
    final port = _port;
    if (port == null) return false;
    try {
      await port.write(Uint8List.fromList(utf8.encode('$command\n')));
      return true;
    } catch (error) {
      status = 'Serial write failed: $error';
      return false;
    }
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    final port = _port;
    _port = null;
    if (port != null) await port.close();
  }
}
