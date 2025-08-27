import 'dart:async';
import 'dart:typed_data';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:html' as html;

abstract class BluetoothManager {
  Future<void> scanForDevices();
  Future<void> connectToDevice(dynamic device);
  Stream<String> get weightStream;
  List<dynamic> get foundDevices;
  String get status;
  void dispose();
}

class BluetoothManagerImpl implements BluetoothManager {
  final List<dynamic> _foundDevices = [];
  final _weightController = StreamController<String>.broadcast();
  final bluetooth = js_util.getProperty(html.window.navigator, 'bluetooth');

  Stream<String> get weightStream => _weightController.stream;

  List<dynamic> get foundDevices => _foundDevices;

  String _status = 'Idle';
  String get status => _status;

  dynamic _device;
  dynamic _server;
  dynamic _characteristic;
  html.EventListener? _notificationListener;

  @override
  Future<void> scanForDevices() async {
    _status = 'Requesting device...';
    try {
      final bluetooth = js_util.getProperty(html.window.navigator, 'bluetooth');

      final device = await js_util.promiseToFuture(
        js_util.callMethod(bluetooth, 'requestDevice', [
          js_util.jsify({
            'filters': [
              {
                'services': ['battery_service'],
              },
            ],
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
      _status = 'Error during device request: $e';
    }
  }

  @override
  Future<void> connectToDevice(dynamic device) async {
    if (device == null) {
      _status = "No device to connect";
      return;
    }

    _status = "Connecting to device...";
    try {
      _server = await js_util.promiseToFuture(
        js_util.callMethod(device, 'gatt.connect', []),
      );
      _characteristic = null;
      final service = await js_util.promiseToFuture(
        js_util.callMethod(_server, 'getPrimaryService', ['battery_service']),
      );
      _characteristic = await js_util.promiseToFuture(
        js_util.callMethod(service, 'getCharacteristic', ['battery_level']),
      );

      await startNotifications(_characteristic);

      _status = "Connected to device and notifications started";
    } catch (e) {
      _status = "Connection failed: $e";
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
  void dispose() {
    if (_characteristic != null) {
      stopNotifications(_characteristic);
    }
    _weightController.close();
  }
}
