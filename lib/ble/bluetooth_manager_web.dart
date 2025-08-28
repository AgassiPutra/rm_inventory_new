import 'dart:async';
import 'dart:typed_data';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import '../models/app_bluetooth_device.dart';
import 'bluetooth_manager.dart';

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
    _status = 'Requesting device...';
    if (bluetooth == null) {
      _status = 'Web Bluetooth not supported in this browser';
      print('Error: Web Bluetooth not supported');
      return;
    }

    try {
      final device = await js_util.promiseToFuture(
        js_util.callMethod(bluetooth, 'requestDevice', [
          js_util.jsify({
            'filters': [
              {
                'services': ['0000181d-0000-1000-8000-00805f9b34fb'],
              },
            ],
            'optionalServices': ['0000181d-0000-1000-8000-00805f9b34fb'],
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

        _status = 'Device found: $deviceName';
        _device = device;
      } else {
        _status = 'No device selected or permission denied';
      }
    } catch (e) {
      _status = 'Error during device request: $e';
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
            '0000181d-0000-1000-8000-00805f9b34fb') {
          final characteristics = await js_util.promiseToFuture(
            js_util.callMethod(service, 'getCharacteristics', []),
          );

          for (var char in characteristics) {
            final charUuid = js_util.getProperty(char, 'uuid') as String;
            final props = js_util.getProperty(char, 'properties');
            final canNotify = js_util.getProperty(props, 'notify') as bool;
            print("   ↳ Char: $charUuid | Notify: $canNotify");

            if (charUuid.toLowerCase() ==
                    '00002a9d-0000-1000-8000-00805f9b34fb' &&
                canNotify) {
              _characteristic = char;
              print("Attempting to start notifications for $charUuid");
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
      _notificationListener = (html.Event event) {
        final jsObject = js_util.getProperty(event, 'target');
        final value = js_util.getProperty(jsObject, 'value');
        final buffer = js_util.getProperty(value, 'buffer');
        final bytes = Uint8List.view(buffer);

        if (bytes.length >= 3) {
          int weightRaw = (bytes[2] << 8) | bytes[1];
          double weight = weightRaw * 0.01;
          print("📩 Data diterima: $weight kg");
          _weightController.add(weight.toStringAsFixed(2));
        } else {
          print("⚠️ Panjang data tidak valid: ${bytes.length}");
        }
      };
      js_util.callMethod(char, 'addEventListener', [
        'characteristicvaluechanged',
        _notificationListener,
      ]);
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
        if (bytes.length >= 3) {
          int weightRaw = (bytes[2] << 8) | bytes[1];
          double weight = weightRaw * 0.01;
          print("📩 Data dari polling: $weight kg");
          _weightController.add(weight.toStringAsFixed(2));
        } else {
          print("⚠️ Panjang data tidak valid: ${bytes.length}");
        }
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
