import 'dart:async';
import 'dart:typed_data';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import '../models/app_bluetooth_device.dart';
import 'bluetooth_manager.dart';
import 'package:js/js.dart';

class BluetoothManagerWeb implements BluetoothManager {
  final bluetooth = js_util.getProperty(html.window.navigator, 'bluetooth');
  final List<AppBluetoothDevice> _foundDevices = [];
  final _weightController = StreamController<String>.broadcast();
  String _status = 'Idle';

  dynamic _device;
  dynamic _server;
  dynamic _characteristic;
  html.EventListener? _notificationListener;

  @override
  Stream<String> get weightStream => _weightController.stream;

  @override
  List<AppBluetoothDevice> get foundDevices => _foundDevices;

  @override
  String get status => _status;

  @override
  Future<void> scanForDevices() async {
    _status = 'Mencari perangkat...';
    if (bluetooth == null) {
      _status = 'Web Bluetooth tidak didukung di browser ini';
      print('Error: Web Bluetooth tidak didukung');
      return;
    }

    try {
      final device = await js_util.promiseToFuture(
        js_util.callMethod(bluetooth, 'requestDevice', [
          js_util.jsify({
            'filters': [
              {
                'services': ['cd5cac32-0548-437b-b273-e0bf0d372110'],
              },
            ],
            'optionalServices': ['cd5cac32-0548-437b-b273-e0bf0d372110'],
          }),
        ]),
      );

      if (device != null) {
        _foundDevices.clear();
        final deviceId = js_util.getProperty(device, 'id') as String;
        final deviceName =
            (js_util.getProperty(device, 'name') ?? 'Unnamed') as String;
        _foundDevices.add(
          AppBluetoothDevice(
            id: deviceId,
            name: deviceName,
            nativeDevice: device,
          ),
        );
        _status = 'Perangkat ditemukan: $deviceName';
        _device = device;
      } else {
        _status = 'Tidak ada perangkat dipilih atau izin ditolak';
      }
    } catch (e) {
      _status = 'Error saat mencari perangkat: $e';
      print('Scan error: $e');
    }
  }

  @override
  Future<void> connectToDevice(AppBluetoothDevice device) async {
    if (device.nativeDevice == null) {
      _status = "No device to connect";
      return;
    }

    _status = "Connecting to device...";

    try {
      _server = js_util.getProperty(device.nativeDevice, 'gatt');
      await js_util.promiseToFuture(js_util.callMethod(_server, 'connect', []));
      await exploreServices(device.nativeDevice);

      _status = "Connected to ${device.name}";
    } catch (e) {
      _status = "Connection failed: $e";
      print('Connect error: $e');
    }
  }

  Future<void> exploreServices(dynamic device) async {
    try {
      final gatt = js_util.getProperty(device, 'gatt');
      final services = await js_util.promiseToFuture(
        js_util.callMethod(gatt, 'getPrimaryServices', []),
      );

      for (var service in services) {
        final serviceUuid = js_util.getProperty(service, 'uuid') as String;
        print("🔹 Service: $serviceUuid");

        if (serviceUuid.toLowerCase() ==
            'cd5cac32-0548-437b-b273-e0bf0d372110') {
          final characteristics = await js_util.promiseToFuture(
            js_util.callMethod(service, 'getCharacteristics', []),
          );

          for (var char in characteristics) {
            final charUuid = js_util.getProperty(char, 'uuid') as String;
            final props = js_util.getProperty(char, 'properties');
            final canNotify = js_util.getProperty(props, 'notify') as bool;
            print("   ↳ Char: $charUuid | Notify: $canNotify");

            if (charUuid.toLowerCase() ==
                    'bb0c63ff-6916-4c89-b62e-a2b090c78601' &&
                canNotify) {
              _characteristic = char;
              print("Mencoba mengaktifkan notifikasi untuk $charUuid");
              await startNotifications(_characteristic);
            }
          }
        }
      }
    } catch (e) {
      print("⚠️ exploreServices error: $e");
    }
  }

  Future<void> startNotifications(dynamic char) async {
    try {
      await js_util.promiseToFuture(
        js_util.callMethod(char, 'startNotifications', []),
      );
      print(
        "Notifikasi berhasil diaktifkan untuk ${js_util.getProperty(char, 'uuid')}",
      );
      _notificationListener = allowInterop((html.Event event) {
        final jsObject = js_util.getProperty(event, 'target');
        final value = js_util.getProperty(jsObject, 'value');
        final buffer = js_util.getProperty(value, 'buffer');
        final bytes = Uint8List.view(buffer);

        final weight = String.fromCharCodes(bytes).trim();
        print("📩 Data diterima: $weight kg");
        _weightController.add(weight);

        print("Bytes: $bytes");
      });
      js_util.callMethod(char, 'addEventListener', [
        'characteristicvaluechanged',
        _notificationListener,
      ]);
      print("Notifikasi listener ditambahkan.");
    } catch (e) {
      print("⚠️ Error startNotifications: $e");
      _status = "Notifikasi tidak didukung, mencoba baca manual...";
      _startPolling(char);
    }
  }

  void _startPolling(dynamic char) {
    Timer.periodic(Duration(seconds: 2), (timer) async {
      try {
        final value = await js_util.promiseToFuture(
          js_util.callMethod(char, 'readValue', []),
        );
        final buffer = js_util.getProperty(value, 'buffer');
        final bytes = Uint8List.view(buffer);

        final weight = String.fromCharCodes(bytes).trim();
        print("📩 Data dari polling: $weight kg");
        _weightController.add(weight);
      } catch (e) {
        print("⚠️ Polling error: $e");
      }
    });
  }

  Future<void> stopNotifications(dynamic char) async {
    if (_notificationListener != null) {
      js_util.callMethod(char, 'removeEventListener', [
        'characteristicvaluechanged',
        _notificationListener,
      ]);
      _notificationListener = null;
    }

    try {
      await js_util.promiseToFuture(
        js_util.callMethod(char, 'stopNotifications', []),
      );
    } catch (e) {
      print("⚠️ stopNotifications error: $e");
    }
  }

  @override
  Future<void> disconnect() async {
    if (_server != null) {
      try {
        if (_characteristic != null) {
          await stopNotifications(_characteristic);
        }
        await js_util.promiseToFuture(
          js_util.callMethod(_server, 'disconnect', []),
        );
        _status = "Disconnected from device";
      } catch (e) {
        _status = "Disconnection failed: $e";
        print('Disconnect error: $e');
      }
    }
  }

  @override
  void dispose() {
    if (_characteristic != null) {
      stopNotifications(_characteristic);
    }
    _weightController.close();
  }
}
