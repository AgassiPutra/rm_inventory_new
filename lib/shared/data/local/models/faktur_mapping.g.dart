// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'faktur_mapping.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FakturMappingAdapter extends TypeAdapter<FakturMapping> {
  @override
  final int typeId = 1;

  @override
  FakturMapping read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FakturMapping(
      localFaktur: fields[0] as String,
      serverFaktur: fields[1] as String?,
      createdAt: fields[2] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, FakturMapping obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.localFaktur)
      ..writeByte(1)
      ..write(obj.serverFaktur)
      ..writeByte(2)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FakturMappingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
