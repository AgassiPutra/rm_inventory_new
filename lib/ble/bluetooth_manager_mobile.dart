import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'bluetooth_manager.dart';
import '../models/app_bluetooth_device.dart';

class BluetoothManagerMobile implements BluetoothManager {
  final List<AppBluetoothDevice> _devices = [];
  final StreamController<String> _weightController =
      StreamController.broadcast();

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<List<int>>? _notificationSub;

  String _status = 'Idle';
  BluetoothDevice? _device;

  @override
  void dispose() {
    _scanSub?.cancel();
    _notificationSub?.cancel();
    _weightController.close();
  }

  @override
  List<AppBluetoothDevice> get foundDevices => _devices;

  @override
  String get status => _status;

  @override
  Stream<String> get weightStream => _weightController.stream;

  @override
  Future<void> scanForDevices() async {
    _devices.clear();
    _status = "Scanning...";

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        if (!_devices.any((d) => d.id == r.device.id.id)) {
          _devices.add(
            AppBluetoothDevice(
              id: r.device.id.id,
              name: r.device.name.isNotEmpty ? r.device.name : "Unnamed",
              nativeDevice: r.device,
            ),
          );
        }
      }
    });

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
    await _scanSub?.cancel();

    _status = _devices.isEmpty ? "No scales found" : "Device(s) found";
  }

  @override
  Future<void> connectToDevice(dynamic device) async {
    if (device is! AppBluetoothDevice) return;

    final native = device.nativeDevice as BluetoothDevice;
    _device = native;

    try {
      await native.connect(timeout: const Duration(seconds: 10));
      _status = "Connected to ${device.name}";

      var services = await native.discoverServices();
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.notify) {
            await characteristic.setNotifyValue(true);
            _notificationSub = characteristic.value.listen((value) {
              final weightData = String.fromCharCodes(value).trim();
              try {
                final weight = double.parse(weightData);
                _weightController.add(weight.toStringAsFixed(2));
              } catch (e) {
                _weightController.add(weightData);
              }
            });
          }
        }
      }
    } catch (e) {
      if (e.toString().contains("already connected")) {
        _status = "Already connected to ${device.name}";
      } else {
        _status = "Connection failed: $e";
      }
    }
  }

  @override
  Future<void> disconnect() async {
    if (_device != null) {
      try {
        await _device?.disconnect();
        _status = "Disconnected from ${_device?.name}";
      } catch (e) {
        _status = "Disconnection failed: $e";
      }
    }
  }
}

BluetoothManager BluetoothManagerImpl() => BluetoothManagerMobile();
