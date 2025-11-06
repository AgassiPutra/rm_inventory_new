import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:rm_inventory_new/screens/incomingdetailpage.dart';
import 'package:rm_inventory_new/screens/menu_1.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/custom_drawer.dart';
import '../utils/auth.dart';
import 'package:intl/intl.dart';

class IncomingManagementPage extends StatefulWidget {
  const IncomingManagementPage({super.key});

  @override
  _IncomingManagementPageState createState() => _IncomingManagementPageState();
}

class _IncomingManagementPageState extends State<IncomingManagementPage> {
  final tanggalAwalController = TextEditingController();
  final tanggalAkhirController = TextEditingController();
  final DateTime today = DateTime.now();

  List<Map<String, dynamic>> data = [];
  late List<Map<String, dynamic>> filteredData = [];
  bool isLoading = true;
  String? errorMessage;
  String? userRole;
  String? userEmail;
  String? _selectedUnit;
  String? _selectedType;

  final List<String> _unitOptions = ['CK1', 'CK2', 'CP3', 'Lainnya'];
  final List<String> _typeOptions = [
    'Wet Chicken',
    'Sayuran',
    'Udang',
    'Ice',
    'Dry',
    'Lainnya',
  ];

  @override
  void initState() {
    super.initState();
    fetchIncomingRM();
    Auth.check(context);
    _loadUserRole();
  }

  @override
  void dispose() {
    tanggalAwalController.dispose();
    tanggalAkhirController.dispose();
    super.dispose();
  }

  String _getInitials(String? email) {
    if (email == null || email.isEmpty) return '??';
    String namePart = email.split('@').first;
    namePart = namePart.replaceAll(RegExp(r'[._-]'), ' ');
    List<String> parts = namePart
        .split(' ')
        .where((s) => s.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return 'U';
    }

    if (parts.length == 1) {
      String part = parts[0];
      if (part.length >= 2) {
        return part.substring(0, 2).toUpperCase();
      } else {
        return part[0].toUpperCase();
      }
    }
    if (parts.length > 1) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return '??';
  }

  String _formatEmailAsName(String? email) {
    if (email == null || email.isEmpty) return 'User';
    String namePart = email.split('@').first;
    namePart = namePart.replaceAll(RegExp(r'[._-]'), ' ');
    List<String> parts = namePart
        .split(' ')
        .where((s) => s.isNotEmpty)
        .toList();

    if (parts.isEmpty) return 'User';

    String formattedName = parts
        .map((part) {
          if (part.isEmpty) return '';
          return part[0].toUpperCase() + part.substring(1).toLowerCase();
        })
        .join(' ');

    return formattedName;
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('posisi');
    final email = prefs.getString('email');
    if (mounted) {
      setState(() {
        userRole = role;
        userEmail = email;
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
    final tanggalAwal = tanggalAwalController.text;
    final tanggalAkhir = tanggalAkhirController.text;

    setState(() {
      filteredData = data.where((row) {
        final unitMatch =
            _selectedUnit == null ||
            _selectedUnit == 'Lainnya' ||
            (row['unit'] ?? '').toLowerCase() == _selectedUnit!.toLowerCase();
        final typeMatch =
            _selectedType == null ||
            _selectedType == 'Lainnya' ||
            (row['jenis_rm'] ?? '').toLowerCase() ==
                _selectedType!.toLowerCase();

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

        return unitMatch && typeMatch && tanggalMatch;
      }).toList();
    });
  }

  void clearFilter() {
    setState(() {
      _selectedUnit = null;
      _selectedType = null;
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
      final now = DateTime.now();
      final firstDayOfPreviousMonth = DateTime(now.year, now.month - 1, 1);
      final DateTime tomorrow = today.add(const Duration(days: 1));

      final String tanggalAwal = tanggalAwalController.text.isNotEmpty
          ? tanggalAwalController.text
          : formatter.format(firstDayOfPreviousMonth);
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

      // print('Status code: ${response.statusCode}');
      // print('Response body: ${response.body}');

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

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '';
    try {
      final parsedDate = DateTime.parse(dateString);
      return DateFormat('dd MMM yyyy, HH:mm').format(parsedDate);
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Incoming Management',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Streamlines raw material data entry and review...',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                onPressed: () {},
                icon: Icon(
                  Icons.notifications_none_rounded,
                  color: Colors.pink[400],
                ),
              ),
              SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: Colors.pink[400],
                radius: 18,
                child: Text(
                  _getInitials(userEmail),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Text(
                _formatEmailAsName(userEmail),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: _buildDropdown(
              hint: 'Unit',
              value: _selectedUnit,
              items: _unitOptions,
              onChanged: (val) {
                setState(() => _selectedUnit = val);
                applyFilter();
              },
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: _buildDropdown(
              hint: 'Type',
              value: _selectedType,
              items: _typeOptions,
              onChanged: (val) {
                setState(() => _selectedType = val);
                applyFilter();
              },
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => Menu1Page()),
                );
              },
              icon: Icon(Icons.add_circle, size: 20),
              label: Text('Add New Incoming'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF388BFF),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String hint,
    String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items.map((String item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item, style: TextStyle(fontSize: 14)),
        );
      }).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: null,
      backgroundColor: Color(0xFFF0F9F6),
      drawer: CustomDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30.0),
                    topRight: Radius.circular(30.0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildFilterBar(),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minWidth: constraints.maxWidth,
                                  ),
                                  child: isLoading
                                      ? Center(
                                          child: Padding(
                                            padding: const EdgeInsets.all(32.0),
                                            child: CircularProgressIndicator(),
                                          ),
                                        )
                                      : DataTable(
                                          headingRowHeight: 48.0,
                                          dataRowHeight: 52.0,
                                          headingRowColor:
                                              MaterialStateProperty.all(
                                                Colors.grey[50],
                                              ),
                                          headingTextStyle: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                            fontSize: 14,
                                          ),
                                          dataTextStyle: TextStyle(
                                            fontSize: 14,
                                            color: Colors.black87,
                                          ),
                                          columnSpacing: 36,
                                          dividerThickness: 1,
                                          sortColumnIndex: null,
                                          sortAscending: true,

                                          columns: [
                                            DataColumn(label: Text('FAKTUR')),
                                            DataColumn(label: Text('UNIT')),
                                            DataColumn(label: Text('TYPE')),
                                            DataColumn(label: Text('SUPPLIER')),
                                            DataColumn(label: Text('DATE')),
                                            DataColumn(label: Text('ACTIONS')),
                                          ],
                                          rows: filteredData.map((row) {
                                            return DataRow(
                                              cells: [
                                                DataCell(
                                                  Text(
                                                    row['faktur'] ?? '',
                                                    style: TextStyle(
                                                      color: Colors.blue[700],
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  Builder(
                                                    builder: (context) {
                                                      final String unitText =
                                                          (row['unit'] ?? '')
                                                              .toString()
                                                              .toUpperCase();
                                                      return unitText.contains(
                                                                'CK',
                                                              ) ||
                                                              unitText.contains(
                                                                'CP',
                                                              )
                                                          ? Container(
                                                              padding:
                                                                  EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        12,
                                                                    vertical: 6,
                                                                  ),
                                                              decoration: BoxDecoration(
                                                                color: Colors
                                                                    .blue[100],
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      8,
                                                                    ),
                                                              ),
                                                              child: Text(
                                                                row['unit'] ??
                                                                    '',
                                                                style: TextStyle(
                                                                  color: Colors
                                                                      .blue[900],
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                              ),
                                                            )
                                                          : Text(
                                                              row['unit'] ?? '',
                                                            );
                                                    },
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(row['jenis_rm'] ?? ''),
                                                ),
                                                DataCell(
                                                  Text(row['supplier'] ?? ''),
                                                ),
                                                DataCell(
                                                  Text(
                                                    _formatDate(
                                                      row['tanggal_incoming'],
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      IconButton(
                                                        icon: Icon(
                                                          Icons
                                                              .description_outlined,
                                                          color: Colors.blue,
                                                        ),
                                                        onPressed: () {
                                                          Navigator.push(
                                                            context,
                                                            MaterialPageRoute(
                                                              builder: (_) =>
                                                                  IncomingDetailPage(
                                                                    data: row,
                                                                  ),
                                                            ),
                                                          );
                                                        },
                                                        tooltip: 'View Details',
                                                      ),
                                                      if (userRole ==
                                                              'supervisor' ||
                                                          userRole ==
                                                              'SUPERVISOR' ||
                                                          userRole ==
                                                              'Supervisor')
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
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
