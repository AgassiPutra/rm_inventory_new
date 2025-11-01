import 'package:hive/hive.dart';

part 'faktur_mapping.g.dart';

@HiveType(typeId: 1)
class FakturMapping extends HiveObject {
  @HiveField(0)
  final String localFaktur;

  @HiveField(1)
  String? serverFaktur;

  @HiveField(2)
  final DateTime createdAt;

  FakturMapping({
    required this.localFaktur,
    this.serverFaktur,
    required this.createdAt,
  });
}
