import 'dart:async';
import 'package:flutter/services.dart';
import '../../domain/models/vpn_config.dart';
import '../../domain/models/v2ray_status.dart';
import '../utils/xray_config_converter.dart';

class VpnService {
  static const MethodChannel _channel = MethodChannel('com.example.ananas/vpn');
  static const EventChannel _eventChannel = EventChannel('com.example.ananas/vpn_status');
  
  final _statusController = StreamController<V2RayStatus>.broadcast();
  
  VpnService() {
    _eventChannel.receiveBroadcastStream().listen((event) {
      if (event is Map) {
        final statusMap = Map<String, dynamic>.from(event);
        _statusController.add(V2RayStatus.fromMap(statusMap));
      }
    }, onError: (error) {
      // Handle stream errors
    });
  }

  Stream<V2RayStatus> get statusStream => _statusController.stream;

  Future<void> initialize() async {
    // Initialize native assets if needed
    await _channel.invokeMethod('initialize');
  }

  Future<void> startVpn(VpnConfig config) async {
    try {
      // Use the pre-converted fullJsonConfig or convert the rawLink
      final configJson = config.fullJsonConfig.isNotEmpty 
          ? config.fullJsonConfig 
          : XrayConfigConverter.convertToFullJson(config.rawLink);
          
      await _channel.invokeMethod('startVpn', {
        'config': configJson,
        'remark': config.remark.isNotEmpty ? config.remark : config.name,
      });
    } on PlatformException catch (e) {
      throw Exception('Failed to start VPN: ${e.message}');
    }
  }

  Future<void> stopVpn() async {
    try {
      await _channel.invokeMethod('stopVpn');
    } on PlatformException catch (e) {
      throw Exception('Failed to stop VPN: ${e.message}');
    }
  }

  Future<int> getConnectedServerDelay() async {
    try {
      final int delay = await _channel.invokeMethod('getConnectedServerDelay');
      return delay;
    } catch (e) {
      return -1;
    }
  }

  Future<int> getServerDelay(String config) async {
    try {
      final int delay = await _channel.invokeMethod('getServerDelay', {'config': config});
      return delay;
    } catch (e) {
      return -1;
    }
  }
}
