import 'dart:io';
import 'package:flutter/material.dart';
import 'package:rm_inventory_new/core/network/http_override.dart';
import 'package:rm_inventory_new/shared/data/local/hive_service.dart';
import 'package:rm_inventory_new/features/sync/data/services/sync_service.dart';
import 'package:rm_inventory_new/app/routes/app_routes.dart';

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
      initialRoute: AppRoutes.splash,
      routes: AppRoutes.routes,
    );
  }
}
