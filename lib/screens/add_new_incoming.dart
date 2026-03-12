import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../utils/auth.dart';
import '../widgets/custom_drawer.dart';
import 'package:rm_inventory_new/ble/bluetooth_manager_web.dart' as web;
import '../ble/permission_handler.dart';
import '../models/app_bluetooth_device.dart';
import '../db/hive_service.dart';
import '../models/upload_queue.dart';
import 'package:uuid/uuid.dart';

class AddNewIncomingPage extends StatefulWidget {
  const AddNewIncomingPage({super.key});

  @override
  State<AddNewIncomingPage> createState() => _AddNewIncomingPageState();
}

class _AddNewIncomingPageState extends State<AddNewIncomingPage> {
  final Auth authService = Auth();
  final Uuid _uuid = Uuid();
  late Timer _timeUpdateTimer;
  late TextEditingController currentTimeController;
  late TextEditingController shiftController;
  String? selectedUnit;
  String? selectedRmType;
  String? selectedSupplier;
  TextEditingController qtyPoController = TextEditingController();
  TextEditingController produsenController = TextEditingController();

  List<Map<String, dynamic>> suppliers = [];
  List<String> jenisRmList = [];
  bool isLoadingSuppliers = false;
  XFile? invoiceFile;
  XFile? suratJalanFile;
  final ImagePicker _picker = ImagePicker();
  late web.BluetoothManagerWeb bluetoothManager;
  List<AppBluetoothDevice> foundDevices = [];
  AppBluetoothDevice? connectedDevice;
  String bluetoothStatus = 'No scales found';
  StreamSubscription<String>? _notificationSubscription;
  String? esp32Weight;
  bool isReceivingWeight = false;
  double? receivedWeight;
  List<Map<String, dynamic>> receivedList = [];
  String? lastSubmittedFaktur;
  bool isSaving = false;

  bool get isFormComplete =>
      invoiceFile != null &&
      suratJalanFile != null &&
      selectedRmType != null &&
      selectedSupplier != null &&
      qtyPoController.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    Auth.check(context);
    currentTimeController = TextEditingController();
    shiftController = TextEditingController();
    bluetoothManager = web.BluetoothManagerWeb();
    _updateTime();
    _timeUpdateTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) _updateTime();
    });
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
    _timeUpdateTimer.cancel();
    super.dispose();
  }

  String _shiftFromTime(String time) {
    final parts = time.split(':');
    final h = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final total = h * 60 + m;
    if (total >= 6 * 60 && total < 14 * 60) return 'Shift 1';
    if (total >= 14 * 60 && total < 22 * 60) return 'Shift 2';
    return 'Shift 3';
  }

  void _updateTime() {
    final now = DateTime.now();
    final t =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    currentTimeController.text = t;
    shiftController.text = _shiftFromTime(t);
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> fetchSuppliers() async {
    final token = await _getToken();
    if (token == null || token.isEmpty) return;
    setState(() => isLoadingSuppliers = true);
    try {
      final response = await http.get(
        Uri.parse('https://api-gts-rm.miegacoan.id/gtsrm/api/supplier'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (!mounted) return;
      if (await Auth.handle401(context, response)) return;
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
            };
          }).toList();
          jenisRmList = suppliers
              .map((e) => e['jenis_rm'] as String)
              .toSet()
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetchSuppliers: $e');
    } finally {
      if (mounted) setState(() => isLoadingSuppliers = false);
    }
  }

  Future<void> scanForDevices() async {
    bool granted = await PermissionHelper.requestBluetoothPermissions();
    if (!granted) {
      setState(() => bluetoothStatus = 'Permissions denied');
      return;
    }
    setState(() {
      foundDevices.clear();
      bluetoothStatus = 'Scanning...';
    });
    await bluetoothManager.scanForDevices();
    setState(() {
      foundDevices
        ..clear()
        ..addAll(bluetoothManager.foundDevices);
      bluetoothStatus = bluetoothManager.foundDevices.isEmpty
          ? bluetoothManager.status
          : 'Device(s) found';
    });
  }

  Future<void> connectToDevice(AppBluetoothDevice device) async {
    try {
      setState(() {
        bluetoothStatus = 'Menghubungkan ke ${device.name}...';
        connectedDevice = null;
        esp32Weight = null;
      });

      await bluetoothManager
          .connectToDevice(device)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException('Gagal menghubungkan: Waktu tunggu habis');
            },
          );

      await _notificationSubscription?.cancel();
      _notificationSubscription = null;
      _notificationSubscription = bluetoothManager.weightStream.listen(
        (weightData) {
          if (weightData.startsWith('SAVE_SIGNAL')) {
            final parts = weightData.split(':');
            if (parts.length == 2 && parts[1].isNotEmpty) {
              final parsedWeight = double.tryParse(parts[1]);
              if (parsedWeight != null && parsedWeight > 0) {
                if (mounted) _saveWeightDirectly(parsedWeight);
                return;
              }
            }
            if (mounted) _saveCurrentWeight();
            return;
          }
          final weight = double.tryParse(weightData.trim());
          if (weight != null) {
            if (mounted) {
              setState(() {
                esp32Weight = weight.toStringAsFixed(2);
                bluetoothStatus =
                    'Terhubung ke ${device.name} | Berat: ${esp32Weight} kg';
              });
            }
          }
        },
        onError: (e) {
          debugPrint('weightStream error: $e');
          if (mounted) setState(() => bluetoothStatus = 'Error: $e');
        },
        onDone: () {
          if (mounted) {
            setState(() {
              connectedDevice = null;
              esp32Weight = null;
              bluetoothStatus = 'Perangkat terputus';
            });
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted && connectedDevice == null) {
                connectToDevice(device);
              }
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          connectedDevice = device;
          bluetoothStatus = 'Terhubung ke ${device.name}';
        });
      }
    } catch (e) {
      debugPrint('Error connect: $e');
      if (mounted) {
        setState(() {
          connectedDevice = null;
          esp32Weight = null;
          bluetoothStatus = 'Gagal menghubungkan: $e';
        });
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && connectedDevice == null) connectToDevice(device);
        });
      }
    }
  }

  Future<void> submitData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final userId = prefs.getString('user_id') ?? 'guest';

    if (token == null || token.isEmpty) {
      _showSnackBar(
        'Token tidak ditemukan. Silakan login ulang.',
        isError: true,
      );
      return;
    }

    if (selectedRmType == null ||
        selectedSupplier == null ||
        qtyPoController.text.isEmpty) {
      _showSnackBar('Harap lengkapi semua field', isError: true);
      return;
    }

    const apiEndpoint = 'gtsrm/api/incoming-rm';
    final apiEndpointFull = 'https://api-gts-rm.miegacoan.id/$apiEndpoint';

    final Map<String, dynamic> requestFields = {
      'jenis_rm': selectedRmType!,
      'qty_po': qtyPoController.text,
      'supplier': selectedSupplier!,
      'produsen': produsenController.text,
    };

    final uri = Uri.parse(apiEndpointFull);
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token';

    requestFields.forEach((k, v) => request.fields[k] = v.toString());

    final List<String> fileContentsBase64 = [];

    if (kIsWeb) {
      if (invoiceFile != null) {
        final bytes = await invoiceFile!.readAsBytes();
        fileContentsBase64.add(base64Encode(bytes));
        request.files.add(
          http.MultipartFile.fromBytes(
            'invoice_supplier',
            bytes,
            filename: invoiceFile!.name,
          ),
        );
      }
      if (suratJalanFile != null) {
        final bytes = await suratJalanFile!.readAsBytes();
        fileContentsBase64.add(base64Encode(bytes));
        request.files.add(
          http.MultipartFile.fromBytes(
            'surat_jalan',
            bytes,
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

      if (response.statusCode == 401) {
        await Auth.logout(context);
        return;
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonRes = jsonDecode(resBody);
        final fakturServer = jsonRes['data']?['faktur'];
        if (mounted) {
          setState(() => lastSubmittedFaktur = fakturServer);
        }
        _showSnackBar('Data berhasil dikirim');
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
        throw Exception(errorMsg);
      }
    } catch (e) {
      debugPrint('Error submit: $e. Saving to queue.');
      String fakturId = lastSubmittedFaktur ?? 'UUID-${_uuid.v4()}';
      if (lastSubmittedFaktur == null) {
        setState(() => lastSubmittedFaktur = fakturId);
      }
      final hiveService = HiveService.instance;
      final queueItem = UploadQueue(
        userId: userId,
        apiEndpoint: apiEndpoint,
        requestBodyJson: jsonEncode(requestFields),
        fileContentsBase64: fileContentsBase64,
        status: 'PENDING',
        menuType: 'MENU1_FORM_UTAMA',
        isMultipart: true,
        token: token,
        createdAt: DateTime.now(),
        method: 'POST',
        fakturLocalId: fakturId,
      );
      await hiveService.addItemToQueue(queueItem);
      _showSnackBar(
        'Gagal kirim. Data disimpan lokal (Offline).',
        isError: true,
      );
    }
  }

  Future<void> _saveWeightDirectly(double weight) async {
    if (isReceivingWeight) return;
    setState(() => isReceivingWeight = true);
    if (lastSubmittedFaktur == null) {
      _showSnackBar(
        'Faktur belum disubmit. Harap Submit form utama terlebih dahulu.',
        isError: true,
      );
      setState(() => isReceivingWeight = false);
      return;
    }
    await _postWeight(weight);
  }

  Future<void> _saveCurrentWeight() async {
    if (isReceivingWeight) return;
    final parsedWeight = double.tryParse(esp32Weight ?? '');
    if (parsedWeight == null || parsedWeight <= 0.0) {
      _showSnackBar('Berat tidak valid atau nol.', isError: true);
      return;
    }
    setState(() => isReceivingWeight = true);
    if (lastSubmittedFaktur == null) {
      _showSnackBar(
        'Faktur belum disubmit. Harap Submit form utama terlebih dahulu.',
        isError: true,
      );
      setState(() => isReceivingWeight = false);
      return;
    }
    await _postWeight(parsedWeight);
  }

  Future<void> _postWeight(double weight) async {
    final token = await _getToken();
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? 'guest';

    if (token == null || token.isEmpty) {
      _showSnackBar('Token tidak ditemukan.', isError: true);
      setState(() => isReceivingWeight = false);
      return;
    }

    final hiveService = HiveService.instance;
    final serverFaktur = await hiveService.getServerFaktur(
      lastSubmittedFaktur!,
    );
    final fakturToUse = serverFaktur ?? lastSubmittedFaktur;
    final apiEndpoint = 'gtsrm/api/timbangan?faktur=$fakturToUse';
    final weightData = {'weight': weight.toStringAsFixed(2)};

    try {
      final response = await http.post(
        Uri.parse('https://api-gts-rm.miegacoan.id/$apiEndpoint'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(weightData),
      );
      if (await Auth.handle401(context, response)) {
        setState(() => isReceivingWeight = false);
        return;
      }
      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSnackBar(
          'Data timbangan ${weight.toStringAsFixed(2)} kg berhasil dikirim.',
        );
      } else {
        throw Exception(
          jsonDecode(response.body)['message'] ?? 'Gagal kirim data timbangan',
        );
      }
    } catch (e) {
      debugPrint('Error weight: $e. Saving to queue.');
      final queueItem = UploadQueue(
        userId: userId,
        apiEndpoint: apiEndpoint,
        requestBodyJson: jsonEncode(weightData),
        fileContentsBase64: const [],
        status: 'PENDING',
        menuType: 'MENU1_TIMBANGAN',
        isMultipart: false,
        token: token,
        createdAt: DateTime.now(),
        method: 'POST',
        fakturLocalId: lastSubmittedFaktur!,
      );
      await hiveService.addItemToQueue(queueItem);
      _showSnackBar(
        'Timbangan disimpan lokal. Akan disinkronkan.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          receivedList.add({
            'weight': weight.toStringAsFixed(2),
            'time': DateTime.now().toString().substring(0, 19),
          });
          receivedWeight = (receivedWeight ?? 0.0) + weight;
          isReceivingWeight = false;
        });
        try {
          await bluetoothManager.turnOnLed();
        } catch (e) {
          debugPrint('LED error: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _buildAppBar(),
      drawer: const CustomDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildShiftSection(),
            const SizedBox(height: 16),
            _buildMidRow(),
            const SizedBox(height: 16),
            _buildScaleSection(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      titleSpacing: 0,
      title: const Text(
        'Add New Incoming',
        style: TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      actions: [
        Stack(
          alignment: Alignment.topRight,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications, color: Color(0xFFE91E8C)),
              onPressed: () {},
            ),
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: InkWell(
            onTap: () {},
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFFE91E8C).withOpacity(0.15),
                  child: const Icon(
                    Icons.person,
                    color: Color(0xFFE91E8C),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 6),
                FutureBuilder<SharedPreferences>(
                  future: SharedPreferences.getInstance(),
                  builder: (context, snap) {
                    final name = snap.data?.getString('email') ?? 'Annesa Ayu';
                    return Text(
                      name,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShiftSection() {
    return _cardWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.access_time_outlined, 'Shift Information'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _labeledField(
                  label: 'Current Time',
                  child: TextField(
                    controller: currentTimeController,
                    enabled: false,
                    style: const TextStyle(fontSize: 15),
                    decoration: _inputDecoration(hint: ''),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _labeledField(
                  label: 'Current Shift',
                  child: TextField(
                    controller: shiftController,
                    enabled: false,
                    style: const TextStyle(fontSize: 15),
                    decoration: _inputDecoration(hint: ''),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMidRow() {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Document Upload
          Expanded(child: _buildDocumentSection()),
          const SizedBox(width: 12),
          // Material Information
          Expanded(child: _buildMaterialSection()),
        ],
      ),
    );
  }

  Widget _buildDocumentSection() {
    return _cardWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.upload_file_outlined, 'Document Upload'),
          const SizedBox(height: 12),
          _fileUploadTile(
            label: 'Invoice Supplier',
            file: invoiceFile,
            onTap: () async {
              final XFile? file = await _picker.pickImage(
                source: ImageSource.gallery,
              );
              if (file != null) setState(() => invoiceFile = file);
            },
          ),
          const SizedBox(height: 12),
          _fileUploadTile(
            label: 'Surat Jalan',
            file: suratJalanFile,
            onTap: () async {
              final XFile? file = await _picker.pickImage(
                source: ImageSource.gallery,
              );
              if (file != null) setState(() => suratJalanFile = file);
            },
          ),
        ],
      ),
    );
  }

  Widget _fileUploadTile({
    required String label,
    required XFile? file,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            decoration: BoxDecoration(
              border: Border.all(
                color: file != null ? Colors.green : Colors.grey.shade300,
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(8),
              color: file != null
                  ? Colors.green.withOpacity(0.05)
                  : Colors.grey.shade50,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_upload_outlined,
                  size: 28,
                  color: file != null ? Colors.green : Colors.grey.shade400,
                ),
                const SizedBox(height: 4),
                file == null
                    ? RichText(
                        textAlign: TextAlign.center,
                        text: const TextSpan(
                          style: TextStyle(fontSize: 11),
                          children: [
                            TextSpan(
                              text: 'Click to upload',
                              style: TextStyle(
                                color: Color(0xFF4A90D9),
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            TextSpan(
                              text: ' or drag and drop',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : Text(
                        file.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                const SizedBox(height: 2),
                if (file == null)
                  const Text(
                    'JPG, PDF',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMaterialSection() {
    return _cardWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.layers_outlined, 'Material Information'),
          const SizedBox(height: 12),
          // Unit & RM Type row
          Row(
            children: [
              Expanded(
                child: _labeledField(
                  label: 'Unit',
                  child: DropdownButtonFormField<String>(
                    value: selectedUnit,
                    hint: const Text('Unit', style: TextStyle(fontSize: 13)),
                    items: const [
                      DropdownMenuItem(value: 'KG', child: Text('KG')),
                      DropdownMenuItem(value: 'PCS', child: Text('PCS')),
                      DropdownMenuItem(value: 'LITER', child: Text('LITER')),
                    ],
                    onChanged: (v) => setState(() => selectedUnit = v),
                    decoration: _inputDecoration(hint: ''),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _labeledField(
                  label: 'RM Type',
                  child: isLoadingSuppliers
                      ? const Center(
                          child: SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : DropdownButtonFormField<String>(
                          value:
                              selectedRmType != null &&
                                  jenisRmList.contains(selectedRmType)
                              ? selectedRmType
                              : null,
                          hint: const Text(
                            'RM Type',
                            style: TextStyle(fontSize: 13),
                          ),
                          items: jenisRmList
                              .map(
                                (e) =>
                                    DropdownMenuItem(value: e, child: Text(e)),
                              )
                              .toList(),
                          onChanged: (v) {
                            setState(() {
                              selectedRmType = v;
                              selectedSupplier = null;
                              produsenController.clear();
                            });
                          },
                          decoration: _inputDecoration(hint: ''),
                          isDense: true,
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _labeledField(
                  label: 'Qty PO',
                  child: TextFormField(
                    controller: qtyPoController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 13),
                    decoration: _inputDecoration(hint: 'Qty PO'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _labeledField(
                  label: 'Supplier',
                  child: DropdownButtonFormField<String>(
                    value:
                        selectedSupplier != null &&
                            suppliers.any(
                              (s) => s['supplier'] == selectedSupplier,
                            )
                        ? selectedSupplier
                        : null,
                    hint: const Text(
                      'Supplier',
                      style: TextStyle(fontSize: 13),
                    ),
                    items: suppliers
                        .where((s) => s['jenis_rm'] == selectedRmType)
                        .map(
                          (s) => DropdownMenuItem<String>(
                            value: s['supplier'] as String,
                            child: Text(s['supplier'] as String),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        selectedSupplier = v;
                        final sel = suppliers.firstWhere(
                          (s) => s['supplier'] == v,
                          orElse: () => {'produsen': ''},
                        );
                        final p = (sel['produsen'] as String? ?? '').isNotEmpty
                            ? sel['produsen'] as String
                            : v;
                        produsenController.text = p;
                      });
                    },
                    decoration: _inputDecoration(hint: ''),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _labeledField(
            label: 'Producer',
            child: TextFormField(
              controller: produsenController,
              enabled: false,
              style: const TextStyle(fontSize: 13),
              decoration: _inputDecoration(
                hint: 'Producer',
              ).copyWith(filled: true, fillColor: Colors.grey.shade100),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScaleSection() {
    return _cardWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              const Icon(Icons.scale_outlined, size: 20, color: Colors.black87),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Scale Connection',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              if (lastSubmittedFaktur != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Faktur : $lastSubmittedFaktur',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _buildScaleStatusRow(),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.settings, size: 14, color: Colors.grey),
              label: const Text(
                'Debug',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),

          const SizedBox(height: 6),
          _buildBleInfoRow(),

          const SizedBox(height: 16),
          _buildWeightDisplay(),
        ],
      ),
    );
  }

  Widget _buildScaleStatusRow() {
    final bool hasWarning = connectedDevice == null;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: BoxDecoration(
        color: hasWarning ? const Color(0xFFFFF3E0) : const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(
            hasWarning ? Icons.error_outline : Icons.check_circle_outline,
            size: 16,
            color: hasWarning ? Colors.orange : Colors.green,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              hasWarning
                  ? 'Notification setup failed – trying periodic reading'
                  : 'Connected successfully',
              style: TextStyle(
                fontSize: 12,
                color: hasWarning
                    ? Colors.orange.shade800
                    : Colors.green.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBleInfoRow() {
    return Row(
      children: [
        Icon(
          Icons.bluetooth,
          size: 16,
          color: connectedDevice != null ? Colors.blue : Colors.grey,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            connectedDevice != null
                ? 'Connected to: ${connectedDevice!.name}'
                : 'Connected to: T RM',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
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
                  bluetoothStatus = 'Disconnected';
                });
              }
            },
            icon: const Icon(
              Icons.bluetooth_disabled,
              size: 14,
              color: Colors.red,
            ),
            label: const Text(
              'Disconnected',
              style: TextStyle(fontSize: 12, color: Colors.red),
            ),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          )
        else
          TextButton.icon(
            onPressed: bluetoothStatus == 'Scanning...' ? null : scanForDevices,
            icon: Icon(
              Icons.bluetooth_disabled,
              size: 14,
              color: Colors.grey.shade400,
            ),
            label: Text(
              'Disconnected',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            ),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
      ],
    );
  }

  Widget _buildWeightDisplay() {
    final double? weight = esp32Weight != null
        ? double.tryParse(esp32Weight!)
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Text(
            weight != null ? weight.toStringAsFixed(2) : '0.00',
            style: const TextStyle(
              fontSize: 52,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Current Weight (kg)',
            style: TextStyle(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: isReceivingWeight
                  ? null
                  : () async {
                      if (lastSubmittedFaktur == null) {
                        setState(() => isSaving = true);
                        await submitData();
                        setState(() => isSaving = false);
                      } else {
                        await _saveCurrentWeight();
                      }
                    },
              icon: isReceivingWeight
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.download_rounded, color: Colors.white),
              label: Text(
                isReceivingWeight ? 'Receiving...' : 'Receive',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90D9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
            ),
          ),
          if (receivedList.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const Text(
              'Riwayat Penerimaan',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16,
                columns: const [
                  DataColumn(label: Text('No')),
                  DataColumn(label: Text('Berat (kg)')),
                  DataColumn(label: Text('Waktu')),
                ],
                rows: List.generate(receivedList.length, (index) {
                  final row = receivedList[index];
                  return DataRow(
                    cells: [
                      DataCell(Text('${index + 1}')),
                      DataCell(Text(row['weight'] as String)),
                      DataCell(Text(row['time'].toString().substring(11, 19))),
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

  Widget _cardWrapper({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        children: [child],
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.black54),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _labeledField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }

  InputDecoration _inputDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint.isEmpty ? null : hint,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }
}
