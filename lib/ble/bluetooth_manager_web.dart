import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_web_bluetooth/flutter_web_bluetooth.dart';

import '../models/app_bluetooth_device.dart';
import 'bluetooth_manager.dart';

class BluetoothManagerWeb implements BluetoothManager {
  final FlutterWebBluetoothInterface _ble = FlutterWebBluetooth.instance;

  final List<AppBluetoothDevice> _foundDevices = [];
  final _weightController = StreamController<String>.broadcast();

  BluetoothDevice? _device;
  BluetoothCharacteristic? _notifyChar;
  StreamSubscription<ByteData>? _valueSub;

  String _status = 'Idle';
  static const String _serviceUuid = 'cd5cac32-0548-437b-b273-e0bf0d372110';
  static const String _charUuid = 'bb0c63ff-6916-4c89-b62e-a2b090c78601';
  static const String _ledUuID = 'b75501ff-4e00-45d1-bab1-09f4b5a6dddf';

  @override
  Stream<String> get weightStream => _weightController.stream;

  @override
  List<AppBluetoothDevice> get foundDevices => _foundDevices;

  @override
  String get status => _status;

  @override
  Future<void> scanForDevices() async {
    _status = 'Meminta perangkat...';

    if (!_ble.isBluetoothApiSupported) {
      _status = 'Web Bluetooth tidak didukung pada browser ini';
      return;
    }

    try {
      final options = RequestOptionsBuilder(
        [
          RequestFilterBuilder(services: [_serviceUuid]),
        ],
        optionalServices: [_serviceUuid],
      );

      final dev = await _ble.requestDevice(options);

      if (dev != null) {
        _foundDevices
          ..clear()
          ..add(
            AppBluetoothDevice(
              id: dev.id,
              name: dev.name ?? 'Unnamed',
              nativeDevice: dev,
            ),
          );
        _device = dev;
        _status = 'Perangkat ditemukan: ${dev.name ?? dev.id}';
      } else {
        _status = 'Tidak ada perangkat dipilih (dialog dibatalkan)';
      }
    } on SecurityError catch (e) {
      _status = 'Service/Characteristic diblokir browser: $e';
    } on BluetoothAdapterNotAvailable {
      _status = 'Adapter Bluetooth tidak tersedia/disabled';
    } catch (e) {
      _status = 'Error saat memindai: $e';
    }
  }

  @override
  Future<void> connectToDevice(AppBluetoothDevice device) async {
    final native = device.nativeDevice;
    if (native is! BluetoothDevice) {
      _status = 'Objek device tidak valid';
      return;
    }

    _status = 'Menghubungkan ke ${device.name}...';

    try {
      await native.connect(timeout: const Duration(seconds: 5));

      final services = await native.discoverServices();
      final service = services.firstWhere(
        (s) => s.uuid.toLowerCase() == _serviceUuid,
        orElse: () => throw Exception('Service $_serviceUuid tidak ditemukan'),
      );

      final ch = await service.getCharacteristic(_charUuid);
      _notifyChar = ch;

      await ch.startNotifications();

      await _valueSub?.cancel();
      _valueSub = ch.value.listen(
        (ByteData data) {
          final rawData = _decodeText(data).trim();

          if (rawData.isNotEmpty) {
            final isParsable = double.tryParse(rawData) != null;

            if (isParsable) {
              _weightController.add(rawData);
            } else {
              _weightController.add('SAVE_SIGNAL');
            }
          }
        },
        onError: (e) {
          _status = 'Error notifikasi: $e';
        },
        cancelOnError: false,
      );

      _status = 'Terhubung ke ${device.name}';
      _device = native;
    } on SecurityError catch (e) {
      _status = 'Hak akses ditolak: $e';
    } on NetworkError catch (e) {
      _status = 'Gagal komunikasi GATT: $e';
    } catch (e) {
      _status = 'Gagal menghubungkan: $e';
    }
  }

  String _decodeText(ByteData data) {
    final bytes = data.buffer.asUint8List();
    int last = bytes.length - 1;
    while (last >= 0 && bytes[last] == 0) {
      last--;
    }
    if (last < 0) return '';

    final trimmed = Uint8List.sublistView(bytes, 0, last + 1);
    return utf8.decode(trimmed, allowMalformed: true);
  }

  Future<void> _stopNotifications() async {
    try {
      await _valueSub?.cancel();
      _valueSub = null;

      final ch = _notifyChar;
      _notifyChar = null;

      if (ch != null) {
        await ch.stopNotifications();
      }
    } catch (_) {}
  }

  @override
  Future<void> disconnect() async {
    await _stopNotifications();
    _device?.disconnect();
    _device = null;
    _status = 'Disconnected';
  }

  @override
  void dispose() {
    _stopNotifications();
    _weightController.close();
  }
}
