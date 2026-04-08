// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'upload_queue.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UploadQueueAdapter extends TypeAdapter<UploadQueue> {
  @override
  final int typeId = 0;

  @override
  UploadQueue read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UploadQueue(
      userId: fields[0] as String,
      apiEndpoint: fields[1] as String,
      requestBodyJson: fields[2] as String,
      fileContentsBase64: (fields[3] as List).cast<String>(),
      method: fields[4] as String,
      status: fields[5] as String,
      menuType: fields[6] as String,
      isMultipart: fields[7] as bool,
      token: fields[8] as String,
      createdAt: fields[9] as DateTime,
      fakturLocalId: fields[10] as String,
    );
  }

  @override
  void write(BinaryWriter writer, UploadQueue obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.userId)
      ..writeByte(1)
      ..write(obj.apiEndpoint)
      ..writeByte(2)
      ..write(obj.requestBodyJson)
      ..writeByte(3)
      ..write(obj.fileContentsBase64)
      ..writeByte(4)
      ..write(obj.method)
      ..writeByte(5)
      ..write(obj.status)
      ..writeByte(6)
      ..write(obj.menuType)
      ..writeByte(7)
      ..write(obj.isMultipart)
      ..writeByte(8)
      ..write(obj.token)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.fakturLocalId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UploadQueueAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
