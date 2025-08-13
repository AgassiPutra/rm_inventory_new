import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:rm_inventory_new/screens/login.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/custom_drawer.dart';

class Menu3Page extends StatefulWidget {
  @override
  State<Menu3Page> createState() => _Menu3PageState();
}

class _Menu3PageState extends State<Menu3Page> {
  List<dynamic> suppliers = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchSuppliers();
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> fetchSuppliers() async {
    setState(() {
      isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = await getToken() ?? '';

    if (token.isEmpty) {
      await prefs.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Token tidak ditemukan, silakan login ulang')),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => LoginPage()),
          (route) => false,
        );
      }
      setState(() {
        isLoading = false;
      });
      return;
    }

    final response = await http.get(
      Uri.parse('https://trial-api-gts-rm.scm-ppa.com/gtsrm/api/supplier'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonResponse = json.decode(response.body);
      setState(() {
        suppliers = jsonResponse['data'] ?? [];
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal memuat data supplier')));
    }
  }

  Future<void> showSupplierForm({Map<String, dynamic>? data}) async {
    final TextEditingController supplierController = TextEditingController(
      text: data?['supplier'] ?? '',
    );
    final TextEditingController pabrikController = TextEditingController(
      text: data?['nama_pabrik'] ?? '',
    );
    final TextEditingController jenisController = TextEditingController(
      text: data?['jenis_rm'] ?? '',
    );

    bool isEdit = data != null;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEdit ? 'Edit Supplier' : 'Tambah Supplier'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: supplierController,
              decoration: InputDecoration(labelText: 'Supplier'),
            ),
            TextField(
              controller: pabrikController,
              decoration: InputDecoration(labelText: 'Produsen'),
            ),
            TextField(
              controller: jenisController,
              decoration: InputDecoration(labelText: 'Jenis RM'),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: Text('Batal'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: Text('Simpan'),
            onPressed: () async {
              final token = await getToken() ?? '';
              if (token.isEmpty) return;

              final body = {
                'supplier': supplierController.text,
                'nama_pabrik': pabrikController.text,
                'jenis_rm': jenisController.text,
              };

              http.Response res;
              if (isEdit) {
                res = await http.put(
                  Uri.parse(
                    'https://trial-api-gts-rm.scm-ppa.com/gtsrm/api/supplier/${data!['id']}',
                  ),
                  headers: {
                    'Authorization': 'Bearer $token',
                    'Accept': 'application/json',
                    'Content-Type': 'application/json',
                  },
                  body: jsonEncode(body),
                );
              } else {
                res = await http.post(
                  Uri.parse(
                    'https://trial-api-gts-rm.scm-ppa.com/gtsrm/api/supplier',
                  ),
                  headers: {
                    'Authorization': 'Bearer $token',
                    'Accept': 'application/json',
                    'Content-Type': 'application/json',
                  },
                  body: jsonEncode(body),
                );
              }

              if (res.statusCode == 200 || res.statusCode == 201) {
                Navigator.pop(context);
                fetchSuppliers();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isEdit
                          ? 'Data berhasil diubah'
                          : 'Data berhasil ditambahkan',
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Gagal menyimpan data')));
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Suppliers'),
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: fetchSuppliers),
        ],
      ),
      drawer: CustomDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: isLoading
            ? Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth,
                        ),
                        child: DataTable(
                          columnSpacing: 24,
                          headingRowColor: MaterialStateProperty.all(
                            Colors.grey[100],
                          ),
                          columns: [
                            DataColumn(label: Text('Supplier')),
                            DataColumn(label: Text('Produsen')),
                            DataColumn(label: Text('Jenis')),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: suppliers.map((data) {
                            return DataRow(
                              cells: [
                                DataCell(Text(data['supplier'] ?? '')),
                                DataCell(Text(data['nama_pabrik'] ?? '')),
                                DataCell(Text(data['jenis_rm'] ?? '')),
                                DataCell(
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.edit, size: 18),
                                        onPressed: () {
                                          showSupplierForm(data: data);
                                        },
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.delete,
                                          size: 18,
                                          color: Colors.red,
                                        ),
                                        onPressed: () {},
                                      ),
                                    ],
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.purple[100],
        child: Icon(Icons.add, color: Colors.purple),
        onPressed: () {
          showSupplierForm();
        },
      ),
    );
  }
}
