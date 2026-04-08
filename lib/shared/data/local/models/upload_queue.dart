import 'package:hive/hive.dart';

part 'upload_queue.g.dart';

@HiveType(typeId: 0)
class UploadQueue extends HiveObject {
  @HiveField(0)
  final String userId;

  @HiveField(1)
  final String apiEndpoint;

  @HiveField(2)
  final String requestBodyJson;

  @HiveField(3)
  final List<String> fileContentsBase64;

  @HiveField(4)
  final String method;

  @HiveField(5)
  final String status;

  @HiveField(6)
  final String menuType;

  @HiveField(7)
  final bool isMultipart;

  @HiveField(8)
  final String token;

  @HiveField(9)
  final DateTime createdAt;

  @HiveField(10)
  final String fakturLocalId;

  UploadQueue({
    required this.userId,
    required this.apiEndpoint,
    required this.requestBodyJson,
    required this.fileContentsBase64,
    required this.method,
    required this.status,
    required this.menuType,
    required this.isMultipart,
    required this.token,
    required this.createdAt,
    required this.fakturLocalId,
  });
}
