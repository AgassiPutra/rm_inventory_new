import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'bluetooth_manager_mobile.dart' as mobile;
import 'bluetooth_manager_web.dart' as web;

import 'bluetooth_manager.dart';

BluetoothManager createBluetoothManager() {
  if (kIsWeb) {
    return web.BluetoothManagerImpl();
  } else if (Platform.isAndroid || Platform.isIOS) {
    return mobile.BluetoothManagerImpl();
  } else {
    throw UnsupportedError("Unsupported platform for BluetoothManager");
  }
}
