import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vpn_provider.dart';
import '../providers/config_provider.dart';
import '../../domain/models/vpn_config.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final vpnProvider = Provider.of<VpnProvider>(context);
    final configProvider = Provider.of<ConfigProvider>(context);
    final status = vpnProvider.status;

    final currentGroup = configProvider.groups.firstWhere(
      (g) => g.id == configProvider.selectedGroupId,
      orElse: () =>
          VpnGroup(id: '', name: 'Ananas VPN', createdAt: DateTime.now()),
    );

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF1A1A1A),
      drawer: _buildDrawer(context, configProvider),
      body: SafeArea(
        child: Column(
          children: [
            _buildModernAppBar(context, configProvider, currentGroup),
            // Status Header
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2C),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatusItem(
                    Icons.download,
                    'Down',
                    _formatSpeed(status.downloadSpeed),
                  ),
                  _buildStatusItem(
                    Icons.upload,
                    'Up',
                    _formatSpeed(status.uploadSpeed),
                  ),
                  _buildStatusItem(Icons.timer, 'Time', status.duration),
                  if (vpnProvider.isConnected && status.delay != null)
                    _buildStatusItem(
                      Icons.bolt,
                      'Real Delay',
                      '${status.delay}ms',
                    ),
                ],
              ),
            ),

            // Config List
            Expanded(
              child: ListView.builder(
                itemCount: configProvider
                    .getConfigsByGroup(
                      configProvider.selectedGroupId ?? 'default',
                    )
                    .length,
                itemBuilder: (context, index) {
                  final config = configProvider.getConfigsByGroup(
                    configProvider.selectedGroupId ?? 'default',
                  )[index];
                  final isSelected =
                      configProvider.selectedConfigId == config.id;

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    color: isSelected
                        ? Colors.deepPurple.withOpacity(0.3)
                        : const Color(0xFF2C2C2C),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: isSelected
                          ? const BorderSide(color: Colors.deepPurple, width: 2)
                          : BorderSide.none,
                    ),
                    child: ListTile(
                      title: Text(
                        config.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Row(
                        children: [
                          Text(
                            config.remark.isNotEmpty
                                ? config.remark
                                : _getProtocolFromLink(config.rawLink),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 12,
                            ),
                          ),
                          if (config.lastLatency != null) ...[
                            const SizedBox(width: 12),
                            Icon(
                              config.lastLatency == -1 ? Icons.error_outline : Icons.bolt,
                              size: 12,
                              color: config.lastLatency == -1 ? Colors.redAccent : Colors.amber,
                            ),
                            Text(
                              config.lastLatency == -1 ? 'Time Out' : '${config.lastLatency}ms',
                              style: TextStyle(
                                color: config.lastLatency == -1 
                                  ? Colors.redAccent 
                                  : _getLatencyColor(config.lastLatency!),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                          if (config.lastDownloadSpeed != null) ...[
                            const SizedBox(width: 12),
                            const Icon(Icons.download, size: 12, color: Colors.blueAccent),
                            Text(
                              _formatDownloadSpeed(config.lastDownloadSpeed!),
                              style: const TextStyle(
                                color: Colors.blueAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                      leading: CircleAvatar(
                        backgroundColor: Colors.deepPurple.withOpacity(0.2),
                        child: Icon(
                          _getProtocolIcon(config.rawLink),
                          color: Colors.deepPurple,
                          size: 20,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSelected)
                            IconButton(
                              icon: const Icon(
                                Icons.speed,
                                color: Colors.blueAccent,
                                size: 20,
                              ),
                              onPressed: () async {
                                if (vpnProvider.isConnected) {
                                  // Clear old values first to show testing state
                                  final clearedConfig = config.copyWith(
                                    lastLatency: null,
                                    lastDownloadSpeed: null,
                                  );
                                  await configProvider.updateConfig(clearedConfig);

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Testing real delay and speed...'), duration: Duration(seconds: 1)),
                                  );
                                  
                                  final delay = await configProvider.getRealDelay();
                                  final speed = await configProvider.checkSpeed(config);
                                  
                                  final updatedConfig = config.copyWith(
                                    lastLatency: delay,
                                    lastDownloadSpeed: speed,
                                  );
                                  await configProvider.updateConfig(updatedConfig);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please connect first to test real delay')),
                                  );
                                }
                              },
                              tooltip: 'Test Speed',
                            ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                              size: 20,
                            ),
                            onPressed: () => configProvider.deleteConfig(config.id),
                          ),
                        ],
                      ),
                      onTap: () => configProvider.selectConfig(config.id),
                    ),
                  );
                },
              ),
            ),

            // Connection Toggle
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: GestureDetector(
                onTap: vpnProvider.toggleConnection,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: vpnProvider.isConnected
                        ? Colors.green
                        : const Color(0xFF3A3A3A),
                    boxShadow: [
                      BoxShadow(
                        color:
                            (vpnProvider.isConnected
                                    ? Colors.green
                                    : Colors.black)
                                .withOpacity(0.3),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    vpnProvider.isConnected ? Icons.stop : Icons.play_arrow,
                    size: 45,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                status.state,
                style: TextStyle(
                  color: vpnProvider.isConnected
                      ? Colors.green
                      : Colors.white60,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getProtocolFromLink(String link) {
    if (link.startsWith('vless://')) return 'VLESS';
    if (link.startsWith('vmess://')) return 'VMess';
    if (link.startsWith('trojan://')) return 'Trojan';
    if (link.startsWith('ss://')) return 'Shadowsocks';
    return 'Unknown';
  }

  IconData _getProtocolIcon(String link) {
    if (link.startsWith('vless://')) return Icons.bolt;
    if (link.startsWith('vmess://')) return Icons.rocket_launch;
    if (link.startsWith('trojan://')) return Icons.security;
    return Icons.vpn_lock;
  }

  Widget _buildModernAppBar(
    BuildContext context,
    ConfigProvider configProvider,
    VpnGroup currentGroup,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.menu_rounded,
              color: Colors.white70,
              size: 28,
            ),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  currentGroup.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (currentGroup.lastUpdated != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 10,
                          color: Colors.white38,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(currentGroup.lastUpdated!),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white38,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // Actions Group
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Optimization Button
                if (configProvider.isUpdating)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.amber,
                      ),
                    ),
                  )
                else
                  IconButton(
                    icon: const Icon(
                      Icons.auto_awesome,
                      color: Colors.amber,
                      size: 20,
                    ),
                    onPressed: () async {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Optimizing group...')),
                      );
                      await configProvider.optimizeGroup(currentGroup.id);
                    },
                    tooltip: 'Optimize Now',
                  ),
                
                if (currentGroup.subscriptionUrl != null &&
                    currentGroup.subscriptionUrl!.isNotEmpty)
                  IconButton(
                    icon: const Icon(
                      Icons.sync,
                      color: Colors.deepPurpleAccent,
                      size: 20,
                    ),
                    onPressed: () async {
                      final success = await configProvider.updateSubscription(currentGroup.id);
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Subscription updated')),
                        );
                      }
                    },
                    tooltip: 'Update Subscription',
                  ),
                
                IconButton(
                  icon: const Icon(
                    Icons.content_paste_rounded,
                    color: Colors.white70,
                    size: 20,
                  ),
                  onPressed: () async {
                    final success = await configProvider.importFromClipboard();
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Imported from clipboard')),
                      );
                    }
                  },
                  tooltip: 'Import from Clipboard',
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, ConfigProvider provider) {
    return Drawer(
      backgroundColor: const Color(0xFF1A1A1A),
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.deepPurple),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.shield, size: 40, color: Colors.white),
                      const SizedBox(height: 10),
                      const Text(
                        'Ananas VPN',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${provider.configs.length} Configs',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: IconButton(
                    icon: const Icon(Icons.add_box_outlined, color: Colors.white70),
                    onPressed: () => _showAddGroupDialog(context, provider),
                    tooltip: 'Add Group',
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: provider.groups.length,
              itemBuilder: (context, index) {
                final group = provider.groups[index];
                final isSelected = provider.selectedGroupId == group.id;
                final isSub =
                    group.subscriptionUrl != null &&
                    group.subscriptionUrl!.isNotEmpty;

                return ListTile(
                  leading: Icon(
                    isSub ? Icons.rss_feed : Icons.folder,
                    color: isSelected ? Colors.deepPurple : Colors.white60,
                    size: 20,
                  ),
                  title: Text(
                    group.name,
                    style: TextStyle(
                      color: isSelected ? Colors.deepPurple : Colors.white,
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  subtitle: isSub
                      ? const Text(
                          'Subscription',
                          style: TextStyle(fontSize: 10, color: Colors.white38),
                        )
                      : null,
                  selected: isSelected,
                  onTap: () {
                    provider.selectGroup(group.id);
                    Navigator.pop(context);
                  },
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          group.isAutoOptimizeEnabled ? Icons.bolt : Icons.bolt_outlined,
                          size: 18,
                          color: group.isAutoOptimizeEnabled ? Colors.amber : Colors.white24,
                        ),
                        onPressed: () {
                          final updatedGroup = group.copyWith(
                            isAutoOptimizeEnabled: !group.isAutoOptimizeEnabled,
                          );
                          provider.updateGroup(updatedGroup);
                        },
                        tooltip: 'Toggle Auto-Optimize',
                      ),
                      if (group.id != 'default')
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Colors.redAccent,
                          ),
                          onPressed: () => provider.deleteGroup(group.id),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const Divider(color: Colors.white10),
          ListTile(
            leading: const Icon(
              Icons.settings,
              color: Colors.white60,
              size: 20,
            ),
            title: const Text(
              'Settings',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            onTap: () {
              // Settings logic
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStatusItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.deepPurple, size: 18),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 10),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Color _getLatencyColor(int latency) {
    if (latency < 150) return Colors.greenAccent;
    if (latency < 300) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  String _formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond < 1024) return '$bytesPerSecond B/s';
    if (bytesPerSecond < 1024 * 1024)
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  String _formatDownloadSpeed(double mbps) {
    if (mbps < 1) {
      return '${(mbps * 1024).toStringAsFixed(1)} KB/s';
    }
    return '${mbps.toStringAsFixed(1)} MB/s';
  }

  String _formatDate(DateTime date) {
    return '${date.hour}:${date.minute.toString().padLeft(2, '0')} - ${date.year}/${date.month}/${date.day}';
  }

  void _showAddGroupDialog(BuildContext context, ConfigProvider provider) {
    final nameController = TextEditingController();
    final subController = TextEditingController();
    bool isAutoOpt = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF2C2C2C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Add New Group',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Group Name',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.black12,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: subController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Subscription URL (Optional)',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.black12,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Auto Optimize',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
                subtitle: const Text('Update & select best every 60m',
                    style: TextStyle(color: Colors.white38, fontSize: 11)),
                value: isAutoOpt,
                activeColor: Colors.deepPurpleAccent,
                onChanged: (val) => setState(() => isAutoOpt = val),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  provider.addGroup(
                    nameController.text,
                    subscriptionUrl: subController.text.isNotEmpty
                        ? subController.text
                        : null,
                    isAutoOptimize: isAutoOpt,
                  );
                  Navigator.pop(context);
                }
              },
              child: const Text(
                'Add Group',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
