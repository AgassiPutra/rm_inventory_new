import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/upload_queue.dart';

class HiveService {
  static const String _boxName = 'uploadQueueBox';
  static final HiveService _instance = HiveService._internal();
  static late Box<UploadQueue> _queueBox;

  static HiveService get instance => _instance;

  factory HiveService() => _instance;
  HiveService._internal();
  static Future<void> initialize() async {
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(UploadQueueAdapter());
    }
    _queueBox = await Hive.openBox<UploadQueue>(_boxName);
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
}
