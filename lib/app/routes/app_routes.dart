import 'package:flutter/material.dart';
import 'package:rm_inventory_new/features/auth/presentation/pages/login_page.dart';
import 'package:rm_inventory_new/features/auth/presentation/pages/splash_page.dart';
import 'package:rm_inventory_new/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:rm_inventory_new/features/incoming_material/presentation/pages/incoming_material_page.dart';
import 'package:rm_inventory_new/features/incoming_rm_dashboard/presentation/pages/incoming_rm_dashboard_page.dart';
import 'package:rm_inventory_new/features/supplier/presentation/pages/supplier_page.dart';
import 'package:rm_inventory_new/features/incoming_management/presentation/pages/incoming_management_page.dart';
import 'package:rm_inventory_new/features/batching/presentation/pages/batching_page.dart';
import 'package:rm_inventory_new/features/incoming_material/presentation/pages/add_new_incoming_page.dart';

class AppRoutes {
  static const String splash = '/splash';
  static const String login = '/login';
  static const String dashboard = '/dashboard';
  static const String incomingMaterial = '/incoming-material';
  static const String incomingRawMaterial = '/incoming-raw-material';
  static const String supplier = '/supplier';
  // static const String incomingManagement = '/incoming-management';
  // static const String masterSupplier = '/master-supplier';
  // static const String addNewIncoming = '/add-new-incoming';
  // static const String menu6 = '/menu6';

  static Map<String, WidgetBuilder> get routes => {
    splash: (context) => SplashScreen(),
    login: (context) => const LoginPage(),
    dashboard: (context) => DashboardPage(),
    incomingMaterial: (context) => Menu1Page(),
    incomingRawMaterial: (context) => Menu2Page(),
    supplier: (context) => Menu3Page(),
    // incomingManagement: (context) => IncomingManagementPage(),
    // masterSupplier: (context) => MasterSupplierPage(),
    // addNewIncoming: (context) => const AddNewIncomingPage(),
    // menu6: (context) => Menu6Page(),
  };
}
