import 'package:ananas/domain/models/vpn_config.dart';
import 'package:hive/hive.dart';

class VpnConfigAdapter extends TypeAdapter<VpnConfig> {
  @override
  final int typeId = 0;

  @override
  VpnConfig read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return VpnConfig(
      id: fields[0] as String,
      name: fields[1] as String,
      rawLink: fields[2] as String,
      fullJsonConfig: fields[3] as String,
      groupId: fields[4] as String,
      createdAt: fields[5] as DateTime,
      remark: fields[6] as String,
      lastLatency: fields[7] as int?,
      lastDownloadSpeed: fields[8] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, VpnConfig obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.rawLink)
      ..writeByte(3)
      ..write(obj.fullJsonConfig)
      ..writeByte(4)
      ..write(obj.groupId)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.remark)
      ..writeByte(7)
      ..write(obj.lastLatency)
      ..writeByte(8)
      ..write(obj.lastDownloadSpeed);
  }
}

class VpnGroupAdapter extends TypeAdapter<VpnGroup> {
  @override
  final int typeId = 1;

  @override
  VpnGroup read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return VpnGroup(
      id: fields[0] as String,
      name: fields[1] as String,
      createdAt: fields[2] as DateTime,
      subscriptionUrl: fields[3] as String?,
      lastUpdated: fields[4] as DateTime?,
      isAutoOptimizeEnabled: fields[5] as bool? ?? false,
      lastOptimized: fields[6] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, VpnGroup obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.createdAt)
      ..writeByte(3)
      ..write(obj.subscriptionUrl)
      ..writeByte(4)
      ..write(obj.lastUpdated)
      ..writeByte(5)
      ..write(obj.isAutoOptimizeEnabled)
      ..writeByte(6)
      ..write(obj.lastOptimized);
  }
}
