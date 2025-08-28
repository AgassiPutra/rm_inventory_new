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

    try {
      final device = await js_util.promiseToFuture(
        js_util.callMethod(bluetooth, 'requestDevice', [
          js_util.jsify({
            'acceptAllDevices': true,
            'optionalServices': ['generic_access', 'device_information'],
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
        _status = 'No device selected';
      }
    } catch (e) {
      _status = 'Error during device request: $e';
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

      _status = "Connected (check console for services/characteristics)";
    } catch (e) {
      _status = "Connection failed: $e";
    }
  }

  Future<void> exploreServices(dynamic device) async {
    try {
      final gatt = js_util.getProperty(device, 'gatt');
      final services = await js_util.promiseToFuture(
        js_util.callMethod(gatt, 'getPrimaryServices', []),
      );

      for (var service in services) {
        final serviceUuid = js_util.getProperty(service, 'uuid');
        print("🔹 Service: $serviceUuid");

        final characteristics = await js_util.promiseToFuture(
          js_util.callMethod(service, 'getCharacteristics', []),
        );

        for (var char in characteristics) {
          final charUuid = js_util.getProperty(char, 'uuid');
          final props = js_util.getProperty(char, 'properties');
          print("   ↳ Char: $charUuid | props: $props");
        }
      }
    } catch (e) {
      print("⚠️ exploreServices error: $e");
    }
  }

  Future<void> startNotifications(dynamic char) async {
    await js_util.promiseToFuture(
      js_util.callMethod(char, 'startNotifications', []),
    );
    _notificationListener = (html.Event event) {
      final jsObject = js_util.getProperty(event, 'target');
      final value = js_util.getProperty(jsObject, 'value');
      final buffer = js_util.getProperty(value, 'buffer');
      final bytes = Uint8List.view(buffer);

      final weight = String.fromCharCodes(bytes).trim();
      _weightController.add(weight);
    };
    js_util.callMethod(char, 'addEventListener', [
      'characteristicvaluechanged',
      _notificationListener,
    ]);
  }

  Future<void> stopNotifications(dynamic char) async {
    if (_notificationListener != null) {
      js_util.callMethod(char, 'removeEventListener', [
        'characteristicvaluechanged',
        _notificationListener,
      ]);
      _notificationListener = null;
    }

    await js_util.promiseToFuture(
      js_util.callMethod(char, 'stopNotifications', []),
    );
    await _weightController.close();
  }

  @override
  Future<void> disconnect() async {
    if (_server != null) {
      try {
        await js_util.promiseToFuture(
          js_util.callMethod(_server, 'disconnect', []),
        );
        _status = "Disconnected from device";
      } catch (e) {
        _status = "Disconnection failed: $e";
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
