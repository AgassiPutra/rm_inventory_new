import 'dart:io';
import 'package:flutter/material.dart';
import 'screens/login.dart';
import 'screens/dashboard.dart';
import 'screens/menu_1.dart';
import 'screens/menu_2.dart';
import 'screens/menu_3.dart';
import 'screens/menu_4.dart';
import 'screens/menu_5.dart';
import 'screens/menu_6.dart';
import 'screens/splash.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() {
  HttpOverrides.global = MyHttpOverrides();
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
        '/menu1': (context) => Menu1Page(),
        '/menu2': (context) => Menu2Page(),
        '/menu3': (context) => Menu3Page(),
        '/menu4': (context) => Menu4Page(),
        '/menu5': (context) => Menu5Page(),
        '/menu6': (context) => Menu6Page(),
      },
    );
  }
}
