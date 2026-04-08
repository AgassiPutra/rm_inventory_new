import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:http/http.dart' as http;

class Auth {
  static Future<void> check(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null || token.isEmpty) {
      Future.microtask(() {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      });
    }
  }

  static Future<void> logout(BuildContext context) async {
    await clearSession();

    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  static Future<bool> handle401(
    BuildContext context,
    http.Response response,
  ) async {
    if (response.statusCode == 401) {
      await logout(context);
      return true;
    }
    return false;
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('email');
    await prefs.remove('unit');
    await prefs.remove('jenis_unit');
    await prefs.remove('posisi');
  }
}
