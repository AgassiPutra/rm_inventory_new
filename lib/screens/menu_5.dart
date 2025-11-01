import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/custom_drawer.dart';
import 'login.dart';
import '../utils/auth.dart';

class MasterSupplierPage extends StatefulWidget {
  @override
  State<MasterSupplierPage> createState() => _MasterSupplierPageState();
}

class _MasterSupplierPageState extends State<MasterSupplierPage> {
  List<dynamic> suppliers = [];
  List<dynamic> filteredSuppliers = [];
  bool isLoading = true;
  String? userEmail;
  String? _selectedUnit;
  String? _selectedType;

  final List<String> _unitOptions = const [
    'KG',
    'KARTON',
    'BAK',
    'PACK',
    'JERRYCAN',
    'Lainnya',
  ];
  final List<String> _typeOptions = const [
    'WET CHICKEN',
    'DRY',
    'SAYURAN',
    'ICE',
    'UDANG',
    'Lainnya',
  ];

  @override
  void initState() {
    super.initState();
    fetchSuppliers();
    Auth.check(context);
    _loadUserData();
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('email');
    if (mounted) {
      setState(() {
        userEmail = email;
      });
    }
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
      return (part.length >= 2)
          ? part.substring(0, 2).toUpperCase()
          : part[0].toUpperCase();
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

  void applyFilter() {
    setState(() {
      filteredSuppliers = suppliers.where((row) {
        final unitMatch =
            _selectedUnit == null ||
            _selectedUnit == 'Lainnya' ||
            (row['satuan'] ?? '').toLowerCase().contains(
              _selectedUnit!.toLowerCase(),
            );
        final typeMatch =
            _selectedType == null ||
            _selectedType == 'Lainnya' ||
            (row['jenis_rm'] ?? '').toLowerCase().contains(
              _selectedType!.toLowerCase(),
            );
        return unitMatch && typeMatch;
      }).toList();
    });
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
          applyFilter();
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

  Widget _buildStatusIcon(bool isSuccess) {
    final Color baseColor = isSuccess ? Color(0xFF388BFF) : Colors.red[400]!;
    final IconData iconData = isSuccess
        ? Icons.check_rounded
        : Icons.warning_amber_rounded;

    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: baseColor.withOpacity(0.1),
      ),
      child: Center(
        child: Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: baseColor.withOpacity(0.2),
          ),
          child: Center(
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: baseColor,
              ),
              child: Icon(iconData, color: Colors.white, size: 36),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showStatusDialog({
    required bool isSuccess,
    required String title,
    required String message,
  }) async {
    final context = Navigator.of(this.context).overlay!.context;

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        Future.delayed(Duration(seconds: 2), () {
          if (Navigator.of(dialogContext).canPop()) {
            Navigator.of(dialogContext).pop();
          }
        });

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 20),
              _buildStatusIcon(isSuccess),
              SizedBox(height: 24),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  InputDecoration _buildModalInputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.grey[400]),
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: Color(0xFF388BFF), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: Colors.red, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: Colors.red, width: 2),
      ),
    );
  }

  Future<void> _openAddSupplier() async {
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
      'KG',
      'KARTON',
      'BAK',
      'PACK',
      'JERRYCAN',
    ];
    final List<String> jenisAyamOptions = const [
      'FRESH WET CHICKEN',
      'FROZEN CHICKEN',
      'OTHER',
    ];

    Future<bool> _submit() async {
      if (!_formKey.currentState!.validate()) return false;

      final token = await getToken() ?? '';
      if (token.isEmpty) {
        if (!mounted) return false;
        await _showStatusDialog(
          isSuccess: false,
          title: "Data Supplier gagal disimpan",
          message: "Token tidak valid. Silakan login ulang.",
        );
        return false;
      }

      final body = {
        "kode_supplier": _kodeSupplierC.text.trim(),
        "supplier": _supplierC.text.trim(),
        "nama_pabrik": _pabrikC.text.trim(),
        "satuan": _satuan ?? "Kg",
        "jenis_rm": _jenisRm ?? "",
        "jenis_ayam": (_jenisRm == 'WET CHICKEN') ? (_jenisAyam ?? "") : "",
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

        if (!mounted) return false;
        if (res.statusCode == 200 || res.statusCode == 201) {
          await _showStatusDialog(
            isSuccess: true,
            title: "Data Supplier Tersimpan",
            message: "Datamu telah berhasil tersimpan!",
          );
          return true;
        } else {
          await _showStatusDialog(
            isSuccess: false,
            title: "Data Supplier gagal disimpan",
            message: "Datamu masih belum tersimpan!",
          );
          return false;
        }
      } catch (e) {
        if (!mounted) return false;
        await _showStatusDialog(
          isSuccess: false,
          title: "Data Supplier gagal disimpan",
          message: "Terjadi kesalahan: ${e.toString()}",
        );
        return false;
      }
    }

    final bool? created = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0),
              ),
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24.0),
              actionsPadding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 24.0),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Add Master Supplier',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.grey[700]),
                    onPressed: () => Navigator.pop(dialogContext, false),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.4,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Suppliers Code',
                          style: TextStyle(fontSize: 14, color: Colors.black87),
                        ),
                        SizedBox(height: 8),
                        TextFormField(
                          controller: _kodeSupplierC,
                          decoration: _buildModalInputDecoration('Choose'),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Wajib diisi'
                              : null,
                        ),
                        SizedBox(height: 16),

                        Text(
                          'Suppliers',
                          style: TextStyle(fontSize: 14, color: Colors.black87),
                        ),
                        SizedBox(height: 8),
                        TextFormField(
                          controller: _supplierC,
                          decoration: _buildModalInputDecoration(
                            'Suppliers name',
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Wajib diisi'
                              : null,
                        ),
                        SizedBox(height: 16),

                        Text(
                          'Producer',
                          style: TextStyle(fontSize: 14, color: Colors.black87),
                        ),
                        SizedBox(height: 8),
                        TextFormField(
                          controller: _pabrikC,
                          decoration: _buildModalInputDecoration('Producer'),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Wajib diisi'
                              : null,
                        ),
                        SizedBox(height: 16),

                        Text(
                          'RM Type',
                          style: TextStyle(fontSize: 14, color: Colors.black87),
                        ),
                        SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _jenisRm,
                          items: jenisRmOptions
                              .map(
                                (e) =>
                                    DropdownMenuItem(value: e, child: Text(e)),
                              )
                              .toList(),
                          onChanged: (v) => setModalState(() => _jenisRm = v),
                          decoration: _buildModalInputDecoration('RM Type'),
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Pilih jenis RM'
                              : null,
                        ),
                        SizedBox(height: 16),
                        if (_jenisRm == 'WET CHICKEN') ...[
                          Text(
                            'Jenis Ayam',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _jenisAyam,
                            items: jenisAyamOptions
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setModalState(() => _jenisAyam = v),
                            decoration: _buildModalInputDecoration(
                              'Jenis Ayam',
                            ),
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'Pilih jenis ayam'
                                : null,
                          ),
                          SizedBox(height: 16),
                        ],

                        Text(
                          'Unit',
                          style: TextStyle(fontSize: 14, color: Colors.black87),
                        ),
                        SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _satuan,
                          items: satuanOptions
                              .map(
                                (e) =>
                                    DropdownMenuItem(value: e, child: Text(e)),
                              )
                              .toList(),
                          onChanged: (v) => setModalState(() => _satuan = v),
                          decoration: _buildModalInputDecoration('Unit'),
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Pilih satuan' : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      bool success = await _submit();
                      if (success) {
                        Navigator.pop(dialogContext, true);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF388BFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                    ),
                    child: Text('Save'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    _kodeSupplierC.dispose();
    _supplierC.dispose();
    _pabrikC.dispose();
    if (created == true) {
      fetchSuppliers();
    }
  }

  Future<void> showSupplierForm({Map<String, dynamic>? data}) async {
    final _formKey = GlobalKey<FormState>();
    final TextEditingController _kodeSupplierC = TextEditingController(
      text: data?['kode_supplier'] ?? '',
    );
    final TextEditingController _supplierC = TextEditingController(
      text: data?['supplier'] ?? '',
    );
    final TextEditingController _pabrikC = TextEditingController(
      text: data?['nama_pabrik'] ?? '',
    );

    String? _jenisRm = data?['jenis_rm'] as String?;
    String? _satuan = data?['satuan'] as String?;
    String? _jenisAyam = data?['jenis_ayam'] as String?;

    final List<String> jenisRmOptions = const [
      'WET CHICKEN',
      'DRY',
      'SAYURAN',
      'ICE',
      'UDANG',
    ];
    final List<String> satuanOptions = const [
      'KG',
      'KARTON',
      'BAK',
      'PACK',
      'JERRYCAN',
    ];
    final List<String> jenisAyamOptions = const [
      'FRESH WET CHICKEN',
      'FROZEN CHICKEN',
      'OTHER',
    ];

    Future<bool> _submitEdit() async {
      if (!_formKey.currentState!.validate()) return false;

      final token = await getToken() ?? '';
      if (token.isEmpty) {
        if (!mounted) return false;
        await _showStatusDialog(
          isSuccess: false,
          title: "Data Supplier gagal disimpan",
          message: "Token tidak valid. Silakan login ulang.",
        );
        return false;
      }

      final body = {
        'kode_supplier': _kodeSupplierC.text.trim(),
        'supplier': _supplierC.text.trim(),
        'nama_pabrik': _pabrikC.text.trim(),
        'satuan': _satuan ?? 'Kg',
        'jenis_rm': _jenisRm ?? '',
        'jenis_ayam': (_jenisRm == 'WET CHICKEN') ? (_jenisAyam ?? '') : '',
      };

      try {
        final res = await http.put(
          Uri.parse(
            'https://trial-api-gts-rm.scm-ppa.com/gtsrm/api/supplier?kode_supplier=${_kodeSupplierC.text.trim()}',
          ),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        );

        if (!mounted) return false;
        if (res.statusCode == 200 || res.statusCode == 201) {
          await _showStatusDialog(
            isSuccess: true,
            title: "Data Supplier Tersimpan",
            message: "Datamu telah berhasil diperbarui!",
          );
          return true;
        } else {
          String msg = 'Gagal menyimpan data (${res.statusCode})';
          try {
            final m = jsonDecode(res.body);
            if (m is Map && m['message'] is String) {
              msg = '${m['message']} (${res.statusCode})';
            }
          } catch (_) {}
          print("Error API: $msg");
          await _showStatusDialog(
            isSuccess: false,
            title: "Data Supplier gagal disimpan",
            message: "Datamu masih belum tersimpan!",
          );
          return false;
        }
      } catch (e) {
        if (!mounted) return false;
        await _showStatusDialog(
          isSuccess: false,
          title: "Data Supplier gagal disimpan",
          message: "Terjadi kesalahan: ${e.toString()}",
        );
        return false;
      }
    }

    final bool? updated = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0),
              ),
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24.0),
              actionsPadding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 24.0),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Edit Master Supplier',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.grey[700]),
                    onPressed: () => Navigator.pop(dialogContext, false),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.4,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Suppliers Code',
                          style: TextStyle(fontSize: 14, color: Colors.black87),
                        ),
                        SizedBox(height: 8),
                        TextFormField(
                          controller: _kodeSupplierC,
                          readOnly: true,
                          decoration: _buildModalInputDecoration(
                            'Choose',
                          ).copyWith(fillColor: Colors.grey[200]),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Wajib diisi'
                              : null,
                        ),
                        SizedBox(height: 16),

                        Text(
                          'Suppliers',
                          style: TextStyle(fontSize: 14, color: Colors.black87),
                        ),
                        SizedBox(height: 8),
                        TextFormField(
                          controller: _supplierC,
                          decoration: _buildModalInputDecoration(
                            'Suppliers name',
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Wajib diisi'
                              : null,
                        ),
                        SizedBox(height: 16),

                        Text(
                          'Producer',
                          style: TextStyle(fontSize: 14, color: Colors.black87),
                        ),
                        SizedBox(height: 8),
                        TextFormField(
                          controller: _pabrikC,
                          decoration: _buildModalInputDecoration('Producer'),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Wajib diisi'
                              : null,
                        ),
                        SizedBox(height: 16),

                        Text(
                          'RM Type',
                          style: TextStyle(fontSize: 14, color: Colors.black87),
                        ),
                        SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: jenisRmOptions.contains(_jenisRm)
                              ? _jenisRm
                              : null,
                          items: jenisRmOptions
                              .map(
                                (e) =>
                                    DropdownMenuItem(value: e, child: Text(e)),
                              )
                              .toList(),
                          onChanged: (v) => setModalState(() {
                            _jenisRm = v;
                            if (_jenisRm != 'WET CHICKEN') {
                              _jenisAyam = null;
                            }
                          }),
                          decoration: _buildModalInputDecoration('RM Type'),
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Pilih jenis RM'
                              : null,
                        ),
                        SizedBox(height: 16),
                        if (_jenisRm == 'WET CHICKEN') ...[
                          Text(
                            'Jenis Ayam',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: jenisAyamOptions.contains(_jenisAyam)
                                ? _jenisAyam
                                : null,
                            items: jenisAyamOptions
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setModalState(() => _jenisAyam = v),
                            decoration: _buildModalInputDecoration(
                              'Jenis Ayam',
                            ),
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'Pilih jenis ayam'
                                : null,
                          ),
                          SizedBox(height: 16),
                        ],

                        Text(
                          'Unit',
                          style: TextStyle(fontSize: 14, color: Colors.black87),
                        ),
                        SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: satuanOptions.contains(_satuan)
                              ? _satuan
                              : null,
                          items: satuanOptions
                              .map(
                                (e) =>
                                    DropdownMenuItem(value: e, child: Text(e)),
                              )
                              .toList(),
                          onChanged: (v) => setModalState(() => _satuan = v),
                          decoration: _buildModalInputDecoration('Unit'),
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Pilih satuan' : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      bool success = await _submitEdit();
                      if (success) {
                        Navigator.pop(dialogContext, true);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF388BFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                    ),
                    child: Text('Save'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    _kodeSupplierC.dispose();
    _supplierC.dispose();
    _pabrikC.dispose();
    if (updated == true) {
      fetchSuppliers();
    }
  }

  Future<void> deleteSupplier(BuildContext context, String kodeSupplier) async {
    final url = Uri.parse(
      'https://trial-api-gts-rm.scm-ppa.com/gtsrm/api/supplier?kode_supplier=$kodeSupplier',
    );
    final token = await getToken();

    if (token == null || token.isEmpty) {
      await _showStatusDialog(
        isSuccess: false,
        title: "Gagal Menghapus",
        message: "Token tidak valid. Silakan login ulang.",
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
        await _showStatusDialog(
          isSuccess: true,
          title: "Berhasil Dihapus",
          message: "Data supplier telah dihapus.",
        );
        fetchSuppliers();
      } else {
        print('Status Code: ${response.statusCode}');
        print('Response Body: ${response.body}');
        await _showStatusDialog(
          isSuccess: false,
          title: "Gagal Menghapus",
          message: "Data supplier gagal dihapus.",
        );
      }
    } catch (e) {
      Navigator.of(context, rootNavigator: true).pop();
      await _showStatusDialog(
        isSuccess: false,
        title: "Gagal Menghapus",
        message: "Terjadi kesalahan: ${e.toString()}",
      );
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
                'Master Supplier',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Streamlines raw material data entry and review for better transparancy and efficiency.',
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
              hint: 'Satuan',
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
              onPressed: _openAddSupplier,
              icon: Icon(Icons.add_circle, size: 20),
              label: Text('Add Master Supplier'),
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
      drawer: const CustomDrawer(),
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
                                          columnSpacing: 24,
                                          columns: const [
                                            DataColumn(
                                              label: Text('KODE SUPPLIER'),
                                            ),
                                            DataColumn(label: Text('SUPPLIER')),
                                            DataColumn(label: Text('PRODUSEN')),
                                            DataColumn(label: Text('SATUAN')),
                                            DataColumn(label: Text('JENIS RM')),
                                            DataColumn(label: Text('ACTIONS')),
                                          ],
                                          rows: filteredSuppliers.map((data) {
                                            return DataRow(
                                              cells: [
                                                DataCell(
                                                  Text(
                                                    data['kode_supplier'] ?? '',
                                                    style: TextStyle(
                                                      color: Colors.blue[700],
                                                      decoration: TextDecoration
                                                          .underline,
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(data['supplier'] ?? ''),
                                                ),
                                                DataCell(
                                                  Text(
                                                    data['nama_pabrik'] ?? '',
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(data['satuan'] ?? ''),
                                                ),
                                                DataCell(
                                                  Text(data['jenis_rm'] ?? ''),
                                                ),
                                                DataCell(
                                                  Row(
                                                    children: [
                                                      IconButton(
                                                        icon: const Icon(
                                                          Icons.edit,
                                                          size: 20,
                                                          color: Colors.orange,
                                                        ),
                                                        onPressed: () =>
                                                            showSupplierForm(
                                                              data: data,
                                                            ),
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(
                                                          Icons.delete,
                                                          size: 20,
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
                                                                  child:
                                                                      const Text(
                                                                        'Batal',
                                                                      ),
                                                                  onPressed: () =>
                                                                      Navigator.of(
                                                                        ctx,
                                                                      ).pop(),
                                                                ),
                                                                TextButton(
                                                                  child:
                                                                      const Text(
                                                                        'Hapus',
                                                                      ),
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
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: null,
    );
  }
}
