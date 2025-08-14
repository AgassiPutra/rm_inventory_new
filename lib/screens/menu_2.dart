import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/custom_drawer.dart';

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
            type.isEmpty || row['type']!.toLowerCase().contains(type);
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
        Uri.parse('https://trial-api-gts-rm.scm-ppa.com/gtsrm/api/incoming-rm'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final List<dynamic> items = jsonData['data'];

        setState(() {
          data = items.map((item) {
            return {
              'faktur': item['faktur'] ?? '',
              'unit': item['unit'] ?? '',
              'type': item['jenis_rm'] ?? '',
              'supplier': item['supplier'] ?? '',
              'date': item['tanggal_incoming'] ?? '',
            };
          }).toList();

          // Segera terapkan filter jika diperlukan
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

  @override
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
                            DataColumn(label: Text('Type')),
                            DataColumn(label: Text('Supplier')),
                            DataColumn(label: Text('Date')),
                          ],
                          rows: filteredData.map((row) {
                            return DataRow(
                              cells: [
                                DataCell(Text(row['faktur'] ?? '')),
                                DataCell(Text(row['unit'] ?? '')),
                                DataCell(Text(row['type'] ?? '')),
                                DataCell(Text(row['supplier'] ?? '')),
                                DataCell(Text(row['date'] ?? '')),
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
                  labelText: 'Type',
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
}
