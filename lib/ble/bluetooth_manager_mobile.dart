import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'bluetooth_manager.dart';

class BluetoothManagerMobile implements BluetoothManager {
  List<BluetoothDevice> _devices = [];
  StreamController<String> _weightController = StreamController.broadcast();
  StreamSubscription? _notificationSub;
  String _status = 'Idle';

  @override
  void dispose() {
    _notificationSub?.cancel();
    _weightController.close();
  }

  @override
  List<BluetoothDevice> get foundDevices => _devices;

  @override
  String get status => _status;

  @override
  Stream<String> get weightStream => _weightController.stream;

  @override
  Future<void> scanForDevices() async {
    _devices.clear();
    _status = "Scanning...";
    final subscription = FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        if (!_devices.any((d) => d.id == r.device.id)) {
          _devices.add(r.device);
        }
      }
    });

    await FlutterBluePlus.startScan(timeout: Duration(seconds: 5));
    await subscription.cancel();

    _status = _devices.isEmpty ? "No devices found" : "Devices found";
  }

  @override
  Future<void> connectToDevice(dynamic device) async {
    if (device is! BluetoothDevice) return;

    try {
      await device.connect(timeout: Duration(seconds: 10));
      _status = "Connected to ${device.name}";

      var services = await device.discoverServices();
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.notify) {
            await characteristic.setNotifyValue(true);
            _notificationSub = characteristic.value.listen((value) {
              final weight = String.fromCharCodes(value).trim();
              _weightController.add(weight);
            });
          }
        }
      }
    } catch (e) {
      _status = "Connection failed: $e";
    }
  }
}

BluetoothManager BluetoothManagerImpl() => BluetoothManagerMobile();
