import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/custom_drawer.dart';
import 'login.dart';
import '../utils/auth.dart';
import 'package:flutter/material.dart';

class Menu3Page extends StatefulWidget {
  @override
  State<Menu3Page> createState() => _Menu3PageState();
}

class _Menu3PageState extends State<Menu3Page> {
  List<dynamic> allSuppliers = [];
  List<dynamic> filteredSuppliers = [];
  List<dynamic> currentSuppliers = [];
  bool isLoading = true;
  int currentPage = 1;
  int pageSize = 10;
  int totalPages = 1;
  final TextEditingController _searchController = TextEditingController();
  String? _filterJenisRm;

  final List<String> jenisRmOptions = const [
    'WET CHICKEN',
    'DRY',
    'SAYURAN',
    'ICE',
    'UDANG',
  ];

  @override
  void initState() {
    super.initState();
    fetchSuppliers();
    Auth.check(context);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _filterSuppliers();
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> fetchSuppliers() async {
    setState(() {
      isLoading = true;
      currentPage = 1;
    });

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
        Uri.parse('https://api-gts-rm.scm-ppa.com/gtsrm/api/supplier'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (res.statusCode == 200) {
        final jsonRes = json.decode(res.body) as Map<String, dynamic>;

        setState(() {
          allSuppliers = (jsonRes['data'] ?? []) as List<dynamic>;
          isLoading = false;
        });
        _filterSuppliers();
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

  void _filterSuppliers() {
    final query = _searchController.text.toLowerCase().trim();
    final filterRm = _filterJenisRm;
    filteredSuppliers = allSuppliers.where((supplier) {
      final supplierName = (supplier['supplier'] as String? ?? '')
          .toLowerCase();
      final jenisRm = supplier['jenis_rm'] as String? ?? '';
      final matchesQuery = query.isEmpty || supplierName.contains(query);
      final matchesJenisRm =
          filterRm == null || filterRm.isEmpty || jenisRm == filterRm;

      return matchesQuery && matchesJenisRm;
    }).toList();

    totalPages = (filteredSuppliers.length / pageSize).ceil();
    if (totalPages == 0 && filteredSuppliers.isNotEmpty) {
      totalPages = 1;
    } else if (filteredSuppliers.isEmpty) {
      totalPages = 1;
    }

    if (currentPage > totalPages) {
      currentPage = totalPages > 0 ? totalPages : 1;
    }
    _updateCurrentPageData();
    setState(() {});
  }

  void _updateCurrentPageData() {
    final start = (currentPage - 1) * pageSize;
    final end = (start + pageSize).clamp(0, filteredSuppliers.length);
    currentSuppliers = filteredSuppliers.sublist(start, end);
  }

  void _goToPage(int page) {
    if (page < 1 || page > totalPages) return;
    setState(() {
      currentPage = page;
      _updateCurrentPageData();
    });
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
    const jenisRmOptionsLocal = ['WET CHICKEN', 'DRY', 'SAYURAN', 'ICE'];
    const jenisAyamOptions = ['FRESH WET CHICKEN', 'FROZEN CHICKEN', 'OTHER'];
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
                    DropdownButtonFormField<String>(
                      value: jenisRmOptionsLocal.contains(jenisRm)
                          ? jenisRm
                          : null,
                      items: jenisRmOptionsLocal
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (v) {
                        setStateSB(() {
                          jenisRm = v;
                          if (jenisRm != 'WET CHICKEN') jenisAyam = null;
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
                    if (jenisRm == 'WET CHICKEN') ...[
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
                            (jenisRm == 'WET CHICKEN' &&
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
                      value: satuanOptions.contains(satuan) ? satuan : null,
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
                    'jenis_ayam': (jenisRm == 'WET CHICKEN')
                        ? (jenisAyam ?? '')
                        : '',
                  };

                  try {
                    final res = await http.put(
                      Uri.parse(
                        'https://api-gts-rm.scm-ppa.com/gtsrm/api/supplier?kode_supplier=${kodeSupplierC.text.trim()}',
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
      'https://api-gts-rm.scm-ppa.com/gtsrm/api/supplier?kode_supplier=$kodeSupplier',
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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

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
        fetchSuppliers();
      } else {
        String msg = 'Gagal menghapus: (${response.statusCode})';
        try {
          final m = jsonDecode(response.body);
          if (m is Map && m['message'] is String) {
            msg = 'Gagal menghapus: ${m['message']} (${response.statusCode})';
          }
        } catch (_) {
          msg = 'Gagal menghapus: ${response.body} (${response.statusCode})';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
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
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              labelText: 'Cari Supplier...',
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 200,
                          child: DropdownButtonFormField<String>(
                            value: _filterJenisRm,
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('Semua Jenis'),
                              ),
                              ...jenisRmOptions
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(e),
                                    ),
                                  )
                                  .toList(),
                            ],
                            onChanged: (v) {
                              setState(() {
                                _filterJenisRm = v;
                                currentPage = 1;
                              });
                              _filterSuppliers();
                            },
                            decoration: const InputDecoration(
                              labelText: 'Jenis RM',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        if (filteredSuppliers.isEmpty && !isLoading) {
                          return const Center(
                            child: Text(
                              'Tidak ada data supplier yang cocok dengan kriteria.',
                            ),
                          );
                        }
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
                                rows: currentSuppliers.map((data) {
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(data['supplier'] ?? '')),
                                      DataCell(Text(data['nama_pabrik'] ?? '')),
                                      DataCell(Text(data['jenis_rm'] ?? '')),
                                      DataCell(
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                Icons.edit,
                                                size: 18,
                                              ),
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
                                                    title: const Text(
                                                      'Konfirmasi',
                                                    ),
                                                    content: const Text(
                                                      'Yakin ingin menghapus supplier ini?',
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        child: const Text(
                                                          'Batal',
                                                        ),
                                                        onPressed: () =>
                                                            Navigator.of(
                                                              ctx,
                                                            ).pop(),
                                                      ),
                                                      TextButton(
                                                        child: const Text(
                                                          'Hapus',
                                                        ),
                                                        onPressed: () {
                                                          Navigator.of(
                                                            ctx,
                                                          ).pop();
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
                  if (totalPages > 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: currentPage > 1
                                ? () => _goToPage(currentPage - 1)
                                : null,
                          ),
                          ...List.generate(totalPages, (index) {
                            int pageNum = index + 1;
                            if (pageNum == 1 ||
                                pageNum == totalPages ||
                                (pageNum >= currentPage - 2 &&
                                    pageNum <= currentPage + 2)) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4.0,
                                ),
                                child: ChoiceChip(
                                  label: Text('$pageNum'),
                                  selected: pageNum == currentPage,
                                  onSelected: (selected) {
                                    if (selected) {
                                      _goToPage(pageNum);
                                    }
                                  },
                                ),
                              );
                            } else if ((pageNum == currentPage - 3 &&
                                    currentPage > 3) ||
                                (pageNum == currentPage + 3 &&
                                    currentPage < totalPages - 2)) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4.0),
                                child: Text('...'),
                              );
                            }
                            return const SizedBox.shrink();
                          }).where((widget) => widget is! SizedBox).toList(),

                          IconButton(
                            icon: const Icon(Icons.arrow_forward),
                            onPressed: currentPage < totalPages
                                ? () => _goToPage(currentPage + 1)
                                : null,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.purple[100],
        child: const Icon(Icons.add, color: Colors.purple),
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const AddSupplierPage()),
          );
          if (created == true) {
            fetchSuppliers();
          }
        },
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
  final TextEditingController _kodeSupplierC = TextEditingController();
  final TextEditingController _supplierC = TextEditingController();
  final TextEditingController _pabrikC = TextEditingController();

  String? _jenisRm;
  String? _satuan;
  String? _jenisAyam;

  final List<String> jenisRmOptions = const [
    'WET CHICKEN',
    'DRY',
    'SAYURAN',
    'ICE',
    'UDANG',
  ];

  final List<String> satuanOptions = const [
    'Kg',
    'Karton',
    'Bak',
    'Pack',
    'Jerrycan',
  ];

  final List<String> jenisAyamOptions = const [
    'FRESH WET CHICKEN',
    'FROZEN CHICKEN',
    'OTHER',
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
        Uri.parse('https://api-gts-rm.scm-ppa.com/gtsrm/api/supplier'),
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
        Navigator.pop(context, true);
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
              if (_jenisRm == 'WET CHICKEN') ...[
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
