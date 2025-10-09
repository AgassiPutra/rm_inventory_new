import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<String?> getToken() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('auth_token');
}

Future<void> clearToken() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('auth_token');
}

class CustomDrawer extends StatefulWidget {
  const CustomDrawer({super.key});

  @override
  State<CustomDrawer> createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  String nama = '';
  String posisi = '';
  String unit = '';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      nama = prefs.getString('nama') ?? '';
      posisi = prefs.getString('posisi') ?? '';
      unit = prefs.getString('jenis_unit') ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
      ),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 140, 5, 161),
            ),
            currentAccountPicture: CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white,
              child: Text(
                nama.isNotEmpty ? nama[0] : 'A',
                style: const TextStyle(
                  color: Colors.purple,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            accountName: Text(
              nama.isNotEmpty ? nama : 'AdminCK2',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            accountEmail: Text(
              ((posisi.isNotEmpty ? posisi : 'Posisi') +
                  '\n' +
                  (unit.isNotEmpty ? unit : 'Unit')),
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          drawerItem(context, 'Dashboard', '/dashboard'),
          drawerItem(context, 'RM Incoming', '/menu1'),
          drawerItem(context, 'RM Incoming Dashboard', '/menu2'),
          drawerItem(context, 'Master Supplier', '/menu3'),
          drawerItem(context, 'QC Inspection', '/menu4'),
          drawerItem(context, 'Batching', '/menu5'),
          drawerItem(context, 'Master', '/menu6'),
          const Divider(),
          ListTile(
            title: const Text(
              'Versi 0.2.6',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }

  ListTile drawerItem(BuildContext context, String title, String routeName) {
    return ListTile(
      title: Text(title),
      onTap: () {
        Navigator.pushReplacementNamed(context, routeName);
      },
    );
  }
}
