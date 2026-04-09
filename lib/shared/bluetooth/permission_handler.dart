import 'dart:io' show Platform;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class PermissionHelper {
  static Future<bool> requestBluetoothPermissions() async {
    if (kIsWeb) {
      return true;
    }

    if (Platform.isAndroid) {
      var scanStatus = await Permission.bluetoothScan.request();
      if (!scanStatus.isGranted) return false;

      var connectStatus = await Permission.bluetoothConnect.request();
      if (!connectStatus.isGranted) return false;

      var advertiseStatus = await Permission.bluetoothAdvertise.request();
      if (!advertiseStatus.isGranted) return false;
      var locationStatus = await Permission.locationWhenInUse.request();
      if (!locationStatus.isGranted) return false;

      return true;
    }

    if (Platform.isIOS) {
      var locationStatus = await Permission.locationWhenInUse.request();
      if (!locationStatus.isGranted) return false;
      return true;
    }
    return true;
  }
}
