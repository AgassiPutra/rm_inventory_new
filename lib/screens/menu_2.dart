import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:rm_inventory_new/screens/incomingdetailpage.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/custom_drawer.dart';
import '../utils/auth.dart';
import 'package:intl/intl.dart';

class Menu2Page extends StatefulWidget {
  @override
  _Menu2PageState createState() => _Menu2PageState();
}

class _Menu2PageState extends State<Menu2Page> {
  final fakturController = TextEditingController();
  final unitController = TextEditingController();
  final typeController = TextEditingController();
  final supplierController = TextEditingController();
  final tanggalAwalController = TextEditingController();
  final tanggalAkhirController = TextEditingController();
  final DateTime today = DateTime.now();

  List<Map<String, dynamic>> data = [];
  late List<Map<String, dynamic>> filteredData = [];
  bool isLoading = true;
  String? errorMessage;
  int? _sortColumnIndex;
  bool _sortAscending = true;

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
    tanggalAwalController.dispose();
    tanggalAkhirController.dispose();
    super.dispose();
  }

  void _sort<T>(
    Comparable<T> Function(Map<String, dynamic> d) getField,
    int columnIndex,
    bool ascending,
  ) {
    setState(() {
      filteredData.sort((a, b) {
        final aValue = getField(a);
        final bValue = getField(b);
        return ascending
            ? Comparable.compare(aValue, bValue)
            : Comparable.compare(bValue, aValue);
      });
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }

  void applyFilter() {
    final faktur = fakturController.text.trim().toLowerCase();
    final unit = unitController.text.trim().toLowerCase();
    final type = typeController.text.trim().toLowerCase();
    final supplier = supplierController.text.trim().toLowerCase();
    final tanggalAwal = tanggalAwalController.text;
    final tanggalAkhir = tanggalAkhirController.text;

    setState(() {
      filteredData = data.where((row) {
        final fakturMatch =
            faktur.isEmpty ||
            (row['faktur'] ?? '').toLowerCase().contains(faktur);
        final unitMatch =
            unit.isEmpty || (row['unit'] ?? '').toLowerCase().contains(unit);
        final typeMatch =
            type.isEmpty ||
            (row['jenis_rm'] ?? '').toLowerCase().contains(type);
        final supplierMatch =
            supplier.isEmpty ||
            (row['supplier'] ?? '').toLowerCase().contains(supplier);

        bool tanggalMatch = true;
        final tanggalIncoming = row['tanggal_incoming'] ?? '';
        if (tanggalAwal.isNotEmpty &&
            tanggalAkhir.isNotEmpty &&
            tanggalIncoming.isNotEmpty) {
          tanggalMatch =
              tanggalIncoming.compareTo(tanggalAwal) >= 0 &&
              tanggalIncoming.compareTo(tanggalAkhir) <= 0;
        } else if (tanggalAwal.isNotEmpty && tanggalIncoming.isNotEmpty) {
          tanggalMatch = tanggalIncoming.compareTo(tanggalAwal) >= 0;
        } else if (tanggalAkhir.isNotEmpty && tanggalIncoming.isNotEmpty) {
          tanggalMatch = tanggalIncoming.compareTo(tanggalAkhir) <= 0;
        }

        return fakturMatch &&
            unitMatch &&
            typeMatch &&
            supplierMatch &&
            tanggalMatch;
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
      print('Token: $token');

      if (token == null) {
        setState(() {
          errorMessage = 'Token tidak ditemukan. Silakan login ulang.';
          isLoading = false;
        });
        print('Token null, keluar dari fetch');
        return;
      }

      final DateTime today = DateTime.now();
      final DateFormat formatter = DateFormat('yyyy-MM-dd');
      final DateTime firstDayOfMonth = DateTime(today.year, today.month, 1);
      final DateTime tomorrow = today.add(const Duration(days: 1));

      final String tanggalAwal = tanggalAwalController.text.isNotEmpty
          ? tanggalAwalController.text
          : formatter.format(firstDayOfMonth);
      final String tanggalAkhir = tanggalAkhirController.text.isNotEmpty
          ? tanggalAkhirController.text
          : formatter.format(tomorrow);

      final url =
          'https://api-gts-rm.scm-ppa.com/gtsrm/api/incoming-rm?tanggalAwal=$tanggalAwal&tanggalAkhir=$tanggalAkhir';

      print('Fetching URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );

      print('Status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final List<dynamic> items = jsonData['data'];

        setState(() {
          data = items
              .map<Map<String, dynamic>>((item) => item as Map<String, dynamic>)
              .toList();
          if (data.isEmpty) {
            errorMessage = 'Tidak ada data pengiriman RM pada periode ini.';
          } else {
            errorMessage = null;
          }

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
              GestureDetector(
                onTap: () async {
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    tanggalAwalController.text = picked
                        .toIso8601String()
                        .substring(0, 10);
                  }
                },
                child: AbsorbPointer(
                  child: TextField(
                    controller: tanggalAwalController,
                    decoration: InputDecoration(
                      labelText: 'Tanggal Awal (YYYY-MM-DD)',
                      prefixIcon: Icon(Icons.date_range),
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () async {
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    tanggalAkhirController.text = picked
                        .toIso8601String()
                        .substring(0, 10);
                  }
                },
                child: AbsorbPointer(
                  child: TextField(
                    controller: tanggalAkhirController,
                    decoration: InputDecoration(
                      labelText: 'Tanggal Akhir (YYYY-MM-DD)',
                      prefixIcon: Icon(Icons.date_range),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              clearFilter();
              tanggalAwalController.clear();
              tanggalAkhirController.clear();
              fetchIncomingRM();
              Navigator.pop(context);
            },
            child: Text('Clear'),
          ),
          ElevatedButton(
            onPressed: () {
              fetchIncomingRM();
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
              fetchIncomingRM();
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
                          sortColumnIndex: _sortColumnIndex,
                          sortAscending: _sortAscending,
                          headingRowColor: MaterialStateProperty.all(
                            Colors.blue[50],
                          ),
                          columnSpacing: 24,
                          columns: [
                            DataColumn(
                              label: Text('Faktur'),
                              onSort: (i, asc) =>
                                  _sort((d) => d['faktur'] ?? '', i, asc),
                            ),
                            DataColumn(
                              label: Text('Unit'),
                              onSort: (i, asc) =>
                                  _sort((d) => d['unit'] ?? '', i, asc),
                            ),
                            DataColumn(
                              label: Text('Jenis RM'),
                              onSort: (i, asc) =>
                                  _sort((d) => d['jenis_rm'] ?? '', i, asc),
                            ),
                            DataColumn(
                              label: Text('Supplier'),
                              onSort: (i, asc) =>
                                  _sort((d) => d['supplier'] ?? '', i, asc),
                            ),
                            DataColumn(
                              label: Text('Tanggal'),
                              onSort: (i, asc) => _sort(
                                (d) => d['tanggal_incoming'] ?? '',
                                i,
                                asc,
                              ),
                            ),
                            DataColumn(label: Text('Action')),
                          ],
                          rows: filteredData.map((row) {
                            return DataRow(
                              cells: [
                                DataCell(Text(row['faktur'] ?? '')),
                                DataCell(
                                  (row['unit'] ?? '')
                                          .toString()
                                          .toUpperCase()
                                          .contains('CK')
                                      ? Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.blue[100],
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            row['unit'] ?? '',
                                            style: TextStyle(
                                              color: Colors.blue[900],
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        )
                                      : Text(row['unit'] ?? ''),
                                ),
                                DataCell(Text(row['jenis_rm'] ?? '')),
                                DataCell(Text(row['supplier'] ?? '')),
                                DataCell(Text(row['tanggal_incoming'] ?? '')),
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
