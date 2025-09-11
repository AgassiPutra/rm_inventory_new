import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Auth {
  static Future<void> check(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null || token.isEmpty) {
      Future.microtask(() {
        Navigator.pushReplacementNamed(context, '/login');
      });
    }
  }
}
