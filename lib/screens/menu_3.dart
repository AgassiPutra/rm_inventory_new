import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/custom_drawer.dart';
import 'login.dart';

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
    return prefs.getString('auth_token');
  }

  Future<void> fetchSuppliers() async {
    setState(() => isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final token = await getToken() ?? '';

    if (token.isEmpty) {
      await prefs.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Token tidak ditemukan, silakan login ulang'),
        ),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
      setState(() => isLoading = false);
      return;
    }

    try {
      final res = await http.get(
        Uri.parse('https://trial-api-gts-rm.scm-ppa.com/gtsrm/api/supplier'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (res.statusCode == 200) {
        final jsonRes = json.decode(res.body) as Map<String, dynamic>;
        setState(() {
          suppliers = (jsonRes['data'] ?? []) as List<dynamic>;
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat data supplier (${res.statusCode})'),
          ),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _openAddSupplier() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddSupplierPage()),
    );
    if (created == true) {
      fetchSuppliers();
    }
  }

  Future<void> showSupplierForm({Map<String, dynamic>? data}) async {
    final kodeSupplierC = TextEditingController(
      text: data?['kode_supplier'] ?? '',
    );
    final supplierC = TextEditingController(text: data?['supplier'] ?? '');
    final pabrikC = TextEditingController(text: data?['nama_pabrik'] ?? '');
    String? jenisRm = data?['jenis_rm'] as String?;
    String? jenisAyam = data?['jenis_ayam'] as String?;
    String? satuan = data?['satuan'] as String?;
    const jenisRmOptions = ['Wet Chicken', 'Dry', 'Sayuran', 'Ice'];
    const jenisAyamOptions = ['Fresh Wet Chicken', 'Frozen Chicken', 'Other'];
    const satuanOptions = ['Kg', 'Karton', 'Bak', 'Pack', 'Jerrycan'];

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setStateSB) {
          return AlertDialog(
            title: const Text('Edit Supplier'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Jenis RM
                    DropdownButtonFormField<String>(
                      value: jenisRm,
                      items: jenisRmOptions
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (v) {
                        setStateSB(() {
                          jenisRm = v;
                          if (jenisRm != 'Wet Chicken') jenisAyam = null;
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'Jenis RM',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Pilih jenis RM' : null,
                    ),
                    const SizedBox(height: 12),
                    if (jenisRm == 'Wet Chicken') ...[
                      DropdownButtonFormField<String>(
                        value: jenisAyam,
                        items: jenisAyamOptions
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                        onChanged: (v) => setStateSB(() => jenisAyam = v),
                        decoration: const InputDecoration(
                          labelText: 'Jenis Ayam',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            (jenisRm == 'Wet Chicken' &&
                                (v == null || v.isEmpty))
                            ? 'Pilih jenis ayam'
                            : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: supplierC,
                      decoration: const InputDecoration(
                        labelText: 'Supplier',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Wajib diisi'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: pabrikC,
                      decoration: const InputDecoration(
                        labelText: 'Produsen',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Wajib diisi'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: satuan,
                      items: satuanOptions
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (v) => setStateSB(() => satuan = v),
                      decoration: const InputDecoration(
                        labelText: 'Satuan',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Pilih satuan' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: kodeSupplierC,
                      decoration: const InputDecoration(
                        labelText: 'Kode Supplier',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Wajib diisi'
                          : null,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                child: const Text('Batal'),
                onPressed: () => Navigator.pop(context),
              ),
              ElevatedButton(
                child: const Text('Simpan'),
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;

                  final token = await getToken() ?? '';
                  if (token.isEmpty) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Token tidak ditemukan. Silakan login ulang.',
                        ),
                      ),
                    );
                    return;
                  }

                  final body = {
                    'kode_supplier': kodeSupplierC.text.trim(),
                    'supplier': supplierC.text.trim(),
                    'nama_pabrik': pabrikC.text.trim(),
                    'satuan': satuan ?? 'Kg',
                    'jenis_rm': jenisRm ?? '',
                    'jenis_ayam': (jenisRm == 'Wet Chicken')
                        ? (jenisAyam ?? '')
                        : '',
                  };

                  try {
                    final res = await http.put(
                      Uri.parse(
                        'https://trial-api-gts-rm.scm-ppa.com/gtsrm/api/supplier?KodeSupplier=${kodeSupplierC.text.trim()}',
                      ),

                      headers: {
                        'Authorization': 'Bearer $token',
                        'Accept': 'application/json',
                        'Content-Type': 'application/json',
                      },
                      body: jsonEncode(body),
                    );

                    if (!mounted) return;
                    if (res.statusCode == 200 || res.statusCode == 201) {
                      Navigator.pop(context);
                      fetchSuppliers();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Data berhasil diubah')),
                      );
                    } else {
                      String msg = 'Gagal menyimpan data (${res.statusCode})';
                      try {
                        final m = jsonDecode(res.body);
                        if (m is Map && m['message'] is String) {
                          msg = '${m['message']} (${res.statusCode})';
                        }
                      } catch (_) {}
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(msg)));
                    }
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> deleteSupplier(BuildContext context, String kodeSupplier) async {
    final url = Uri.parse(
      'https://trial-api-gts-rm.scm-ppa.com/gtsrm/api/supplier?KodeSupplier=$kodeSupplier',
    );
    final token = await getToken();

    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Token tidak ditemukan. Silakan login ulang.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      Navigator.of(context, rootNavigator: true).pop();

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Supplier berhasil dihapus'),
            backgroundColor: Colors.green,
          ),
        );
        fetchSuppliers(); // refresh data
      } else {
        print('Status Code: ${response.statusCode}');
        print('Response Body: ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghapus: ${response.body}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suppliers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchSuppliers,
          ),
        ],
      ),
      drawer: const CustomDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
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
                          columns: const [
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
                                        icon: const Icon(Icons.edit, size: 18),
                                        onPressed: () =>
                                            showSupplierForm(data: data),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          size: 18,
                                          color: Colors.red,
                                        ),
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text('Konfirmasi'),
                                              content: const Text(
                                                'Yakin ingin menghapus supplier ini?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  child: const Text('Batal'),
                                                  onPressed: () =>
                                                      Navigator.of(ctx).pop(),
                                                ),
                                                TextButton(
                                                  child: const Text('Hapus'),
                                                  onPressed: () {
                                                    deleteSupplier(
                                                      context,
                                                      data['kode_supplier'],
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                          );
                                        },
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
        child: const Icon(Icons.add, color: Colors.purple),
        onPressed: _openAddSupplier,
      ),
    );
  }
}

class AddSupplierPage extends StatefulWidget {
  const AddSupplierPage({super.key});

  @override
  State<AddSupplierPage> createState() => _AddSupplierPageState();
}

class _AddSupplierPageState extends State<AddSupplierPage> {
  final _formKey = GlobalKey<FormState>();

  // field controllers
  final TextEditingController _kodeSupplierC = TextEditingController();
  final TextEditingController _supplierC = TextEditingController();
  final TextEditingController _pabrikC = TextEditingController();

  // dropdown values
  String? _jenisRm; // contoh: "Wet Chicken"
  String? _satuan; // contoh: "Kg"
  String? _jenisAyam; // contoh: "Fresh Wet Chicken"

  final List<String> jenisRmOptions = const [
    'Wet Chicken',
    'Dry',
    'Sayuran',
    'Ice',
  ];

  final List<String> satuanOptions = const [
    'Kg',
    'Karton',
    'Bak',
    'Pack',
    'Jerrycan',
  ];

  final List<String> jenisAyamOptions = const [
    'Fresh Wet Chicken',
    'Frozen Chicken',
    'Other',
  ];

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final token = await _getToken() ?? '';
    if (token.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Token tidak ditemukan. Silakan login ulang.'),
        ),
      );
      return;
    }

    final body = {
      "kode_supplier": _kodeSupplierC.text.trim(),
      "supplier": _supplierC.text.trim(),
      "nama_pabrik": _pabrikC.text.trim(),
      "satuan": _satuan ?? "Kg",
      "jenis_rm": _jenisRm ?? "",
      "jenis_ayam": _jenisAyam ?? "",
    };

    try {
      final res = await http.post(
        Uri.parse('https://trial-api-gts-rm.scm-ppa.com/gtsrm/api/supplier'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (!mounted) return;
      if (res.statusCode == 200 || res.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Supplier berhasil dibuat')),
        );
        Navigator.pop(context, true); // -> kembali & trigger refresh
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuat supplier (${res.statusCode})')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  void dispose() {
    _kodeSupplierC.dispose();
    _supplierC.dispose();
    _pabrikC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Supplier'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Jenis RM
              DropdownButtonFormField<String>(
                value: _jenisRm,
                items: jenisRmOptions
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => _jenisRm = v),
                decoration: const InputDecoration(
                  labelText: 'Jenis RM',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Pilih jenis RM' : null,
              ),
              const SizedBox(height: 12),

              // Jenis Ayam (jika Wet Chicken)
              if (_jenisRm == 'Wet Chicken') ...[
                DropdownButtonFormField<String>(
                  value: _jenisAyam,
                  items: jenisAyamOptions
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _jenisAyam = v),
                  decoration: const InputDecoration(
                    labelText: 'Jenis Ayam',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Pilih jenis ayam' : null,
                ),
                const SizedBox(height: 12),
              ],

              // Supplier
              TextFormField(
                controller: _supplierC,
                decoration: const InputDecoration(
                  labelText: 'Supplier',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),

              // Produsen
              TextFormField(
                controller: _pabrikC,
                decoration: const InputDecoration(
                  labelText: 'Produsen',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),

              // Satuan
              DropdownButtonFormField<String>(
                value: _satuan,
                items: satuanOptions
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => _satuan = v),
                decoration: const InputDecoration(
                  labelText: 'Satuan',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Pilih satuan' : null,
              ),
              const SizedBox(height: 12),

              // Kode Supplier
              TextFormField(
                controller: _kodeSupplierC,
                decoration: const InputDecoration(
                  labelText: 'Kode Supplier',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 24),

              // Button submit
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple[50],
                    foregroundColor: Colors.purple[700],
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Create Supplier'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
