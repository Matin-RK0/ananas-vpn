import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import '../../domain/models/vpn_config.dart';
import '../../data/utils/xray_config_converter.dart';
import '../../data/services/vpn_service.dart';

class ConfigProvider with ChangeNotifier {
  final VpnService? _vpnService;
  late Box<VpnConfig> _configBox;
  late Box<VpnGroup> _groupBox;
  late Box _settingsBox;
  
  List<VpnGroup> _groups = [];
  List<VpnConfig> _configs = [];
  String? _selectedConfigId;
  String? _selectedGroupId;
  bool _isUpdating = false;
  Timer? _optimizationTimer;

  List<VpnGroup> get groups => _groups;
  List<VpnConfig> get configs => _configs;
  String? get selectedConfigId => _selectedConfigId;
  String? get selectedGroupId => _selectedGroupId;
  bool get isUpdating => _isUpdating;

  VpnConfig? get selectedConfig {
    if (_selectedConfigId == null) return null;
    try {
      return _configs.firstWhere((c) => c.id == _selectedConfigId);
    } catch (_) {
      return null;
    }
  }

  ConfigProvider({VpnService? vpnService}) : _vpnService = vpnService {
    _init();
    _startOptimizationTimer();
  }

  Future<int?> getRealDelay() async {
    // This measures the real delay of the CURRENTLY ACTIVE VPN connection
    try {
      final stopwatch = Stopwatch()..start();
      final response = await http.get(
        Uri.parse('http://cp.cloudflare.com/generate_204'),
      ).timeout(const Duration(seconds: 5));
      stopwatch.stop();
      
      if (response.statusCode >= 200 && response.statusCode < 400) {
        return stopwatch.elapsedMilliseconds;
      }
      return null;
    } catch (e) {
      debugPrint('Real delay check failed: $e');
      return null;
    }
  }

  Future<void> _startOptimizationTimer() async {
    _optimizationTimer?.cancel();
    // Check every 5 minutes if any group needs optimization (60 min interval)
    _optimizationTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _checkAndOptimizeGroups();
    });
  }

  Future<void> _checkAndOptimizeGroups() async {
    final now = DateTime.now();
    for (var group in _groups) {
      if (group.isAutoOptimizeEnabled) {
        final lastOpt = group.lastOptimized;
        if (lastOpt == null || now.difference(lastOpt).inMinutes >= 60) {
          await optimizeGroup(group.id);
        }
      }
    }
  }

  Future<void> optimizeGroup(String groupId) async {
    debugPrint('Optimizing group: $groupId');
    final group = _groupBox.get(groupId);
    if (group == null) return;

    _isUpdating = true;
    notifyListeners();

    try {
      // 1. Update subscription if applicable and wait for it
      if (group.subscriptionUrl != null && group.subscriptionUrl!.isNotEmpty) {
        await updateSubscription(groupId);
      }

      // Refresh configs after subscription update
      _loadData();
      final groupConfigs = _configs.where((c) => c.groupId == groupId).toList();
      if (groupConfigs.isEmpty) {
        _isUpdating = false;
        notifyListeners();
        return;
      }

      // 2. Measure latency and speed for all configs in this group (5 at a time)
      VpnConfig? bestConfig;
      double maxScore = -1.0;

      for (int i = 0; i < groupConfigs.length; i += 5) {
        final end = (i + 5 < groupConfigs.length) ? i + 5 : groupConfigs.length;
        final batch = groupConfigs.sublist(i, end);

        // 2a. Clear old values for the current batch to show "loading" state in UI
        for (var config in batch) {
          final clearedConfig = config.copyWith(lastLatency: null, lastDownloadSpeed: null);
          await _configBox.put(config.id, clearedConfig);
        }
        _loadData();

        // 2b. Test a batch of 5 concurrently
        final results = await Future.wait(batch.map((config) async {
          final latency = await checkLatency(config);
          
          double? estimatedSpeed;
          if (latency != null && latency != -1) {
            estimatedSpeed = await checkSpeed(config);
          }
          
          final updatedConfig = config.copyWith(
            lastLatency: latency,
            lastDownloadSpeed: estimatedSpeed,
          );
          await _configBox.put(config.id, updatedConfig);
          
          return {'config': updatedConfig, 'latency': latency, 'speed': estimatedSpeed};
        }));

        // Process results for each batch to find the best
        for (var result in results) {
          final config = result['config'] as VpnConfig;
          final latency = result['latency'] as int?;
          final speed = result['speed'] as double?;

          if (latency != null && latency != -1) {
            // Scoring formula: Speed is good, Latency is bad.
            // We want high speed and low latency.
            // Score = Speed (MB/s) * 1000 / Latency (ms)
            // Example: 1.5MB/s and 100ms -> Score 15
            // Example: 0.5MB/s and 50ms -> Score 10
            final currentScore = (speed ?? 0) * 1000 / latency;
            
            if (currentScore > maxScore) {
              maxScore = currentScore;
              bestConfig = config;
            }
          }
        }
        
        _loadData();
      }

      // 3. Auto-select best config if found
      if (bestConfig != null) {
        _selectedConfigId = bestConfig.id;
        await _settingsBox.put('last_config_id', bestConfig.id);
        debugPrint('Best config selected: ${bestConfig.name} with score $maxScore');
      }

      // 4. Mark as optimized and reset the 1-hour timer
      final updatedGroup = group.copyWith(lastOptimized: DateTime.now());
      await _groupBox.put(groupId, updatedGroup);

    } catch (e) {
      debugPrint('Optimization failed: $e');
    } finally {
      _isUpdating = false;
      _loadData();
      notifyListeners();
    }
  }

  Future<int?> checkLatency(VpnConfig config) async {
    try {
      // 1. Try native real delay if service is available
      if (_vpnService != null) {
        final delay = await _vpnService.getServerDelay(config.rawLink);
        if (delay > 0) return delay;
      }

      // 2. Fallback to TCP Ping (Server connection time)
      final uri = _parseRawLink(config.rawLink);
      if (uri == null) return -1; // Special value for invalid/timeout

      final host = uri.host;
      final port = uri.port;

      final stopwatch = Stopwatch()..start();
      final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 3));
      stopwatch.stop();
      await socket.close();
      
      return stopwatch.elapsedMilliseconds;
    } catch (e) {
      debugPrint('Latency check failed for ${config.name}: $e');
      return -1; // Special value for Time Out
    }
  }

  Future<double?> checkSpeed(VpnConfig config) async {
    try {
      final stopwatch = Stopwatch()..start();
      
      // We use a very fast endpoint to estimate quality/speed without needing full connection
      // This works as a "connectivity and quality" check for all configs.
      final response = await http.get(
        Uri.parse('https://cp.cloudflare.com/generate_204'),
      ).timeout(const Duration(seconds: 4));
      
      stopwatch.stop();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final ms = stopwatch.elapsedMilliseconds;
        if (ms == 0) return 0;
        
        // This is an estimated quality score (MB/s equivalent)
        // 1000ms response ~ 0.1 MB/s, 100ms response ~ 1.0 MB/s, etc.
        return 100.0 / ms; 
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  Uri? _parseRawLink(String link) {
    try {
      if (link.startsWith('vless://')) {
        return Uri.parse(link);
      } else if (link.startsWith('vmess://')) {
        final data = link.substring(8);
        final decoded = utf8.decode(base64.decode(data));
        final map = json.decode(decoded);
        return Uri(host: map['add'], port: int.parse(map['port'].toString()));
      } else if (link.startsWith('trojan://')) {
        return Uri.parse(link);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _init() async {
    _configBox = await Hive.openBox<VpnConfig>('vpn_configs');
    _groupBox = await Hive.openBox<VpnGroup>('vpn_groups');
    _settingsBox = await Hive.openBox('settings');
    
    // Create default group if none exists
    if (_groupBox.isEmpty) {
      final defaultGroup = VpnGroup(
        id: 'default',
        name: 'Default Group',
        createdAt: DateTime.now(),
      );
      await _groupBox.put(defaultGroup.id, defaultGroup);
    }

    _loadData(isInitial: true);
  }

  void _loadData({bool isInitial = false}) {
    _groups = _groupBox.values.toList();
    _configs = _configBox.values.toList();
    
    if (isInitial) {
      _selectedConfigId = _settingsBox.get('last_config_id');
      _selectedGroupId = _settingsBox.get('last_group_id');
    }

    // Validate and set defaults if selection is invalid or missing
    if (_groups.isNotEmpty) {
      if (_selectedGroupId == null || !_groups.any((g) => g.id == _selectedGroupId)) {
        _selectedGroupId = _groups.first.id;
      }
    }
    
    if (_configs.isNotEmpty) {
      if (_selectedConfigId == null || !_configs.any((c) => c.id == _selectedConfigId)) {
        // Try to pick first config from selected group
        final groupConfigs = getConfigsByGroup(_selectedGroupId ?? 'default');
        if (groupConfigs.isNotEmpty) {
          _selectedConfigId = groupConfigs.first.id;
        } else {
          _selectedConfigId = _configs.first.id;
        }
      }
    }
    
    notifyListeners();
  }

  Future<void> selectConfig(String id) async {
    _selectedConfigId = id;
    await _settingsBox.put('last_config_id', id);
    notifyListeners();
  }

  Future<void> selectGroup(String id) async {
    _selectedGroupId = id;
    await _settingsBox.put('last_group_id', id);
    _loadData(); // Refresh selection logic for configs in this group
    notifyListeners();
  }

  Future<void> addGroup(String name, {String? subscriptionUrl, bool isAutoOptimize = false}) async {
    final group = VpnGroup(
      id: const Uuid().v4(),
      name: name,
      createdAt: DateTime.now(),
      subscriptionUrl: subscriptionUrl,
      isAutoOptimizeEnabled: isAutoOptimize,
    );
    await _groupBox.put(group.id, group);
    _loadData();
    
    if (subscriptionUrl != null && subscriptionUrl.isNotEmpty) {
      await updateSubscription(group.id);
    }

    if (group.isAutoOptimizeEnabled) {
      optimizeGroup(group.id);
    }
  }

  Future<void> updateGroup(VpnGroup group) async {
    final oldGroup = _groupBox.get(group.id);
    await _groupBox.put(group.id, group);
    _loadData();
    
    // If auto-optimize was just enabled, trigger it immediately
    if (group.isAutoOptimizeEnabled && (oldGroup == null || !oldGroup.isAutoOptimizeEnabled)) {
      optimizeGroup(group.id);
    }
  }

  Future<void> updateConfig(VpnConfig config) async {
    await _configBox.put(config.id, config);
    _loadData();
  }

  Future<void> deleteGroup(String id) async {
    if (id == 'default') return;
    await _groupBox.delete(id);
    
    final configsInGroup = _configs.where((c) => c.groupId == id).toList();
    for (var config in configsInGroup) {
      final updated = config.copyWith(groupId: 'default');
      await _configBox.put(updated.id, updated);
    }
    
    if (_selectedGroupId == id) {
      _selectedGroupId = 'default';
      await _settingsBox.put('last_group_id', 'default');
    }
    _loadData();
  }

  Future<bool> updateSubscription(String groupId) async {
    final group = _groupBox.get(groupId);
    if (group == null || group.subscriptionUrl == null || group.subscriptionUrl!.isEmpty) return false;

    _isUpdating = true;
    notifyListeners();

    try {
      final response = await http.get(Uri.parse(group.subscriptionUrl!));
      if (response.statusCode == 200) {
        String content = response.body;
        
        // Handle Base64 if needed (many subscriptions are base64 encoded)
        try {
          content = utf8.decode(base64.decode(content.trim()));
        } catch (_) {
          // Not base64, use as is
        }

        final lines = content.split(RegExp(r'\r?\n'));
        
        // Remove old configs from this group
        final oldConfigs = _configs.where((c) => c.groupId == groupId).toList();
        for (var c in oldConfigs) {
          await _configBox.delete(c.id);
        }

        // Add new configs
        for (var line in lines) {
          if (line.trim().isEmpty) continue;
          await _addConfigFromLinkInternal(line.trim(), groupId);
        }

        final updatedGroup = group.copyWith(lastUpdated: DateTime.now());
        await _groupBox.put(groupId, updatedGroup);
        
        _loadData();
        return true;
      }
    } catch (e) {
      debugPrint('Subscription Update Error: $e');
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
    return false;
  }

  Future<bool> importFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null || data!.text!.isEmpty) return false;

    final link = data.text!.trim();
    return await addConfigFromLink(link);
  }

  Future<bool> addConfigFromLink(String link) async {
    final success = await _addConfigFromLinkInternal(link, _selectedGroupId ?? 'default');
    if (success) {
      _loadData();
    }
    return success;
  }

  Future<bool> _addConfigFromLinkInternal(String link, String groupId) async {
    try {
      final fullJson = XrayConfigConverter.convertToFullJson(link);
      
      String name = "New Config";
      if (link.contains('#')) {
        name = Uri.decodeComponent(link.split('#').last);
      }

      final config = VpnConfig(
        id: const Uuid().v4(),
        name: name,
        rawLink: link,
        fullJsonConfig: fullJson,
        groupId: groupId,
        createdAt: DateTime.now(),
      );

      await _configBox.put(config.id, config);
      if (groupId == _selectedGroupId) {
         _selectedConfigId = config.id;
         await _settingsBox.put('last_config_id', config.id);
      }
      return true;
    } catch (e) {
      debugPrint('Import Error: $e');
      return false;
    }
  }

  Future<void> deleteConfig(String id) async {
    await _configBox.delete(id);
    if (_selectedConfigId == id) {
      _selectedConfigId = _configs.isNotEmpty ? _configs.first.id : null;
      if (_selectedConfigId != null) {
        await _settingsBox.put('last_config_id', _selectedConfigId);
      } else {
        await _settingsBox.delete('last_config_id');
      }
    }
    _loadData();
  }

  List<VpnConfig> getConfigsByGroup(String groupId) {
    return _configs.where((c) => c.groupId == groupId).toList();
  }
}
