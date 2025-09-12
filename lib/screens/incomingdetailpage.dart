import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';

import 'package:rm_inventory_new/ble/bluetooth_manager_web.dart' as web;
import '../models/app_bluetooth_device.dart';
import 'dart:async';
import '../ble/permission_handler.dart';
import 'package:flutter/foundation.dart';

class IncomingDetailPage extends StatefulWidget {
  final Map<String, dynamic> data;

  const IncomingDetailPage({required this.data, Key? key}) : super(key: key);

  @override
  _IncomingDetailPageState createState() => _IncomingDetailPageState();
}

class _IncomingDetailPageState extends State<IncomingDetailPage> {
  @override
  void initState() {
    super.initState();
    bluetoothManager = web.BluetoothManagerWeb();
    _qtyLoss = '0';
    selectedJenisRm = widget.data['jenis_rm'];
    fetchIncomingDetail(widget.data['faktur']);
    fetchTimbangan(widget.data['faktur']);
    bluetoothManager = web.BluetoothManagerWeb();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    bluetoothManager.dispose();
    super.dispose();
  }

  final TextEditingController quantityLossController = TextEditingController();
  List<Map<String, dynamic>> scaleData = [];
  bool isLoading = true;

  late web.BluetoothManagerWeb bluetoothManager;
  List<AppBluetoothDevice> foundDevices = [];
  AppBluetoothDevice? connectedDevice;
  StreamSubscription<String>? _notificationSubscription;
  String bluetoothStatus = "No scales found";
  String? esp32Weight;
  XFile? _invoiceRevision;
  XFile? _suratJalanRevision;
  String _qtyLoss = '0';
  List<Map<String, dynamic>> receivedList = [];
  String? lastSubmittedFaktur;
  double? receivedWeight;

  String? selectedStatusPenerimaan;
  String? selectedTipeRM;
  final Map<String, List<String>> tipeRMOptions = {
    'WET CHICKEN': ['Boneless Dada (BLD)', 'Boneless Paha Kulit (BLPK)'],
    'SAYURAN': ['Wortel', 'Bawang', 'Jamur'],
    'DRY': ['Bumbu', 'Tepung', 'Lainnya'],
    'ICE': ['Es Batu', 'Ice Cube'],
    'UDANG': ['Udang Fresh', 'Udang Beku'],
  };
  String? selectedJenisRm;

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    print('Token from SharedPreferences: $token');
    return token;
  }

  Future<void> scanForDevices() async {
    bool granted = await PermissionHelper.requestBluetoothPermissions();
    if (!granted) {
      setState(() {
        bluetoothStatus = "Permissions denied";
      });
      return;
    }

    setState(() {
      foundDevices.clear();
      bluetoothStatus = "Scanning...";
    });

    await bluetoothManager.scanForDevices();

    setState(() {
      foundDevices
        ..clear()
        ..addAll(bluetoothManager.foundDevices);

      bluetoothStatus = bluetoothManager.foundDevices.isEmpty
          ? bluetoothManager.status
          : "Device(s) found";
    });
  }

  Future<void> connectToDevice(AppBluetoothDevice device) async {
    try {
      setState(() {
        bluetoothStatus = "Menghubungkan ke ${device.name}...";
        connectedDevice = null;
        esp32Weight = null;
      });

      await bluetoothManager
          .connectToDevice(device)
          .timeout(
            Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException("Gagal menghubungkan: Waktu tunggu habis");
            },
          );

      await _notificationSubscription?.cancel();
      _notificationSubscription = null;

      _notificationSubscription = bluetoothManager.weightStream.listen(
        (weightData) {
          debugPrint("📩 Data dari ESP32: '$weightData'");
          try {
            final weight = double.parse(weightData);
            if (mounted) {
              setState(() {
                esp32Weight = weight.toStringAsFixed(2);
                bluetoothStatus =
                    "Terhubung ke ${device.name} | Berat: ${esp32Weight} kg";
              });
            }
          } catch (e) {
            debugPrint("❌ Gagal parsing data: '$weightData', error: $e");
            if (mounted) {
              setState(() {
                esp32Weight = null;
                bluetoothStatus = "Data berat tidak valid dari ${device.name}";
              });
            }
          }
        },
        onError: (error) {
          debugPrint("❌ Error di weightStream: $error");
          if (mounted) {
            setState(() {
              bluetoothStatus = "Error menerima data: $error";
            });
          }
        },
        onDone: () {
          debugPrint("📴 Stream berat ditutup, kemungkinan perangkat terputus");
          if (mounted) {
            setState(() {
              connectedDevice = null;
              esp32Weight = null;
              bluetoothStatus = "Perangkat terputus";
            });
            Future.delayed(Duration(seconds: 3), () {
              if (mounted && connectedDevice == null) {
                debugPrint("🔄 Mencoba reconnect ke ${device.name}");
                connectToDevice(device);
              }
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          connectedDevice = device;
          bluetoothStatus = "Terhubung ke ${device.name}";
        });
      }
    } catch (e) {
      debugPrint("❌ Error menghubungkan ke perangkat: $e");
      if (mounted) {
        setState(() {
          connectedDevice = null;
          esp32Weight = null;
          bluetoothStatus = "Gagal menghubungkan: $e";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal menghubungkan ke ${device.name}: $e"),
            duration: Duration(seconds: 3),
          ),
        );

        Future.delayed(Duration(seconds: 3), () {
          if (mounted && connectedDevice == null) {
            debugPrint("🔄 Mencoba reconnect ke ${device.name}");
            connectToDevice(device);
          }
        });
      }
    }
  }

  Future<void> fetchIncomingDetail(String faktur) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    final url = Uri.parse(
      "https://api-gts-rm.miegacoan.id/gtsrm/api/incoming-rm?Faktur=$faktur",
    );

    try {
      final response = await http.get(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        print("DEBUG incoming-rm response: $decoded");

        if (decoded is Map && decoded.containsKey('data')) {
          final dataList = decoded['data'];
          if (dataList is List) {
            final match = dataList.firstWhere(
              (item) => item['faktur'] == faktur,
              orElse: () => null,
            );

            setState(() {
              _qtyLoss = match?['qty_losses']?.toString() ?? '0';
              quantityLossController.text = _qtyLoss;
              isLoading = false;
            });
          }
        } else {
          setState(() {
            _qtyLoss = '0';
            isLoading = false;
          });
        }
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      print("Error fetch incoming detail: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> uploadRevisionFiles() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    final faktur = widget.data['faktur'] ?? '';

    try {
      final uri = Uri.parse(
        "https://api-gts-rm.miegacoan.id/gtsrm/api/incoming-rm/invoice-sj-update?Faktur=$faktur",
      );
      final request = http.MultipartRequest('PUT', uri);

      if (_invoiceRevision != null) {
        final bytes = await _invoiceRevision!.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'invoice_supplier_revisi',
            bytes,
            filename: _invoiceRevision!.name,
          ),
        );
      }

      if (_suratJalanRevision != null) {
        final bytes = await _suratJalanRevision!.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'surat_jalan_revisi',
            bytes,
            filename: _suratJalanRevision!.name,
          ),
        );
      }

      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      final response = await request.send();
      final respStr = await response.stream.bytesToString();
      print("Response status: ${response.statusCode}");
      print("Response body: $respStr");

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Upload revisi berhasil!")));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Upload gagal (${response.statusCode})")),
        );
      }
    } catch (e) {
      print("Error upload: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> fetchTimbangan(String faktur) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    final url = Uri.parse(
      "https://api-gts-rm.miegacoan.id/gtsrm/api/timbangan?Faktur=$faktur",
    );

    try {
      final response = await http.get(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      print("Status Timbangan: ${response.statusCode}");

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded.containsKey('data')) {
          final data = decoded['data'];

          if (data is List && data.isNotEmpty) {
            final firstItem = data[0];
            if (firstItem is Map && firstItem.isNotEmpty) {
              final firstKey = firstItem.keys.first;
              final listData = firstItem[firstKey];

              setState(() {
                scaleData = List<Map<String, dynamic>>.from(listData);
                isLoading = false;
              });
              return;
            }
          }
        }

        setState(() {
          scaleData = [];
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      print("Error fetch timbangan: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> updateQuantityLoss() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    final faktur = widget.data['faktur'];
    final qtyLoss = quantityLossController.text.trim();

    if (qtyLoss.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Masukkan nilai Quantity Loss terlebih dahulu')),
      );
      return;
    }

    final url = Uri.parse(
      "https://api-gts-rm.miegacoan.id/gtsrm/api/incoming-rm/qty-losses?Faktur=$faktur",
    );

    try {
      final response = await http.put(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({"qty_losses": qtyLoss}),
      );

      print("Response status: ${response.statusCode}");
      print("Response body: ${response.body}");

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Quantity loss updated successfully!')),
        );
        setState(() {
          _qtyLoss = qtyLoss;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal update: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Incoming Detail'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  SizedBox(height: 12),
                  _buildSection(
                    title: 'Raw Material Information',
                    children: [
                      _buildInfoRow('Type', widget.data['jenis_rm']),
                      _buildInfoRow('Supplier', widget.data['supplier']),
                      _buildInfoRow('Unit', widget.data['unit']),
                      _buildInfoRow(
                        'Quantity PO',
                        (widget.data['qty_po'] != null)
                            ? '${widget.data['qty_po']} KG'
                            : '0 KG',
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  _buildSection(
                    title: 'Documents',
                    children: [
                      _buildDocumentRow(
                        context,
                        'Invoice Supplier',
                        imagePath: widget.data['invoce_supplier'],
                      ),
                      if (widget.data['invoce_supplier_revisi'] != null &&
                          widget.data['invoce_supplier_revisi'].isNotEmpty)
                        _buildDocumentRow(
                          context,
                          'Invoice Supplier Revision',
                          imagePath: widget.data['invoce_supplier_revisi'],
                        ),
                      _buildDocumentRow(
                        context,
                        'Delivery Note (Surat Jalan)',
                        imagePath: widget.data['surat_jalan'],
                      ),
                      if (widget.data['surat_jalan_revisi'] != null &&
                          widget.data['surat_jalan_revisi'].isNotEmpty)
                        _buildDocumentRow(
                          context,
                          'Delivery Note Revision',
                          imagePath: widget.data['surat_jalan_revisi'],
                        ),
                    ],
                  ),
                  SizedBox(height: 12),
                  _buildSection(
                    title: 'Update Documents',
                    subtitle:
                        'Use this form to upload revised versions of the invoice or delivery note.',
                    children: [
                      UploadRow(
                        label: 'Invoice Supplier Revision',
                        onFilePicked: (file) => _invoiceRevision = file,
                      ),
                      UploadRow(
                        label: 'Delivery Note (Surat Jalan) Revision',
                        onFilePicked: (file) => _suratJalanRevision = file,
                      ),
                      SizedBox(height: 12),
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: uploadRevisionFiles,
                          icon: Icon(Icons.cloud_upload),
                          label: Text("Upload Revision Files"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  _buildSection(
                    title: 'Quantity Loss',
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning, color: Colors.red),
                            SizedBox(width: 8),
                            Text(
                              'Current Quantity Loss: ',
                              style: TextStyle(color: Colors.red),
                            ),
                            Text(
                              '$_qtyLoss KG',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 10),
                      TextField(
                        controller: quantityLossController,
                        decoration: InputDecoration(
                          labelText: 'Update Quantity Loss',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      SizedBox(height: 10),
                      ElevatedButton.icon(
                        icon: Icon(Icons.save),
                        label: Text('Save Quantity Loss'),
                        onPressed: updateQuantityLoss,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  _buildSection(
                    title: 'Scale Data',
                    children: [
                      // Penimbangan UI (Bluetooth scale)
                      Card(
                        color: Colors.grey[20],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Scale Connection',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: () {},
                                    icon: Icon(
                                      Icons.settings,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                    label: Text(
                                      'Debug',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ),
                                  if (connectedDevice != null)
                                    TextButton.icon(
                                      onPressed: () async {
                                        await bluetoothManager.disconnect();
                                        await _notificationSubscription
                                            ?.cancel();
                                        _notificationSubscription = null;
                                        if (mounted) {
                                          setState(() {
                                            connectedDevice = null;
                                            esp32Weight = null;
                                            bluetoothStatus = "Disconnected";
                                          });
                                        }
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text("Koneksi diputus"),
                                          ),
                                        );
                                      },
                                      icon: Icon(
                                        Icons.bluetooth_disabled,
                                        size: 16,
                                        color: Colors.red,
                                      ),
                                      label: Text(
                                        'Disconnect',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                ],
                              ),
                              SizedBox(height: 24),
                              if (connectedDevice != null) ...[
                                Text('Status Penerimaan:'),
                                SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  value: selectedStatusPenerimaan,
                                  items: ['Normal', 'Reject', 'Retur']
                                      .map(
                                        (status) => DropdownMenuItem(
                                          value: status,
                                          child: Text(status),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      selectedStatusPenerimaan = value;
                                    });
                                  },
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 16),
                                Text('Tipe RM:'),
                                SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  value: selectedTipeRM,
                                  items: (tipeRMOptions[selectedJenisRm] ?? [])
                                      .map(
                                        (tipe) => DropdownMenuItem(
                                          value: tipe,
                                          child: Text(tipe),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      selectedTipeRM = value;
                                    });
                                  },
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 24),
                              ],
                              Center(
                                child:
                                    connectedDevice != null &&
                                        esp32Weight != null
                                    ? _buildConnectedScaleUI()
                                    : _buildConnectionUI(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Riwayat data timbangan (history) - ensure correct API mapping
                      _buildScaleHistorySection(
                        scaleData.fold<double>(
                          0,
                          (sum, item) =>
                              sum +
                              (item['weight'] is num
                                  ? item['weight']
                                  : double.tryParse(
                                          item['weight']?.toString() ?? '0',
                                        ) ??
                                        0),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Faktur: ${widget.data['faktur']}',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 16),
                SizedBox(width: 4),
                Text(widget.data['tanggal_incoming'] ?? ''),
              ],
            ),
            SizedBox(height: 4),
            Text('Created by: Admin CK2', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(value),
    );
  }

  Widget _buildDocumentRow(
    BuildContext context,
    String title, {
    required String? imagePath,
  }) {
    return ListTile(
      title: Text(title),
      trailing: IconButton(
        icon: const Icon(Icons.remove_red_eye),
        onPressed: () {
          if (imagePath != null && imagePath.isNotEmpty) {
            showImageDialog(context, imagePath, title);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Tidak ada gambar untuk $title')),
            );
          }
        },
      ),
    );
  }

  void showImageDialog(BuildContext context, String imagePath, String title) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: EdgeInsets.all(10),
        child: FutureBuilder<Uint8List?>(
          future: _fetchImageBytes(imagePath),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppBar(
                    title: Text(title),
                    automaticallyImplyLeading: false,
                    actions: [
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text("Gagal memuat gambar"),
                  ),
                ],
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBar(
                  title: Text(title),
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                Expanded(
                  child: InteractiveViewer(child: Image.memory(snapshot.data!)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<Uint8List?> _fetchImageBytes(String imagePath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      final url = Uri.parse("https://api-gts-rm.miegacoan.id/$imagePath");

      print("Fetching image: $url");

      final response = await http.get(
        url,
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        print("Gagal load gambar: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Error load gambar: $e");
      return null;
    }
  }

  Widget _buildSection({
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (subtitle != null) ...[
              SizedBox(height: 4),
              Text(subtitle, style: TextStyle(color: Colors.grey)),
            ],
            SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionUI() {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: bluetoothStatus == "Scanning..." ? null : scanForDevices,
          icon: Icon(Icons.bluetooth, color: Colors.blue),
          label: Text('Connect to Scale'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.blue,
            side: BorderSide(color: Colors.blue),
            shape: StadiumBorder(),
            elevation: 0,
          ),
        ),
        SizedBox(height: 32),
        bluetoothStatus == "Scanning..."
            ? CircularProgressIndicator()
            : (bluetoothStatus == "Device(s) found" && foundDevices.isNotEmpty)
            ? Column(
                children: foundDevices.map((device) {
                  return ListTile(
                    title: Text(
                      device.name.isNotEmpty ? device.name : device.id,
                    ),
                    subtitle: Text(device.id),
                    trailing: ElevatedButton(
                      onPressed: () => connectToDevice(device),
                      child: Text('Connect'),
                    ),
                  );
                }).toList(),
              )
            : Column(
                children: [
                  Icon(
                    Icons.bluetooth_disabled,
                    size: 48,
                    color: Colors.blue[400],
                  ),
                  SizedBox(height: 8),
                  Text(
                    bluetoothStatus.isNotEmpty
                        ? bluetoothStatus
                        : "No devices found",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.blue[700],
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Make sure your ESP32 scale is powered on and within range',
                    style: TextStyle(color: Colors.blue[600], fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
      ],
    );
  }

  Widget _buildConnectedScaleUI() {
    double? weight = esp32Weight != null ? double.tryParse(esp32Weight!) : null;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.lightBlue[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.green[100],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'STABLE',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'WEIGHT',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
              letterSpacing: 1.5,
            ),
          ),
          SizedBox(height: 8),
          Text(
            weight != null ? '${weight.toStringAsFixed(2)} kg' : '- kg',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: (weight != null && weight < 0) ? Colors.red : Colors.black,
            ),
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  'TOTAL WEIGHT RECEIVED',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  receivedWeight != null
                      ? '${receivedWeight!.toStringAsFixed(2)} kg'
                      : '- kg',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: (receivedWeight ?? 0) < 0
                        ? Colors.red
                        : Colors.green[900],
                  ),
                ),
                Text(
                  '(${receivedList.length} reading${receivedList.length > 1 ? 's' : ''})',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              if (esp32Weight == null ||
                  selectedTipeRM == null ||
                  selectedStatusPenerimaan == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Lengkapi data timbangan terlebih dahulu'),
                  ),
                );
                return;
              }

              final parsedWeight = double.tryParse(esp32Weight ?? '');
              if (parsedWeight == null) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Berat tidak valid')));
                return;
              }

              setState(() {
                receivedWeight = parsedWeight;
              });

              final token = await getToken();
              if (token == null || token.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Token tidak ditemukan')),
                );
                return;
              }

              if (selectedJenisRm == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Jenis RM belum dipilih')),
                );
                return;
              }

              final fakturBaru = widget.data['faktur'];
              if (fakturBaru == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Faktur tidak ditemukan. Klik Submit terlebih dahulu.',
                    ),
                  ),
                );
                return;
              }

              final response = await http.post(
                Uri.parse(
                  'https://api-gts-rm.miegacoan.id/gtsrm/api/timbangan?Faktur=$fakturBaru',
                ),
                headers: {
                  'Authorization': 'Bearer $token',
                  'Content-Type': 'application/json',
                },
                body: jsonEncode({
                  "weight": parsedWeight.toStringAsFixed(2),
                  "status": selectedStatusPenerimaan,
                  "type_rm": selectedTipeRM,
                }),
              );

              if (response.statusCode == 200 || response.statusCode == 201) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Data timbangan berhasil dikirim')),
                );

                setState(() {
                  receivedList.add({
                    "weight": parsedWeight.toStringAsFixed(2),
                    "status": selectedStatusPenerimaan,
                    "type_rm": selectedTipeRM,
                    "time": DateTime.now().toString(),
                  });
                });
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Gagal kirim data timbangan: ${response.body}',
                    ),
                  ),
                );
              }
            },

            icon: Icon(Icons.download),
            label: Text('Receive'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: StadiumBorder(),
              minimumSize: Size(double.infinity, 48),
            ),
          ),
          if (receivedList.isNotEmpty) ...[
            SizedBox(height: 20),
            Text(
              "Riwayat Penerimaan",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            DataTable(
              columns: const [
                DataColumn(label: Text("No")),
                DataColumn(label: Text("Berat (kg)")),
                DataColumn(label: Text("Status")),
                DataColumn(label: Text("Tipe RM")),
                DataColumn(label: Text("Waktu")),
              ],
              rows: List.generate(receivedList.length, (index) {
                final row = receivedList[index];
                return DataRow(
                  cells: [
                    DataCell(Text("${index + 1}")),
                    DataCell(Text(row["weight"])),
                    DataCell(Text(row["status"] ?? "-")),
                    DataCell(Text(row["type_rm"] ?? "-")),
                    DataCell(Text(row["time"])),
                  ],
                );
              }),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScaleHistorySection(double totalWeight) {
    return _buildSection(
      title: 'Riwayat Data Timbangan',
      children: [
        if (isLoading)
          const Center(child: CircularProgressIndicator())
        else
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildInfoBadge(
                    "Total: ${totalWeight.toStringAsFixed(2)} kg",
                    Colors.green.shade100,
                  ),
                  _buildInfoBadge(
                    "Penimbangan: ${scaleData.length} kali",
                    Colors.green.shade100,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              if (scaleData.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  alignment: Alignment.center,
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: 8),
                      Icon(Icons.scale, size: 50, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        'No scale data available',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              else
                ...scaleData.map((item) {
                  final typeRm = item['type_rm'] ?? 'Unknown RM';
                  final weight = item['weight'] ?? 0;
                  final status = item['status'] ?? 'Unknown';
                  final dateTime = item['date_time'] ?? '';
                  return ListTile(
                    leading: Icon(
                      status.toString().toLowerCase() == 'retur'
                          ? Icons.close
                          : Icons.check_circle,
                      color: status.toString().toLowerCase() == 'retur'
                          ? Colors.red
                          : Colors.green,
                    ),
                    title: Text("$typeRm - ${weight.toString()} Kg"),
                    subtitle: Text("Status: $status\n$dateTime"),
                  );
                }).toList(),
            ],
          ),
      ],
    );
  }

  Widget _buildInfoBadge(String label, Color backgroundColor) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.green,
        ),
      ),
    );
  }
}

class UploadRow extends StatefulWidget {
  final String label;
  final Function(XFile?) onFilePicked;

  const UploadRow({required this.label, required this.onFilePicked, Key? key})
    : super(key: key);

  @override
  _UploadRowState createState() => _UploadRowState();
}

class _UploadRowState extends State<UploadRow> {
  XFile? _pickedFile;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickFile() async {
    final ImagePicker picker = ImagePicker();

    Future<void> handlePick(ImageSource source) async {
      final XFile? image = await picker.pickImage(source: source);
      if (image != null && mounted) {
        setState(() => _pickedFile = image);
        widget.onFilePicked(image);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Selected file: ${image.name}')));
      }
    }

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pilih Sumber Gambar'),
          content: const Text('Ambil gambar dari kamera atau galeri?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                handlePick(ImageSource.camera);
              },
              child: const Text('Kamera'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                handlePick(ImageSource.gallery);
              },
              child: const Text('Galeri'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.label,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  _pickedFile?.name ?? 'No file selected',
                  style: TextStyle(color: Colors.grey[600]),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: _pickFile,
            icon: Icon(Icons.cloud_upload_outlined),
            label: Text('Choose File'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
