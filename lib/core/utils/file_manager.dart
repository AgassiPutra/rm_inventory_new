import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class FileManager {
  static final Uuid _uuid = Uuid();
  static Future<String> saveFilePermanently(XFile file) async {
    if (file.path.isEmpty) {
      throw Exception("XFile path is empty. Cannot save file.");
    }

    if (kIsWeb) {
      final fileName = '${_uuid.v4()}_${file.name}';
      return 'web_reference/$fileName';
    } else {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = '${_uuid.v4()}_${file.name}';
      final savedPath = '${appDir.path}/uploads/$fileName';
      final directory = Directory('${appDir.path}/uploads');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      await File(file.path).copy(savedPath);
      return savedPath;
    }
  }

  static Future<void> deleteFile(String path) async {
    if (kIsWeb) {
      print('Operasi deleteFile di Web diabaikan: $path');
      return;
    }
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        print('File deleted: $path');
      }
    } on FileSystemException catch (e) {
      print('Error deleting file $path (FS Exception): $e');
    } catch (e) {
      print('Error deleting file $path: $e');
    }
  }
}
