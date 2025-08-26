import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Auth {
  /// Cek apakah user sudah login.
  /// Jika belum, redirect ke halaman /login
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
