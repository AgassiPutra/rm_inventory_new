import 'package:flutter/material.dart';
import '../widgets/custom_drawer.dart';

class Menu5Page extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Batching'),
      ),
      drawer: CustomDrawer(),
      body: Center(
        child: Text('Ini halaman Menu 5'),
      ),
    );
  }
}
