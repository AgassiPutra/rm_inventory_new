import 'package:flutter/material.dart';
import '../widgets/custom_drawer.dart';

class Menu4Page extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('QC Inspection'),
      ),
      drawer: CustomDrawer(),
      body: Center(
        child: Text('Ini halaman Menu 4'),
      ),
    );
  }
}
