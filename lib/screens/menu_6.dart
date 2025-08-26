import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/custom_drawer.dart';

class Menu6Page extends StatefulWidget {
  @override
  _Menu6PageState createState() => _Menu6PageState();
}

class _Menu6PageState extends State<Menu6Page> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Master')),
      drawer: CustomDrawer(),
      body: const Center(child: Text('Ini halaman Menu 6')),
    );
  }
}
