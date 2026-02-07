import 'dart:async';

import 'package:flutter/material.dart';
import '../../data/services/vpn_service.dart';
import '../../domain/models/vpn_config.dart';
import '../../domain/models/v2ray_status.dart';

class VpnProvider extends ChangeNotifier {
  final VpnService _vpnService;
  V2RayStatus _status = V2RayStatus.disconnected();
  VpnConfig? _selectedConfig;
  Timer? _delayTimer;
  
  VpnProvider(this._vpnService) {
    _vpnService.statusStream.listen((status) {
      _status = status;
      notifyListeners();
    });
    
    // Periodically update real delay if connected
    _delayTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (isConnected) {
        final delay = await _vpnService.getConnectedServerDelay();
        if (delay > 0) {
          _status = V2RayStatus(
            duration: _status.duration,
            uploadSpeed: _status.uploadSpeed,
            downloadSpeed: _status.downloadSpeed,
            state: _status.state,
            delay: delay,
          );
          notifyListeners();
        }
      }
    });
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    super.dispose();
  }

  V2RayStatus get status => _status;
  bool get isConnected => _status.state == 'CONNECTED';
  VpnConfig? get selectedConfig => _selectedConfig;

  void updateSelectedConfig(VpnConfig? config) {
    _selectedConfig = config;
    notifyListeners();
  }

  Future<void> initialize() => _vpnService.initialize();

  Future<void> toggleConnection() async {
    if (isConnected) {
      await disconnect();
    } else {
      if (_selectedConfig != null) {
        await connect();
      }
    }
  }

  Future<void> connect() async {
    if (_selectedConfig == null) return;
    try {
      await _vpnService.startVpn(_selectedConfig!);
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
