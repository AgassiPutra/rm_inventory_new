import 'dart:async';
import 'dart:typed_data';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'bluetooth_manager.dart';

class BluetoothManagerImpl implements BluetoothManager {
  final _weightController = StreamController<String>.broadcast();

  List<dynamic> _foundDevices = [];
  String _status = "Idle";
  dynamic _device;

  @override
  Stream<String> get weightStream => _weightController.stream;

  html.EventListener? _notificationListener;

  @override
  Future<void> scanForDevices() async {
    _status = 'Requesting device...';

    try {
      final bluetooth = js_util.getProperty(html.window.navigator, 'bluetooth');

      final device = await js_util.promiseToFuture(
        js_util.callMethod(bluetooth, 'requestDevice', [
          js_util.jsify({
            'acceptAllDevices': true,
            'optionalServices': ['battery_service'],
          }),
        ]),
      );

      if (device != null) {
        _foundDevices.clear();
        _foundDevices.add(device);
        _status =
            'Device found: ${js_util.getProperty(device, 'name') ?? 'Unnamed'}';
        _device = device;
      } else {
        _status = 'No device selected';
      }
    } catch (e) {
      _status = 'Error: $e';
    }
  }

  @override
  Future<void> connectToDevice(dynamic device) async {
    try {
      _status = 'Connecting...';

      await js_util.promiseToFuture(
        js_util.callMethod(device, 'gatt.connect', []),
      );

      final gattServer = js_util.getProperty(device, 'gatt');

      final service = await js_util.promiseToFuture(
        js_util.callMethod(gattServer, 'getPrimaryService', [
          'battery_service',
        ]),
      );

      final characteristic = await js_util.promiseToFuture(
        js_util.callMethod(service, 'getCharacteristic', ['battery_level']),
      );

      await startNotifications(characteristic);

      _status =
          'Connected to ${js_util.getProperty(device, 'name') ?? 'Unnamed'}';
    } catch (e) {
      _status = 'Connection failed: $e';
    }
  }

  @override
  List<dynamic> get foundDevices => _foundDevices;

  @override
  String get status => _status;

  @override
  void dispose() {
    _notificationListener = null;
    _weightController.close();
    _foundDevices.clear();
    _status = "Idle";
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
}
