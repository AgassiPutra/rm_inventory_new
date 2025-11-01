import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'db/hive_service.dart';
import 'services/sync_service.dart';
import 'screens/login.dart';
import 'screens/dashboard.dart';
import 'screens/menu_1.dart';
import 'screens/menu_2.dart';
import 'screens/menu_3.dart';
import 'screens/menu_4.dart';
import 'screens/menu_5.dart';
import 'screens/menu_6.dart';
import 'screens/splash.dart';
import 'screens/incoming_material.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();
  try {
    await HiveService.initialize();
    debugPrint('Hive Database berhasil diinisialisasi.');
  } catch (e) {
    debugPrint('ERROR: Gagal inisialisasi Hive: $e');
  }
  SyncService.instance.startListening();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RM Inventory',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => SplashScreen(),
        '/login': (context) => LoginPage(),
        '/dashboard': (context) => DashboardPage(),
        '/incoming-material': (context) => Menu1Page(),
        '/menu2': (context) => Menu2Page(),
        '/menu3': (context) => Menu3Page(),
        // '/incoming-management': (context) => IncomingManagementPage(),
        // '/master-supplier': (context) => MasterSupplierPage(),
        // '/menu6': (context) => Menu6Page(),
      },
    );
  }
}
