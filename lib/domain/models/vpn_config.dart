import 'package:hive/hive.dart';

@HiveType(typeId: 0)
class VpnConfig extends HiveObject {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String name;
  
  @HiveField(2)
  final String rawLink; // The raw vless://, vmess:// etc link
  
  @HiveField(3)
  final String fullJsonConfig; // The converted Xray JSON config
  
  @HiveField(4)
  final String groupId;
  
  @HiveField(5)
  final DateTime createdAt;

  @HiveField(6)
  final String remark;

  @HiveField(7)
  final int? lastLatency;

  @HiveField(8)
  final double? lastDownloadSpeed;

  VpnConfig({
    required this.id,
    required this.name,
    required this.rawLink,
    required this.fullJsonConfig,
    required this.groupId,
    required this.createdAt,
    this.remark = '',
    this.lastLatency,
    this.lastDownloadSpeed,
  });

  VpnConfig copyWith({
    String? id,
    String? name,
    String? rawLink,
    String? fullJsonConfig,
    String? groupId,
    DateTime? createdAt,
    String? remark,
    int? lastLatency,
    double? lastDownloadSpeed,
  }) {
    return VpnConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      rawLink: rawLink ?? this.rawLink,
      fullJsonConfig: fullJsonConfig ?? this.fullJsonConfig,
      groupId: groupId ?? this.groupId,
      createdAt: createdAt ?? this.createdAt,
      remark: remark ?? this.remark,
      lastLatency: lastLatency ?? this.lastLatency,
      lastDownloadSpeed: lastDownloadSpeed ?? this.lastDownloadSpeed,
    );
  }
}

@HiveType(typeId: 1)
class VpnGroup extends HiveObject {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String name;
  
  @HiveField(2)
  final DateTime createdAt;

  @HiveField(3)
  final String? subscriptionUrl;

  @HiveField(4)
  final DateTime? lastUpdated;

  @HiveField(5)
  final bool isAutoOptimizeEnabled;

  @HiveField(6)
  final DateTime? lastOptimized;

  VpnGroup({
    required this.id,
    required this.name,
    required this.createdAt,
    this.subscriptionUrl,
    this.lastUpdated,
    this.isAutoOptimizeEnabled = false,
    this.lastOptimized,
  });

  VpnGroup copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    String? subscriptionUrl,
    DateTime? lastUpdated,
    bool? isAutoOptimizeEnabled,
    DateTime? lastOptimized,
  }) {
    return VpnGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      subscriptionUrl: subscriptionUrl ?? this.subscriptionUrl,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isAutoOptimizeEnabled: isAutoOptimizeEnabled ?? this.isAutoOptimizeEnabled,
      lastOptimized: lastOptimized ?? this.lastOptimized,
    );
  }
}
