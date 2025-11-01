import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/upload_queue.dart';
import '../models/faktur_mapping.dart';

class HiveService {
  static const String _queueBoxName = 'uploadQueueBox';
  static const String _fakturMapBoxName = 'fakturMappingBox';
  static final HiveService _instance = HiveService._internal();
  static late Box<UploadQueue> _queueBox;
  static late Box<FakturMapping> _fakturMapBox;

  static HiveService get instance => _instance;

  factory HiveService() => _instance;
  HiveService._internal();

  static Future<void> initialize() async {
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(UploadQueueAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(FakturMappingAdapter());
    }
    _queueBox = await Hive.openBox<UploadQueue>(_queueBoxName);
    _fakturMapBox = await Hive.openBox<FakturMapping>(_fakturMapBoxName);
  }

  Future<List<UploadQueue>> getAllQueueItems() async {
    return _queueBox.values.toList();
  }

  Future<int> addItemToQueue(UploadQueue item) async {
    return _queueBox.add(item);
  }

  Future<void> deleteQueueItem(int key) async {
    await _queueBox.delete(key);
  }

  Future<String?> getServerFaktur(String localFaktur) async {
    final mappings = _fakturMapBox.values.where(
      (m) => m.localFaktur == localFaktur,
    );
    return mappings.isEmpty ? null : mappings.first.serverFaktur;
  }

  Future<void> updateFakturMapping(
    String localFaktur,
    String serverFaktur,
  ) async {
    final existing = _fakturMapBox.values.where(
      (m) => m.localFaktur == localFaktur,
    );
    if (existing.isEmpty) {
      await _fakturMapBox.add(
        FakturMapping(
          localFaktur: localFaktur,
          serverFaktur: serverFaktur,
          createdAt: DateTime.now(),
        ),
      );
    } else {
      final mapping = existing.first;
      mapping.serverFaktur = serverFaktur;
      await mapping.save();
    }

    final queueItems = _queueBox.values.where(
      (item) => item.fakturLocalId == localFaktur,
    );
    for (var item in queueItems) {
      if (item.menuType == 'MENU1_TIMBANGAN') {
        final newApiEndpoint = 'gtsrm/api/timbangan?faktur=$serverFaktur';
        final updatedItem = UploadQueue(
          userId: item.userId,
          apiEndpoint: newApiEndpoint,
          requestBodyJson: item.requestBodyJson,
          fileContentsBase64: item.fileContentsBase64,
          method: item.method,
          status: item.status,
          menuType: item.menuType,
          isMultipart: item.isMultipart,
          token: item.token,
          createdAt: item.createdAt,
          fakturLocalId: serverFaktur,
        );
        final key = _queueBox.keyAt(_queueBox.values.toList().indexOf(item));
        await _queueBox.put(key, updatedItem);
      }
    }
  }
}
