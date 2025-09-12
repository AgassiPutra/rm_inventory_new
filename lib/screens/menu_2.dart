import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:rm_inventory_new/screens/incomingdetailpage.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/custom_drawer.dart';
import '../utils/auth.dart';

class Menu2Page extends StatefulWidget {
  @override
  _Menu2PageState createState() => _Menu2PageState();
}

class _Menu2PageState extends State<Menu2Page> {
  final fakturController = TextEditingController();
  final unitController = TextEditingController();
  final typeController = TextEditingController();
  final supplierController = TextEditingController();

  List<Map<String, dynamic>> data = [];
  late List<Map<String, dynamic>> filteredData = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchIncomingRM();
    filteredData = List.from(data);
    Auth.check(context);
  }

  @override
  void dispose() {
    fakturController.dispose();
    unitController.dispose();
    typeController.dispose();
    supplierController.dispose();
    super.dispose();
  }

  void applyFilter() {
    final faktur = fakturController.text.trim().toLowerCase();
    final unit = unitController.text.trim().toLowerCase();
    final type = typeController.text.trim().toLowerCase();
    final supplier = supplierController.text.trim().toLowerCase();

    setState(() {
      filteredData = data.where((row) {
        final fakturMatch =
            faktur.isEmpty || row['faktur']!.toLowerCase().contains(faktur);
        final unitMatch =
            unit.isEmpty || row['unit']!.toLowerCase().contains(unit);
        final typeMatch =
            type.isEmpty || row['jenis_rm']!.toLowerCase().contains(type);
        final supplierMatch =
            supplier.isEmpty ||
            row['supplier']!.toLowerCase().contains(supplier);

        return fakturMatch && unitMatch && typeMatch && supplierMatch;
      }).toList();
    });
  }

  void clearFilter() {
    fakturController.clear();
    unitController.clear();
    typeController.clear();
    supplierController.clear();

    setState(() {
      filteredData = List.from(data);
    });
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> fetchIncomingRM() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('https://api-gts-rm.miegacoan.id/gtsrm/api/incoming-rm'),
        headers: {'Authorization': 'Bearer $token'},
      );

      // print('Status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        print('FULL RESPONSE: $jsonData');

        final List<dynamic> items = jsonData['data'];

        setState(() {
          data = items
              .map<Map<String, dynamic>>((item) => item as Map<String, dynamic>)
              .toList();
          applyFilter();
        });
      } else {
        setState(() {
          errorMessage = 'Gagal memuat data: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Terjadi kesalahan: $e';
      });
    }

    setState(() {
      isLoading = false;
    });
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Filter Data'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: fakturController,
                decoration: InputDecoration(
                  labelText: 'Faktur',
                  prefixIcon: Icon(Icons.receipt),
                ),
              ),
              TextField(
                controller: unitController,
                decoration: InputDecoration(
                  labelText: 'Unit',
                  prefixIcon: Icon(Icons.home_work_outlined),
                ),
              ),
              TextField(
                controller: typeController,
                decoration: InputDecoration(
                  labelText: 'Jenis RM',
                  prefixIcon: Icon(Icons.category),
                ),
              ),
              TextField(
                controller: supplierController,
                decoration: InputDecoration(
                  labelText: 'Supplier',
                  prefixIcon: Icon(Icons.local_shipping),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              clearFilter();
              Navigator.pop(context);
            },
            child: Text('Clear'),
          ),
          ElevatedButton(
            onPressed: () {
              applyFilter();
              Navigator.pop(context);
            },
            child: Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> rowData) {
    fakturController.text = rowData['faktur'] ?? '';
    unitController.text = rowData['unit'] ?? '';
    typeController.text = rowData['jenis_rm'] ?? '';
    supplierController.text = rowData['supplier'] ?? '';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Edit Data'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: fakturController,
                decoration: InputDecoration(labelText: 'Faktur'),
              ),
              TextField(
                controller: unitController,
                decoration: InputDecoration(labelText: 'Unit'),
              ),
              TextField(
                controller: typeController,
                decoration: InputDecoration(labelText: 'Jenis RM'),
              ),
              TextField(
                controller: supplierController,
                decoration: InputDecoration(labelText: 'Supplier'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                rowData['faktur'] = fakturController.text;
                rowData['unit'] = unitController.text;
                rowData['jenis_rm'] = typeController.text;
                rowData['supplier'] = supplierController.text;
                applyFilter();
              });
              Navigator.pop(context);
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Incoming Raw Materials'),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_alt_outlined),
            onPressed: () {
              _showFilterDialog();
            },
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              clearFilter();
            },
          ),
          IconButton(icon: Icon(Icons.person), onPressed: () {}),
        ],
      ),
      drawer: CustomDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: isLoading
                      ? Center(child: CircularProgressIndicator())
                      : DataTable(
                          headingRowColor: MaterialStateProperty.all(
                            Colors.blue[50],
                          ),
                          columnSpacing: 24,
                          columns: [
                            DataColumn(label: Text('Faktur')),
                            DataColumn(label: Text('Unit')),
                            DataColumn(label: Text('Jenis RM')),
                            DataColumn(label: Text('Supplier')),
                            DataColumn(label: Text('Action')),
                          ],
                          rows: filteredData.map((row) {
                            return DataRow(
                              cells: [
                                DataCell(Text(row['faktur'] ?? '')),
                                DataCell(Text(row['unit'] ?? '')),
                                DataCell(Text(row['jenis_rm'] ?? '')),
                                DataCell(Text(row['supplier'] ?? '')),
                                DataCell(
                                  IconButton(
                                    icon: Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              IncomingDetailPage(data: row),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
