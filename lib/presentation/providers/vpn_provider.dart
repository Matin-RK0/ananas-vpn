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
  int? _lastSuccessfulDelay;
  
  VpnProvider(this._vpnService) {
    _vpnService.statusStream.listen((status) {
      // Preserve last successful delay if the new status doesn't have one
      if (status.delay != null && status.delay! > 0) {
        _lastSuccessfulDelay = status.delay;
      }
      
      _status = status;
      notifyListeners();
    });
    
    // Periodically update real delay if connected
    _delayTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (isConnected) {
        final delay = await _vpnService.getConnectedServerDelay();
        if (delay > 0) {
          _lastSuccessfulDelay = delay;
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
  bool get isConnecting => _status.state == 'CONNECTING';
  VpnConfig? get selectedConfig => _selectedConfig;
  int? get lastSuccessfulDelay => _lastSuccessfulDelay;

  void updateSelectedConfig(VpnConfig? config) {
    _selectedConfig = config;
    notifyListeners();
  }

  Future<void> initialize() => _vpnService.initialize();

  Future<void> toggleConnection(VpnConfig? config) async {
    if (isConnected) {
      await disconnect();
    } else {
      if (config != null) {
        _selectedConfig = config;
        notifyListeners();
        await connect();
      }
    }
  }

  Future<void> connect() async {
    if (_selectedConfig == null) return;
    _lastSuccessfulDelay = null; // Reset ping for new connection
    notifyListeners();
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
