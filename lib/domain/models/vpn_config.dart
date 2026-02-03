class VpnConfig {
  final String config;
  final String name;
  final String remark;

  VpnConfig({
    required this.config,
    required this.name,
    this.remark = '',
  });
}
