import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../db/hive_service.dart';
import '../models/upload_queue.dart';
import '../utils/file_manager.dart';

class SyncService {
  static const String _baseUrl = 'https://api-gts-rm.scm-ppa.com/';

  StreamSubscription? _connectivitySubscription;
  Timer? _retryTimer;
  bool isSyncing = false;
  late final HiveService _hiveService = HiveService.instance;

  static final SyncService _instance = SyncService._internal();
  static SyncService get instance => _instance;

  factory SyncService() => _instance;
  SyncService._internal();
  void startListening() {
    if (!kIsWeb) {
      processUploadQueue();

      _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
        List<ConnectivityResult> results,
      ) {
        final hasConnection = !results.contains(ConnectivityResult.none);

        if (hasConnection && !isSyncing) {
          debugPrint('Koneksi pulih. Memulai sinkronisasi antrian...');
          processUploadQueue();
        }
      });

      _retryTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
        if (!isSyncing) {
          processUploadQueue();
        }
      });
    } else {
      processUploadQueue();
    }
  }

  void stopListening() {
    _connectivitySubscription?.cancel();
    _retryTimer?.cancel();
  }

  Future<void> processUploadQueue() async {
    if (isSyncing) return;
    isSyncing = true;
    debugPrint('Memulai proses sinkronisasi...');

    try {
      final allItems = await _hiveService.getAllQueueItems();
      final pendingItems = allItems
          .where((item) => item.status == 'PENDING')
          .toList();

      if (pendingItems.isEmpty) {
        debugPrint('Tidak ada data tertunda.');
        return;
      }

      debugPrint('Ditemukan ${pendingItems.length} item untuk diunggah.');

      for (final item in pendingItems) {
        final token = await _getToken();
        if (token == null) {
          debugPrint('Token tidak ditemukan. Sinkronisasi ditunda.');
          break;
        }

        final success = await _uploadItem(item, token);

        if (success) {
          await _hiveService.deleteQueueItem(item.key);
          if (!kIsWeb) {
            for (var path in item.fileContentsBase64) {
              await FileManager.deleteFile(path);
            }
          }
          debugPrint('Item ID ${item.key} berhasil diunggah dan dihapus.');
        } else {
          debugPrint('Item ID ${item.key} gagal. Mencoba lagi nanti.');
          break;
        }
      }
    } catch (e) {
      debugPrint('Exception saat memproses antrian: $e');
    } finally {
      isSyncing = false;
      debugPrint('Sinkronisasi selesai.');
    }
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<bool> _uploadItem(UploadQueue item, String token) async {
    final uri = Uri.parse(_baseUrl + item.apiEndpoint);

    if (item.isMultipart) {
      return await _uploadMultipart(item, token, uri);
    }

    return await _uploadJson(item, token, uri);
  }

  Future<bool> _uploadJson(UploadQueue item, String token, Uri uri) async {
    if (item.menuType == 'MENU1_TIMBANGAN' &&
        item.apiEndpoint.contains('UUID-')) {
      debugPrint(
        'Item timbangan ID ${item.key} menunda, menunggu faktur utama disinkronkan.',
      );
      return false;
    }

    try {
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: item.requestBodyJson,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      } else {
        debugPrint(
          'Upload JSON Gagal (Server Error): Status ${response.statusCode}, Body: ${response.body}',
        );
        return false;
      }
    } catch (e) {
      debugPrint('Error jaringan saat mengunggah JSON: $e');
      return false;
    }
  }

  Future<bool> _uploadMultipart(UploadQueue item, String token, Uri uri) async {
    if (kIsWeb && item.fileContentsBase64.isEmpty) {}

    final request = http.MultipartRequest(item.method, uri)
      ..headers['Authorization'] = 'Bearer $token';
    final Map<String, dynamic> dataMap = jsonDecode(item.requestBodyJson);
    dataMap.forEach((key, value) {
      request.fields[key] = value.toString();
    });
    if (item.fileContentsBase64.isNotEmpty) {
      try {
        for (int i = 0; i < item.fileContentsBase64.length; i++) {
          final payload = item.fileContentsBase64[i];
          final fieldName = i == 0 ? 'invoice_supplier' : 'surat_jalan';

          if (!kIsWeb) {
            final filePath = payload;
            if (File(filePath).existsSync()) {
              request.files.add(
                await http.MultipartFile.fromPath(
                  fieldName,
                  filePath,
                  filename: filePath.split('/').last,
                ),
              );
            }
          } else {
            final base64String = payload;
            final bytes = base64Decode(base64String);
            final fileName = '$fieldName.jpg';

            request.files.add(
              http.MultipartFile.fromBytes(
                fieldName,
                bytes,
                filename: fileName,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Gagal melampirkan file: $e');
        return false;
      }
    }
    try {
      final response = await request.send();
      final resBody = await response.stream.bytesToString();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (item.apiEndpoint == 'gtsrm/api/incoming-rm') {
          try {
            final jsonRes = jsonDecode(resBody);
            final fakturAsli = jsonRes['data']?['faktur'];

            if (fakturAsli != null) {
              debugPrint(
                'Faktur asli diterima: $fakturAsli. Mencoba sinkronisasi timbangan terkait.',
              );
            }
          } catch (_) {
            debugPrint(
              'Gagal memproses respons faktur, lanjutkan penghapusan item.',
            );
          }
        }
        return true;
      } else {
        debugPrint(
          'Upload Multipart Gagal (Server Error): Status ${response.statusCode}, Body: $resBody',
        );
        return false;
      }
    } catch (e) {
      debugPrint('Error jaringan saat mengunggah Multipart: $e');
      return false;
    }
  }
}
