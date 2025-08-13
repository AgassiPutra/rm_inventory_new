import 'package:flutter/material.dart';
import '../widgets/custom_drawer.dart';

class Menu6Page extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Master'),
      ),
      drawer: CustomDrawer(),
      body: Center(
        child: Text('Ini halaman Menu 6'),
      ),
    );
  }
}
