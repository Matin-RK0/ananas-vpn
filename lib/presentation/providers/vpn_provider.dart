import 'package:flutter/material.dart';
import '../../data/services/vpn_service.dart';
import '../../domain/models/vpn_config.dart';
import '../../domain/models/v2ray_status.dart';

class VpnProvider extends ChangeNotifier {
  final VpnService _vpnService;
  V2RayStatus _status = V2RayStatus.disconnected();
  
  VpnProvider(this._vpnService) {
    _vpnService.statusStream.listen((status) {
      _status = status;
      notifyListeners();
    });
  }

  V2RayStatus get status => _status;
  bool get isConnected => _status.state == 'CONNECTED';

  Future<void> initialize() => _vpnService.initialize();

  Future<void> connect(String configStr) async {
    try {
      final config = VpnConfig(config: configStr, name: 'Custom Profile');
      await _vpnService.startVpn(config);
    } catch (e) {
      debugPrint('Error connecting: $e');
    }
  }

  Future<void> disconnect() async {
    try {
      await _vpnService.stopVpn();
    } catch (e) {
      debugPrint('Error disconnecting: $e');
    }
  }
}
