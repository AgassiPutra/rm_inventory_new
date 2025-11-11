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
  final apiTanggalAwalController = TextEditingController();
  final apiTanggalAkhirController = TextEditingController();

  final DateTime today = DateTime.now();
  List<Map<String, dynamic>> data = [];
  late List<Map<String, dynamic>> filteredData = [];
  bool isLoading = true;
  String? errorMessage;
  int? _sortColumnIndex;
  bool _sortAscending = true;
  String? userRole;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final firstDayOfPreviousMonth = DateTime(now.year, now.month - 1, 1);

    final DateFormat formatter = DateFormat('yyyy-MM-dd');
    apiTanggalAwalController.text = formatter.format(firstDayOfPreviousMonth);
    apiTanggalAkhirController.text = formatter.format(now);
    fetchIncomingRM();

    Auth.check(context);
    _loadUserRole();
  }

  @override
  void dispose() {
    fakturController.dispose();
    unitController.dispose();
    typeController.dispose();
    supplierController.dispose();
    tanggalAwalController.dispose();
    tanggalAkhirController.dispose();
    apiTanggalAwalController.dispose();
    apiTanggalAkhirController.dispose();
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

  Future<String?> getLokasiUnit() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jenis_unit');
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('posisi');
    if (mounted) {
      setState(() {
        userRole = role;
      });
    }
  }

  void _showDeleteConfirmationDialog(String faktur) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Konfirmasi Hapus'),
        content: Text(
          'Apakah Anda yakin ingin menghapus data dengan faktur "$faktur"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              deleteIncomingRM(faktur);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> deleteIncomingRM(String faktur) async {
    final token = await getToken();
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Token tidak valid. Silakan login ulang.')),
      );
      return;
    }

    final url =
        'https://api-gts-rm.scm-ppa.com/gtsrm/api/incoming-rm?faktur=$faktur';

    try {
      final response = await http.delete(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Data berhasil dihapus')));
        fetchIncomingRM();
      } else {
        final errorMsg =
            jsonDecode(response.body)['message'] ?? 'Gagal menghapus';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $errorMsg'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kesalahan jaringan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
    tanggalAwalController.clear();
    tanggalAkhirController.clear();
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
      final String? lokasiUnit = await getLokasiUnit();

      if (token == null) {
        setState(() {
          errorMessage = 'Token tidak ditemukan. Silakan login ulang.';
          isLoading = false;
        });
        return;
      }
      if (lokasiUnit == null || lokasiUnit.isEmpty) {
        setState(() {
          errorMessage = 'Lokasi unit tidak terdeteksi. Silakan login ulang.';
          isLoading = false;
        });
        return;
      }

      const String baseUrl =
          'https://api-gts-rm.scm-ppa.com/gtsrm/api/incoming-rm';

      final Map<String, String> queryParams = {'lokasi_unit': lokasiUnit};
      final String tanggalAwal = apiTanggalAwalController.text.trim();
      final String tanggalAkhir = apiTanggalAkhirController.text.trim();

      if (tanggalAwal.isNotEmpty) {
        queryParams['tanggalAwal'] = tanggalAwal;
      }
      if (tanggalAkhir.isNotEmpty) {
        queryParams['tanggalAkhir'] = tanggalAkhir;
      }

      final Uri uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);
      final String url = uri.toString();

      print('Fetching URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );

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
          clearFilter();
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
        title: Text('Filter Data Lokal'),
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
                onTap: () => _selectDate(context, tanggalAwalController),
                child: AbsorbPointer(
                  child: TextField(
                    controller: tanggalAwalController,
                    decoration: InputDecoration(
                      labelText: 'Filter Tanggal Awal',
                      prefixIcon: Icon(Icons.date_range),
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _selectDate(context, tanggalAkhirController),
                child: AbsorbPointer(
                  child: TextField(
                    controller: tanggalAkhirController,
                    decoration: InputDecoration(
                      labelText: 'Filter Tanggal Akhir',
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
              applyFilter();
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

  void _showEditDialog(Map<String, dynamic> rowData) {}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2.0,
        iconTheme: IconThemeData(color: Colors.black87),
        title: Text(
          'Incoming Raw Materials',
          style: TextStyle(color: Colors.black87),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_alt_outlined),
            color: Colors.black87,
            tooltip: "Filter Data Lokal",
            onPressed: () {
              _showFilterDialog();
            },
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            color: Colors.black87,
            tooltip: "Refresh Data dari Server",
            onPressed: () {
              fetchIncomingRM();
            },
          ),
          IconButton(
            icon: Icon(Icons.person),
            color: Colors.black87,
            onPressed: () {},
          ),
        ],
        bottom: _buildAppBarFilter(),
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
                      : (errorMessage != null && filteredData.isEmpty)
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Text(errorMessage!),
                          ),
                        )
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
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          Icons.edit,
                                          color: Colors.blue,
                                        ),
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
                                      if (userRole == 'supervisor' ||
                                          userRole == 'SUPERVISOR' ||
                                          userRole == 'Supervisor')
                                        IconButton(
                                          icon: Icon(
                                            Icons.delete,
                                            color: Colors.red,
                                          ),
                                          onPressed: () {
                                            _showDeleteConfirmationDialog(
                                              row['faktur'],
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
    );
  }

  Future<void> _selectDate(
    BuildContext context,
    TextEditingController controller,
  ) async {
    DateTime initialDate = DateTime.now();
    if (controller.text.isNotEmpty) {
      initialDate = DateTime.tryParse(controller.text) ?? DateTime.now();
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        controller.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  PreferredSizeWidget _buildAppBarFilter() {
    final screenWidth = MediaQuery.of(context).size.width;
    bool isNarrow = screenWidth < 450;
    double preferredHeight = isNarrow ? 120.0 : 70.0;

    return PreferredSize(
      preferredSize: Size.fromHeight(preferredHeight),
      child: Container(
        color: Colors.grey[200],
        padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 12.0),
        child: isNarrow ? _buildNarrowFilter() : _buildWideFilter(),
      ),
    );
  }

  Widget _buildWideFilter() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: _buildApiTanggalAwalField()),
        const SizedBox(width: 12),
        Expanded(child: _buildApiTanggalAkhirField()),
        const SizedBox(width: 8),
        _buildAmbilDataButton(),
      ],
    );
  }

  Widget _buildNarrowFilter() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: _buildApiTanggalAwalField()),
            const SizedBox(width: 12),
            Expanded(child: _buildApiTanggalAkhirField()),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, child: _buildAmbilDataButton()),
      ],
    );
  }

  Widget _buildApiTanggalAwalField() {
    return TextField(
      controller: apiTanggalAwalController,
      readOnly: true,
      style: TextStyle(color: Colors.black87, fontSize: 14),
      decoration: InputDecoration(
        labelText: 'Tanggal Awal',
        labelStyle: TextStyle(color: Colors.grey[700], fontSize: 12),
        suffixIcon: Icon(
          Icons.calendar_today,
          color: Colors.grey[700],
          size: 20,
        ),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(
            color: Theme.of(context).primaryColor,
            width: 2.0,
          ),
        ),
      ),
      onTap: () => _selectDate(context, apiTanggalAwalController),
    );
  }

  Widget _buildApiTanggalAkhirField() {
    return TextField(
      controller: apiTanggalAkhirController,
      readOnly: true,
      style: TextStyle(color: Colors.black87, fontSize: 14),
      decoration: InputDecoration(
        labelText: 'Tanggal Akhir',
        labelStyle: TextStyle(color: Colors.grey[700], fontSize: 12),
        suffixIcon: Icon(
          Icons.calendar_today,
          color: Colors.grey[700],
          size: 20,
        ),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(
            color: Theme.of(context).primaryColor,
            width: 2.0,
          ),
        ),
      ),
      onTap: () => _selectDate(context, apiTanggalAkhirController),
    );
  }

  Widget _buildAmbilDataButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      ),
      onPressed: isLoading ? null : fetchIncomingRM,
      child: Text('Ambil Data'),
    );
  }
}
