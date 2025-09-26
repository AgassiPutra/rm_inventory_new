import 'package:flutter/material.dart';
import '../widgets/custom_drawer.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../utils/auth.dart';
import 'package:flutter/foundation.dart';
import 'package:rm_inventory_new/ble/bluetooth_manager_web.dart' as web;
import 'dart:html' as html;
import '../ble/permission_handler.dart';
import '../models/app_bluetooth_device.dart';

class Menu1Page extends StatefulWidget {
  @override
  State<Menu1Page> createState() => _Menu1PageState();
}

class _Menu1PageState extends State<Menu1Page> {
  bool isLoadingSuppliers = false;
  late String currentTime;
  late TextEditingController currentTimeController;
  late TextEditingController shiftController;
  late TextEditingController produsenController;
  TextEditingController qtyPoController = TextEditingController();
  List<Map<String, dynamic>> suppliers = [];
  List<Map<String, dynamic>> allSuppliers = [];
  StreamSubscription<String>? _notificationSubscription;
  late web.BluetoothManagerWeb bluetoothManager;
  List<Map<String, dynamic>> receivedList = [];
  List<String> get jenisList {
    final jenisSet = suppliers.map((s) => s['jenis_rm'] as String).toSet();
    return jenisSet.toList();
  }

  List<String> get filteredSuppliers {
    if (selectedJenisRm == null) return [];
    return suppliers
        .where((s) => s['jenis_rm'] == selectedJenisRm)
        .map((s) => s['supplier'] as String)
        .toList();
  }

  List<String> jenisRmList = [];

  void updateJenisRmList() {
    final distinctJenis = suppliers.map((e) => e['jenis_rm'] as String).toSet();
    setState(() {
      jenisRmList = distinctJenis.toList();
    });
  }

  bool isSaving = false;
  bool get isFormComplete {
    return invoiceFile != null &&
        suratJalanFile != null &&
        selectedJenisRm != null &&
        selectedSupplier != null &&
        qtyPoController.text.isNotEmpty;
  }

  String? selectedJenisRm;
  String? selectedSupplier;
  String qtyPo = '';
  String produsen = '';
  String? esp32Weight;
  String? selectedStatusPenerimaan;
  String? selectedTipeRM;
  String? lastSubmittedFaktur;
  double? receivedWeight;
  bool isReceivingWeight = false;

  final ImagePicker _picker = ImagePicker();

  XFile? invoiceFile;
  XFile? suratJalanFile;

  List<AppBluetoothDevice> foundDevices = [];
  AppBluetoothDevice? connectedDevice;
  String bluetoothStatus = "No scales found";

  @override
  void initState() {
    super.initState();
    Auth.check(context);

    final now = DateTime.now();
    currentTime =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    currentTimeController = TextEditingController(text: currentTime);
    shiftController = TextEditingController(text: 'Shift 2');
    qtyPoController = TextEditingController();
    produsenController = TextEditingController();
    bluetoothManager = web.BluetoothManagerWeb();
    fetchSuppliers();
  }

  @override
  void dispose() {
    currentTimeController.dispose();
    shiftController.dispose();
    qtyPoController.dispose();
    produsenController.dispose();
    _notificationSubscription?.cancel();
    bluetoothManager.dispose();
    super.dispose();
  }

  final Map<String, List<String>> tipeRMOptions = {
    'WET CHICKEN': ['Boneless Dada (BLD)', 'Boneless Paha Kulit (BLPK)'],
    'SAYURAN': ['Wortel', 'Bawang', 'Jamur'],
    'DRY': ['Bumbu', 'Tepung', 'Lainnya'],
    'ICE': ['Es Batu', 'Ice Cube'],
    'UDANG': ['Udang Fresh', 'Udang Beku'],
  };

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _pickImage(Function(XFile?) onPicked) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    onPicked(image);
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
          if (weightData == 'SAVE_SIGNAL') {
            if (mounted) {
              _receiveWeightReading();
            }
            return;
          }
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
            debugPrint("Gagal parsing data: '$weightData', error: $e");
            if (mounted) {
              setState(() {
                esp32Weight = null;
                bluetoothStatus = "Data berat tidak valid dari ${device.name}";
              });
            }
          }
        },
        onError: (error) {
          debugPrint("Error di weightStream: $error");
          if (mounted) {
            setState(() {
              bluetoothStatus = "Error menerima data: $error";
            });
          }
        },
        onDone: () {
          debugPrint("Stream berat ditutup, kemungkinan perangkat terputus");
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
      debugPrint("Error menghubungkan ke perangkat: $e");
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

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    print('Token from SharedPreferences: $token');
    return token;
  }

  Future<void> fetchSuppliers() async {
    final token = await getToken();
    print('Token dari SharedPreferences: $token');

    if (token == null || token.isEmpty) {
      print('Token tidak ditemukan, user harus login');
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('https://api-gts-rm.miegacoan.id/gtsrm/api/supplier'),
        headers: {'Authorization': 'Bearer $token'},
      );

      print("Status code: ${response.statusCode}");
      print("Response body: ${response.body}");

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List<dynamic> data = body['data'];

        setState(() {
          suppliers = data.map<Map<String, dynamic>>((item) {
            return {
              'kode_supplier': item['kode_supplier'],
              'supplier': item['supplier'],
              'produsen': item['nama_pabrik'],
              'satuan': item['satuan'],
              'jenis_rm': item['jenis_rm'],
              'jenis_ayam': item['jenis_ayam'],
            };
          }).toList();
          final distinctJenis = suppliers
              .map((e) => e['jenis_rm'] as String)
              .toSet();
          jenisRmList = distinctJenis.toList();
        });

        print("Suppliers berhasil dimuat: ${suppliers.length} item");
        print("Jenis RM unik: $jenisRmList");
      } else {
        print('Failed to load suppliers: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e) {
      print("Error fetchSuppliers: $e");
    }
  }

  Future<String?> _getLastFaktur() async {
    return lastSubmittedFaktur;
  }

  Future<void> submitData() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Token tidak ditemukan. Silakan login ulang.'),
        ),
      );
      return;
    }

    final qtyPo = qtyPoController.text;
    if (selectedJenisRm == null || qtyPo.isEmpty || selectedSupplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap lengkapi semua field')),
      );
      return;
    }

    final uri = Uri.parse(
      'https://api-gts-rm.miegacoan.id/gtsrm/api/incoming-rm',
    );
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['jenis_rm'] = selectedJenisRm!
      ..fields['qty_po'] = qtyPo
      ..fields['supplier'] = selectedSupplier!
      ..fields['produsen'] = produsen;

    if (kIsWeb) {
      if (invoiceFile != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'invoice_supplier',
            await invoiceFile!.readAsBytes(),
            filename: invoiceFile!.name,
          ),
        );
      }

      if (suratJalanFile != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'surat_jalan',
            await suratJalanFile!.readAsBytes(),
            filename: suratJalanFile!.name,
          ),
        );
      }
    } else {
      if (invoiceFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'invoice_supplier',
            invoiceFile!.path,
            filename: invoiceFile!.path.split('/').last,
          ),
        );
      }

      if (suratJalanFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'surat_jalan',
            suratJalanFile!.path,
            filename: suratJalanFile!.path.split('/').last,
          ),
        );
      }
    }

    try {
      final response = await request.send();
      final resBody = await response.stream.bytesToString();

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonRes = jsonDecode(resBody);
        debugPrint("Raw Response Incoming-RM: $jsonRes");

        final fakturBaru = jsonRes['data']?['faktur'];
        lastSubmittedFaktur = fakturBaru;

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Data berhasil dikirim')));
      } else {
        String errorMsg = 'Gagal kirim';
        try {
          final errJson = jsonDecode(resBody);
          if (errJson is Map && errJson['error'] is String) {
            errorMsg = errJson['error'];
          }
        } catch (_) {
          errorMsg = resBody;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMsg)));
      }
    } catch (e) {
      debugPrint("Error: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _receiveWeightReading() {
    if (isReceivingWeight) return;

    setState(() {
      isReceivingWeight = true;
    });
    final currentWeight = esp32Weight != null
        ? double.tryParse(esp32Weight!)
        : null;

    if (currentWeight == null) {
      _showSnackBar(
        'Timbangan belum terhubung atau data berat tidak valid.',
        isError: true,
      );
      setState(() => isReceivingWeight = false);
      return;
    }
    if (currentWeight <= 0.0) {
      _showSnackBar('Berat harus lebih besar dari nol.', isError: true);
      setState(() => isReceivingWeight = false);
      return;
    }

    if (selectedStatusPenerimaan == null || selectedTipeRM == null) {
      _showSnackBar(
        'Harap lengkapi Status Penerimaan dan Tipe RM.',
        isError: true,
      );
      setState(() => isReceivingWeight = false);
      return;
    }
    final newReading = {
      'weight': currentWeight,
      'time': DateTime.now().toIso8601String(),
      'status': selectedStatusPenerimaan!,
      'tipeRM': selectedTipeRM!,
    };

    setState(() {
      receivedList.add(newReading);
      receivedWeight = receivedList.fold<double>(0.0, (sum, item) {
        final weight = double.tryParse(item['weight'] as String) ?? 0.0;
        return sum + weight;
      });
      isReceivingWeight = false;
    });
    _showSnackBar(
      'Berat ${currentWeight.toStringAsFixed(2)} kg berhasil di-receive. Total: ${(receivedWeight ?? 0.0).toStringAsFixed(2)} kg.',
    );
  }

  void resetForm() {
    setState(() {
      selectedJenisRm = null;
      qtyPoController.clear();
      selectedSupplier = null;
      produsenController.clear();
      invoiceFile = null;
      suratJalanFile = null;
      currentTimeController.text = currentTime;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Raw Material Incoming Form'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              final now = DateTime.now();
              setState(() {
                currentTime =
                    "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
                currentTimeController.text = currentTime;
              });
            },
          ),
          IconButton(icon: Icon(Icons.person), onPressed: () {}),
        ],
      ),
      drawer: CustomDrawer(),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 4),
                        TextField(
                          enabled: false,
                          controller: currentTimeController,
                          decoration: InputDecoration(
                            labelText: 'Current Time',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 4),
                        TextField(
                          enabled: false,
                          controller: shiftController,
                          decoration: InputDecoration(
                            labelText: 'Current Shift',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            if (connectedDevice != null) ...[
              Card(
                color: invoiceFile == null
                    ? Colors.red[100]
                    : Colors.green[100],
                margin: EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Upload Invoice Supplier',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 8),
                            Text(
                              invoiceFile == null
                                  ? 'Selected File\nNo file selected'
                                  : 'Selected File\n${invoiceFile!.name}',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          _pickImage((file) {
                            setState(() {
                              invoiceFile = file;
                            });
                          });
                        },
                        child: Text('Choose File'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Card(
                color: suratJalanFile == null
                    ? Colors.red[100]
                    : Colors.green[100],
                margin: EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Upload Surat Jalan',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 8),
                            Text(
                              suratJalanFile == null
                                  ? 'Selected File\nNo file selected'
                                  : 'Selected File\n${suratJalanFile!.name}',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          _pickImage((file) {
                            setState(() {
                              suratJalanFile = file;
                            });
                          });
                        },
                        child: Text('Choose File'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Jenis RM',
                  border: OutlineInputBorder(),
                ),
                value:
                    (selectedJenisRm != null &&
                        jenisRmList.contains(selectedJenisRm))
                    ? selectedJenisRm
                    : null,
                items: jenisRmList
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                hint: const Text("Pilih Jenis RM"),
                onChanged: (v) {
                  setState(() {
                    selectedJenisRm = v;
                    selectedSupplier = null;
                    produsenController.clear();
                  });
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: qtyPoController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Qty PO',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 12),
              isLoadingSuppliers
                  ? const Center(child: CircularProgressIndicator())
                  : DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Supplier',
                        border: OutlineInputBorder(),
                      ),
                      value:
                          (selectedSupplier != null &&
                              suppliers.any(
                                (item) => item['supplier'] == selectedSupplier,
                              ))
                          ? selectedSupplier
                          : null,
                      hint: const Text('Pilih Supplier'),
                      items: suppliers
                          .where((item) => item['jenis_rm'] == selectedJenisRm)
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: item['supplier'] as String,
                              child: Text(item['supplier'] as String),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;

                        setState(() {
                          selectedSupplier = value;

                          final selected = suppliers.firstWhere(
                            (item) => item['supplier'] == value,
                            orElse: () => {'supplier': '', 'produsen': ''},
                          );
                          final produsenValue =
                              (selected['produsen'] as String?)?.isNotEmpty ==
                                  true
                              ? selected['produsen'] as String
                              : selected['supplier'] as String;

                          produsen = produsenValue;
                          produsenController.text = produsen;
                        });
                      },
                    ),

              const SizedBox(height: 12),
              TextFormField(
                controller: produsenController,
                enabled: false,
                decoration: InputDecoration(
                  labelText: 'Produsen',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.grey[200],
                ),
              ),
              SizedBox(height: 24),
              Center(
                child: ElevatedButton(
                  onPressed: (!isFormComplete || isSaving)
                      ? null
                      : () async {
                          setState(() => isSaving = true);

                          await submitData();

                          setState(() => isSaving = false);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (!isFormComplete || isSaving)
                        ? Colors.grey
                        : Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize: Size(120, 48),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Submit'),
                ),
              ),
            ],
            SizedBox(height: 32),
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
                              await _notificationSubscription?.cancel();
                              _notificationSubscription = null;

                              if (mounted) {
                                setState(() {
                                  connectedDevice = null;
                                  esp32Weight = null;
                                  bluetoothStatus = "Disconnected";
                                });
                              }

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Koneksi diputus")),
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
                      child: connectedDevice != null && esp32Weight != null
                          ? _buildConnectedScaleUI()
                          : _buildConnectionUI(),
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
                  '${(receivedWeight ?? 0.0).toStringAsFixed(2)} kg',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: (receivedWeight ?? 0.0) < 0
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
            onPressed:
                (weight == null ||
                    selectedTipeRM == null ||
                    selectedStatusPenerimaan == null ||
                    isReceivingWeight)
                ? null
                : () async {
                    setState(() => isReceivingWeight = true);

                    final parsedWeight = double.tryParse(esp32Weight ?? '');
                    if (parsedWeight == null || parsedWeight <= 0.0) {
                      _showSnackBar(
                        'Berat tidak valid atau nol.',
                        isError: true,
                      );
                      setState(() => isReceivingWeight = false);
                      return;
                    }

                    final fakturBaru = await _getLastFaktur();
                    if (fakturBaru == null) {
                      _showSnackBar(
                        'Faktur tidak ditemukan. Klik Submit form utama terlebih dahulu.',
                        isError: true,
                      );
                      setState(() => isReceivingWeight = false);
                      return;
                    }

                    final token = await getToken();
                    if (token == null || token.isEmpty) {
                      _showSnackBar(
                        'Token tidak ditemukan. Silakan login ulang.',
                        isError: true,
                      );
                      setState(() => isReceivingWeight = false);
                      return;
                    }
                    try {
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
                      if (response.statusCode == 200 ||
                          response.statusCode == 201) {
                        setState(() {
                          receivedList.add({
                            "weight": parsedWeight.toStringAsFixed(2),
                            "status": selectedStatusPenerimaan,
                            "type_rm": selectedTipeRM,
                            "time": DateTime.now().toString().substring(0, 19),
                          });
                          receivedWeight =
                              (receivedWeight ?? 0.0) + parsedWeight;
                        });

                        _showSnackBar(
                          'Data timbangan ${parsedWeight.toStringAsFixed(2)} kg berhasil dikirim.',
                        );
                      } else {
                        String errorMsg =
                            jsonDecode(response.body)['message'] ??
                            'Gagal kirim data timbangan';
                        _showSnackBar('Gagal kirim: $errorMsg', isError: true);
                      }
                    } catch (e) {
                      debugPrint("Error submit weight: $e");
                      _showSnackBar(
                        'Terjadi kesalahan koneksi.',
                        isError: true,
                      );
                    } finally {
                      if (mounted) {
                        setState(() => isReceivingWeight = false);
                      }
                    }
                  },
            icon: isReceivingWeight
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.download),
            label: Text(isReceivingWeight ? 'Receiving...' : 'Receive Weight'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isReceivingWeight
                  ? Colors.blueGrey
                  : Colors.green,
              foregroundColor: Colors.white,
              shape: StadiumBorder(),
              minimumSize: Size(double.infinity, 48),
            ),
          ),
          if (receivedList.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              "Riwayat Penerimaan",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
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
                      DataCell(
                        Text(
                          DateTime.parse(
                            row["time"] as String,
                          ).toString().substring(11, 19),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConnectionUI() {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: bluetoothStatus == "Scanning..." ? null : scanForDevices,
          icon: Icon(Icons.bluetooth, color: Colors.grey),
          label: Text('Connect to Scale'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.grey,
            side: BorderSide(color: Colors.grey),
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
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 8),
                  Text(
                    bluetoothStatus.isNotEmpty
                        ? bluetoothStatus
                        : "No devices found",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Make sure your ESP32 scale is powered on and within range',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
      ],
    );
  }
}
