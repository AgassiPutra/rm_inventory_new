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
import '../db/hive_service.dart';
import '../models/upload_queue.dart';
import '../utils/file_manager.dart';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:dotted_border/dotted_border.dart';

class IncomingMaterialPage extends StatefulWidget {
  @override
  State<IncomingMaterialPage> createState() => _IncomingMaterialPageState();
}

class _IncomingMaterialPageState extends State<IncomingMaterialPage> {
  final Auth authService = Auth();
  final Uuid _uuid = Uuid();

  bool isLoadingSuppliers = false;
  late Timer _timeUpdateTimer;
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
  String? userRole;
  String? userEmail;

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
    currentTimeController = TextEditingController();
    shiftController = TextEditingController();
    qtyPoController = TextEditingController();
    produsenController = TextEditingController();
    bluetoothManager = web.BluetoothManagerWeb();
    fetchSuppliers();
    _updateTime();
    _timeUpdateTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        _updateTime();
      }
    });
    _loadUserRole();
  }

  String getShiftFromTime(String time) {
    final parts = time.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final totalMinutes = hour * 60 + minute;

    if (totalMinutes >= 6 * 60 && totalMinutes < 14 * 60) {
      return 'Shift 1';
    } else if (totalMinutes >= 14 * 60 && totalMinutes < 22 * 60) {
      return 'Shift 2';
    } else {
      return 'Shift 3';
    }
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

  void _updateTime() {
    final now = DateTime.now();
    final currentTimeStr =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    final currentShift = getShiftFromTime(currentTimeStr);
    if (currentTimeController == null) {
      currentTimeController = TextEditingController(text: currentTimeStr);
    } else {
      currentTimeController.text = currentTimeStr;
    }

    if (shiftController == null) {
      shiftController = TextEditingController(text: currentShift);
    } else {
      shiftController.text = currentShift;
    }
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
          if (weightData.startsWith('SAVE_SIGNAL')) {
            final parts = weightData.split(':');
            if (parts.length == 2 && parts[1].isNotEmpty) {
              final parsedWeight = double.tryParse(parts[1]);
              if (parsedWeight != null && parsedWeight > 0) {
                if (mounted) {
                  _saveWeightDirectly(parsedWeight);
                }
                return;
              }
            }
            if (mounted) {
              _saveCurrentWeight();
            }
            return;
          }
          final cleanData = weightData.trim();
          final weight = double.tryParse(cleanData);
          if (weight != null) {
            if (mounted) {
              setState(() {
                esp32Weight = weight.toStringAsFixed(2);
                bluetoothStatus =
                    "Terhubung ke ${device.name} | Berat: ${esp32Weight} kg";
              });
            }
          } else {
            debugPrint(
              "Gagal parsing data: '$weightData' (clean: '$cleanData') bukan angka valid",
            );
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

  Future<void> _saveWeightDirectly(double weight) async {
    if (isReceivingWeight) return;
    setState(() => isReceivingWeight = true);

    if (selectedStatusPenerimaan == null || selectedTipeRM == null) {
      _showSnackBar(
        'Harap lengkapi Status Penerimaan dan Tipe RM.',
        isError: true,
      );
      setState(() => isReceivingWeight = false);
      return;
    }

    if (lastSubmittedFaktur == null) {
      _showSnackBar(
        'Faktur belum disubmit. Harap Submit form utama terlebih dahulu.',
        isError: true,
      );
      setState(() => isReceivingWeight = false);
      return;
    }

    final token = await getToken();
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? 'guest';

    if (token == null || token.isEmpty) {
      _showSnackBar(
        'Token tidak ditemukan. Silakan login ulang.',
        isError: true,
      );
      setState(() => isReceivingWeight = false);
      return;
    }

    final hiveService = HiveService.instance;
    final serverFaktur = await hiveService.getServerFaktur(
      lastSubmittedFaktur!,
    );
    final fakturToUse = serverFaktur ?? lastSubmittedFaktur;
    final apiEndpoint = 'gtsrm/api/timbangan?faktur=$fakturToUse';
    final weightData = {
      "weight": weight.toStringAsFixed(2),
      "status": selectedStatusPenerimaan,
      "type_rm": selectedTipeRM,
    };

    try {
      final response = await http.post(
        Uri.parse('https://api-gts-rm.scm-ppa.com/$apiEndpoint'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(weightData),
      );

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
      debugPrint("Error submit weight: $e. Menyimpan ke antrian.");

      final hiveService = HiveService.instance;
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
            "weight": weight.toStringAsFixed(2),
            "status": selectedStatusPenerimaan,
            "type_rm": selectedTipeRM,
            "time": DateTime.now().toString().substring(0, 19),
          });
          receivedWeight = (receivedWeight ?? 0.0) + weight;
          isReceivingWeight = false;
        });
        try {
          await bluetoothManager.turnOnLed();
          // Future.delayed(Duration(seconds: 1), () {
          //   bluetoothManager.turnOffLed();
          // });
        } catch (e) {
          debugPrint("Gagal kontrol LED: $e");
        }
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
        Uri.parse('https://api-gts-rm.scm-ppa.com/gtsrm/api/supplier'),
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
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final userId = prefs.getString('user_id') ?? 'guest';

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
    final apiEndpointFull =
        'https://api-gts-rm.scm-ppa.com/gtsrm/api/incoming-rm';
    const apiEndpoint = 'gtsrm/api/incoming-rm';

    final Map<String, dynamic> requestFields = {
      'jenis_rm': selectedJenisRm!,
      'qty_po': qtyPo,
      'supplier': selectedSupplier!,
      'produsen': produsenController.text,
    };

    final uri = Uri.parse(apiEndpointFull);
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token';

    final List<String> filePaths = [];
    final List<String> fileContentsBase64 = [];
    requestFields.forEach((key, value) {
      request.fields[key] = value.toString();
    });
    if (!kIsWeb) {
      if (invoiceFile != null) {
        final savedPath = await FileManager.saveFilePermanently(invoiceFile!);
        filePaths.add(savedPath);
        request.files.add(
          await http.MultipartFile.fromPath(
            'invoice_supplier',
            invoiceFile!.path,
            filename: invoiceFile!.path.split('/').last,
          ),
        );
      }
      if (suratJalanFile != null) {
        final savedPath = await FileManager.saveFilePermanently(
          suratJalanFile!,
        );
        filePaths.add(savedPath);
        request.files.add(
          await http.MultipartFile.fromPath(
            'surat_jalan',
            suratJalanFile!.path,
            filename: suratJalanFile!.path.split('/').last,
          ),
        );
      }
    } else {
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
    }

    try {
      final response = await request.send();
      final resBody = await response.stream.bytesToString();

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonRes = jsonDecode(resBody);
        debugPrint("Raw Response Incoming-RM: $jsonRes");

        final fakturServer = jsonRes['data']?['faktur'];
        final localFaktur = lastSubmittedFaktur;
        if (localFaktur != null &&
            localFaktur != fakturServer &&
            localFaktur.startsWith('UUID-')) {
          final hiveService = HiveService.instance;
          await hiveService.updateFakturMapping(localFaktur, fakturServer);
        }

        setState(() {
          lastSubmittedFaktur = fakturServer;
        });

        if (!kIsWeb) {
          for (var path in filePaths) {
            await FileManager.deleteFile(path);
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data berhasil dikirim (Online)')),
        );
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
      debugPrint("Error submit main form: $e. Menyimpan ke antrian.");
      String fakturIdUntukAntrian = lastSubmittedFaktur ?? 'UUID-${_uuid.v4()}';
      if (lastSubmittedFaktur == null) {
        setState(() {
          lastSubmittedFaktur = fakturIdUntukAntrian;
        });
      }

      try {
        final hiveService = HiveService.instance;
        final List<String> finalFilePayload = kIsWeb
            ? fileContentsBase64
            : filePaths;

        final queueItem = UploadQueue(
          userId: userId,
          apiEndpoint: apiEndpoint,
          requestBodyJson: jsonEncode(requestFields),
          fileContentsBase64: finalFilePayload,
          status: 'PENDING',
          menuType: 'MENU1_FORM_UTAMA',
          isMultipart: true,
          token: token,
          createdAt: DateTime.now(),
          method: 'POST',
          fakturLocalId: fakturIdUntukAntrian,
        );

        await hiveService.addItemToQueue(queueItem);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal kirim. Data disimpan lokal (Offline).'),
          ),
        );
      } catch (queueError) {
        debugPrint("FATAL: Gagal menyimpan ke antrian Hive: $queueError");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'FATAL ERROR: Gagal menyimpan data offline. Error: ${queueError.toString()}',
            ),
          ),
        );
      }
    }
  }

  Future<void> _saveCurrentWeight() async {
    if (isReceivingWeight) return;
    setState(() => isReceivingWeight = true);

    final parsedWeight = double.tryParse(esp32Weight ?? '');
    if (parsedWeight == null || parsedWeight <= 0.0) {
      _showSnackBar('Berat tidak valid atau nol.', isError: true);
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
    if (lastSubmittedFaktur == null) {
      _showSnackBar(
        'Faktur belum disubmit. Harap Submit form utama terlebih dahulu.',
        isError: true,
      );
      setState(() => isReceivingWeight = false);
      return;
    }

    final token = await getToken();
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? 'guest';

    if (token == null || token.isEmpty) {
      _showSnackBar(
        'Token tidak ditemukan. Silakan login ulang.',
        isError: true,
      );
      setState(() => isReceivingWeight = false);
      return;
    }

    final hiveService = HiveService.instance;
    final serverFaktur = await hiveService.getServerFaktur(
      lastSubmittedFaktur!,
    );
    final fakturToUse = serverFaktur ?? lastSubmittedFaktur;
    final apiEndpoint = 'gtsrm/api/timbangan?faktur=$fakturToUse';
    final weightData = {
      "weight": parsedWeight.toStringAsFixed(2),
      "status": selectedStatusPenerimaan,
      "type_rm": selectedTipeRM,
    };

    try {                                                                                                                                                                                                                                                                       
      final response = await http.post(
        Uri.parse('https://api-gts-rm.scm-ppa.com/$apiEndpoint'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(weightData),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSnackBar(
          'Data timbangan ${parsedWeight.toStringAsFixed(2)} kg berhasil dikirim.',
        );
      } else {
        throw Exception(
          jsonDecode(response.body)['message'] ?? 'Gagal kirim data timbangan',
        );
      }
    } catch (e) {
      debugPrint("Error submit weight: $e. Menyimpan ke antrian.");

      final hiveService = HiveService.instance;
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
            "weight": parsedWeight.toStringAsFixed(2),
            "status": selectedStatusPenerimaan,
            "type_rm": selectedTipeRM,
            "time": DateTime.now().toString().substring(0, 19),
          });
          receivedWeight = (receivedWeight ?? 0.0) + parsedWeight;
          isReceivingWeight = false;
        });
        try {
          await bluetoothManager.turnOnLed();
          // Future.delayed(Duration(seconds: 1), () {
          //   bluetoothManager.turnOffLed();
          // });
        } catch (e) {
          debugPrint("Gagal kontrol LED: $e");
        }
      }
    }
  }

  void resetForm() {
    setState(() {
      selectedJenisRm = null;
      qtyPoController.clear();
      selectedSupplier = null;
      produsenController.clear();
      invoiceFile = null;
      suratJalanFile = null;
      _updateTime();
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Text('Add New Incoming'),
            Spacer(),
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
                  fontSize: 14,
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
      ),
      drawer: CustomDrawer(),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 18,
                        color: Colors.grey[700],
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Shift Information',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current Time',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 4),
                            TextField(
                              enabled: false,
                              controller: currentTimeController,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.blue[50],
                                hintText: '00:00',
                                hintStyle: TextStyle(color: Colors.grey[400]),
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 16,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.grey[300]!,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.blue[300]!,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current Shift',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 4),
                            TextField(
                              enabled: false,
                              controller: shiftController,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.blue[50],
                                hintText: 'Shift X',
                                hintStyle: TextStyle(color: Colors.grey[400]),
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 16,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.grey[300]!,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.blue[300]!,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            // if (connectedDevice != null)
            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.cloud_upload,
                                size: 18,
                                color: Colors.grey[700],
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Document Upload',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Invoice Supplier',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              SizedBox(height: 8),
                              GestureDetector(
                                onTap: () {
                                  _pickImage((file) {
                                    setState(() {
                                      invoiceFile = file;
                                    });
                                  });
                                },
                                child: DottedBorder(
                                  borderType: BorderType.RRect,
                                  radius: Radius.circular(8),
                                  dashPattern: [6, 4],
                                  color: Colors.grey[400]!,
                                  strokeWidth: 1.5,
                                  child: Container(
                                    height: 100,
                                    decoration: BoxDecoration(
                                      color: invoiceFile != null
                                          ? Colors.green[100]
                                          : Colors.grey[50],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.cloud_upload_outlined,
                                            size: 24,
                                            color: Colors.grey[400],
                                          ),
                                          SizedBox(height: 8),
                                          if (invoiceFile == null) ...[
                                            Text(
                                              'Click to upload',
                                              style: TextStyle(
                                                color: Colors.blue[600],
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              'or drag and drop',
                                              style: TextStyle(
                                                color: Colors.grey[500],
                                              ),
                                            ),
                                            Text(
                                              'JPG, PDF',
                                              style: TextStyle(
                                                color: Colors.grey[400],
                                                fontSize: 12,
                                              ),
                                            ),
                                          ] else ...[
                                            Text(
                                              invoiceFile!.name,
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              "Drag and drop or click to replace",
                                              style: TextStyle(
                                                color: Colors.grey,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Surat Jalan',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              SizedBox(height: 8),
                              GestureDetector(
                                onTap: () {
                                  _pickImage((file) {
                                    setState(() {
                                      suratJalanFile = file;
                                    });
                                  });
                                },
                                child: DottedBorder(
                                  borderType: BorderType.RRect,
                                  radius: Radius.circular(8),
                                  dashPattern: [6, 4],
                                  color: Colors.grey[400]!,
                                  strokeWidth: 1.5,
                                  child: Container(
                                    height: 100,
                                    decoration: BoxDecoration(
                                      color: suratJalanFile != null
                                          ? Colors.green[100]
                                          : Colors.grey[50],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.cloud_upload_outlined,
                                            size: 24,
                                            color: Colors.grey[400],
                                          ),
                                          SizedBox(height: 8),
                                          if (suratJalanFile == null) ...[
                                            Text(
                                              'Click to upload',
                                              style: TextStyle(
                                                color: Colors.blue[600],
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              'or drag and drop',
                                              style: TextStyle(
                                                color: Colors.grey[500],
                                              ),
                                            ),
                                            Text(
                                              'JPG, PDF',
                                              style: TextStyle(
                                                color: Colors.grey[400],
                                                fontSize: 12,
                                              ),
                                            ),
                                          ] else ...[
                                            Text(
                                              suratJalanFile!.name,
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              "Drag and drop or click to replace",
                                              style: TextStyle(
                                                color: Colors.grey,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.inventory,
                                size: 18,
                                color: Colors.grey[700],
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Material Information',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Jenis RM',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    DropdownButtonFormField<String>(
                                      decoration: InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey[50],
                                      ),
                                      value: selectedJenisRm,
                                      items: jenisRmList
                                          .map(
                                            (e) => DropdownMenuItem(
                                              value: e,
                                              child: Text(e),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          selectedJenisRm = value;
                                          selectedSupplier = null;
                                          produsenController.clear();
                                          selectedTipeRM = null;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Qty PO',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    TextFormField(
                                      controller: qtyPoController,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey[50],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Supplier',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    DropdownButtonFormField<String>(
                                      decoration: InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey[50],
                                      ),
                                      value: selectedSupplier,
                                      items: suppliers
                                          .where(
                                            (item) =>
                                                item['jenis_rm'] ==
                                                selectedJenisRm,
                                          )
                                          .map(
                                            (item) => DropdownMenuItem<String>(
                                              value: item['supplier'] as String,
                                              child: Text(
                                                item['supplier'] as String,
                                              ),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (value) {
                                        if (value == null) return;
                                        setState(() {
                                          selectedSupplier = value;
                                          final selected = suppliers.firstWhere(
                                            (item) => item['supplier'] == value,
                                            orElse: () => {
                                              'supplier': '',
                                              'produsen': '',
                                            },
                                          );
                                          final produsenValue =
                                              (selected['produsen'] as String?)
                                                      ?.isNotEmpty ==
                                                  true
                                              ? selected['produsen'] as String
                                              : selected['supplier'] as String;
                                          produsen = produsenValue;
                                          produsenController.text = produsen;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Producer',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    TextFormField(
                                      controller: produsenController,
                                      enabled: false,
                                      decoration: InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey[200],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                minimumSize: const Size(360, 50),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
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
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.balance,
                            size: 18,
                            color: Colors.grey[700],
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Scale Connection',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
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
                    child: connectedDevice != null
                        ? _buildConnectedScaleUI()
                        : _buildConnectionUI(),
                  ),
                ],
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
            weight != null ? '${weight.toStringAsFixed(2)} kg' : '0 kg',
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
                : _saveCurrentWeight,
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
          // if (kDebugMode)
          //   Padding(
          //     padding: EdgeInsets.only(top: 12),
          //     child: Wrap(
          //       spacing: 8,
          //       children: [
          //         ElevatedButton(
          //           onPressed: () => bluetoothManager.simulateWeight("0.00"),
          //           child: Text("Simulasi 0.00"),
          //           style: ElevatedButton.styleFrom(
          //             backgroundColor: Colors.grey,
          //           ),
          //         ),
          //         ElevatedButton(
          //           onPressed: () => bluetoothManager.simulateWeight("12.34"),
          //           child: Text("Simulasi 12.34"),
          //           style: ElevatedButton.styleFrom(
          //             backgroundColor: Colors.grey,
          //           ),
          //         ),
          //       ],
          //     ),
          //   ),
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
                      DataCell(Text(row["weight"] as String)),
                      DataCell(Text(row["status"] ?? "-")),
                      DataCell(Text(row["type_rm"] ?? "-")),
                      DataCell(Text(row["time"].toString().substring(11, 19))),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(height: 32),
          Icon(Icons.bluetooth_disabled, size: 48, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            bluetoothStatus.isNotEmpty ? bluetoothStatus : "No Scales Found",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Make sure your scale is powered on and within range',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          Center(
            child: ElevatedButton(
              onPressed: bluetoothStatus == "Scanning..."
                  ? null
                  : scanForDevices,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 97, 164, 219),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                minimumSize: Size(360, 50),
                padding: EdgeInsets.symmetric(horizontal: 16),
              ),
              child: Text('Connect to Scale'),
            ),
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[400],
                ),
              ),
              SizedBox(width: 8),
              Text(
                'Disconnected',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
