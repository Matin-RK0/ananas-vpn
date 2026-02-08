import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../providers/vpn_provider.dart';
import '../providers/config_provider.dart';
import '../../domain/models/vpn_config.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late AnimationController _pulseController;
  late AnimationController _rotateController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

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
      backgroundColor: const Color(0xFF0F0F0F),
      drawer: _buildDrawer(context, configProvider),
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.5,
            colors: [
              (vpnProvider.isConnected ? Colors.green : Colors.deepPurple).withOpacity(0.15),
              const Color(0xFF0F0F0F),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildModernAppBar(context, configProvider, currentGroup),
              // Status Header
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatusItem(
                        Icons.arrow_downward_rounded,
                        'Download',
                        status.downloadSpeed,
                        Colors.blueAccent,
                        isSpeed: true,
                      ),
                    ),
                    Expanded(
                      child: _buildStatusItem(
                        Icons.arrow_upward_rounded,
                        'Upload',
                        status.uploadSpeed,
                        Colors.purpleAccent,
                        isSpeed: true,
                      ),
                    ),
                    Expanded(
                      child: _buildStatusItem(
                        Icons.bolt_rounded,
                        'Real Delay',
                        vpnProvider.lastSuccessfulDelay,
                        Colors.amberAccent,
                      ),
                    ),
                  ],
                ),
              ),

          // Config List
          Expanded(
            child: Consumer<ConfigProvider>(
              builder: (context, configProvider, child) {
                final currentGroupConfigs = configProvider.getConfigsByGroup(configProvider.selectedGroupId ?? 'default');
                
                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(top: 10, bottom: 120),
                  itemCount: currentGroupConfigs.length,
                  itemBuilder: (context, index) {
                    final config = currentGroupConfigs[index];
                    final isSelected = configProvider.selectedConfigId == config.id;

                    // Professional animated wrapper for each card
                    return _AnimatedConfigCard(
                      key: ValueKey(config.id),
                      index: index,
                      child: _buildModernConfigCard(config, isSelected, vpnProvider, configProvider),
                    );
                  },
                );
              },
            ),
          ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildConnectButton(vpnProvider, configProvider, status),
    );
  }

  Widget _buildModernConfigCard(VpnConfig config, bool isSelected, VpnProvider vpnProvider, ConfigProvider configProvider) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? Colors.deepPurple.withOpacity(0.15) : Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected ? Colors.deepPurpleAccent.withOpacity(0.5) : Colors.white.withOpacity(0.05),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          onTap: () => configProvider.selectConfig(config.id),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isSelected ? Colors.deepPurpleAccent.withOpacity(0.2) : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              _getProtocolIcon(config.rawLink),
              color: isSelected ? Colors.deepPurpleAccent : Colors.white70,
              size: 24,
            ),
          ),
          title: Text(
            config.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.9),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              fontSize: 15,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _getProtocolFromLink(config.rawLink),
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
                  ),
                ),
                if (config.lastLatency != null) ...[
                  const SizedBox(width: 10),
                  Icon(
                    config.lastLatency == -1 ? Icons.error_outline : Icons.bolt,
                    size: 14,
                    color: config.lastLatency == -1 ? Colors.redAccent : Colors.amberAccent,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    config.lastLatency == -1 ? 'Time Out' : '${config.lastLatency}ms',
                    style: TextStyle(
                      color: config.lastLatency == -1 ? Colors.redAccent : _getLatencyColor(config.lastLatency!),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
                if (config.lastDownloadSpeed != null) ...[
                  const SizedBox(width: 10),
                  const Icon(Icons.download_rounded, size: 14, color: Colors.blueAccent),
                  const SizedBox(width: 4),
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
          ),
          trailing: isSelected ? IconButton(
            icon: const Icon(Icons.speed_rounded, color: Colors.blueAccent),
            onPressed: () => _testSpeedManual(config, vpnProvider, configProvider),
          ) : IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
            onPressed: () => configProvider.deleteConfig(config.id),
          ),
        ),
      ),
    );
  }

  Future<void> _testSpeedManual(VpnConfig config, VpnProvider vpnProvider, ConfigProvider configProvider) async {
    if (vpnProvider.isConnected) {
      final clearedConfig = config.copyWith(lastLatency: null, lastDownloadSpeed: null);
      await configProvider.updateConfig(clearedConfig);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Testing real delay and speed...'), duration: Duration(seconds: 1)),
      );
      final delay = await configProvider.getRealDelay();
      final speed = await configProvider.checkSpeed(config);
      final updatedConfig = config.copyWith(lastLatency: delay, lastDownloadSpeed: speed);
      await configProvider.updateConfig(updatedConfig);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please connect first to test real delay')),
      );
    }
  }

  Widget _buildConnectButton(VpnProvider vpnProvider, ConfigProvider configProvider, dynamic status) {
    final bool isConnected = vpnProvider.isConnected;
    final bool isConnecting = vpnProvider.isConnecting;
    
    return GestureDetector(
      onTap: () {
        if (isConnected) {
          vpnProvider.disconnect();
        } else {
          final config = configProvider.selectedConfig;
          if (config != null) {
            vpnProvider.toggleConnection(config);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('لطفاً ابتدا یک کانفیگ انتخاب کنید'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        }
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Dynamic Glow
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final color = isConnecting 
                  ? Colors.amberAccent 
                  : (isConnected ? Colors.greenAccent : Colors.deepPurpleAccent);
              return Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.15 * _pulseController.value),
                      blurRadius: 30 * _pulseController.value,
                      spreadRadius: 15 * _pulseController.value,
                    ),
                  ],
                ),
              );
            },
          ),
          // Inner Ring
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final color = isConnecting 
                  ? Colors.amberAccent 
                  : (isConnected ? Colors.greenAccent : Colors.deepPurpleAccent);
              return Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.withOpacity(0.2 * (1 - _pulseController.value)),
                    width: 2,
                  ),
                ),
              );
            },
          ),
          // Main Button
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 85,
            height: 85,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isConnecting
                    ? [Colors.amberAccent, Colors.orange]
                    : isConnected 
                        ? [Colors.greenAccent, Colors.green] 
                        : [Colors.deepPurpleAccent, Colors.deepPurple],
              ),
              boxShadow: [
                BoxShadow(
                  color: (isConnecting 
                          ? Colors.orange 
                          : (isConnected ? Colors.green : Colors.deepPurple)).withOpacity(0.6),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              isConnecting 
                  ? Icons.sync_rounded
                  : (isConnected ? Icons.power_settings_new_rounded : Icons.bolt_rounded),
              size: 40,
              color: Colors.white,
            ),
          ),
          // Progress/Status Ring
          if (isConnected || isConnecting)
            RotationTransition(
              turns: _rotateController,
              child: SizedBox(
                width: 110,
                height: 110,
                child: CircularProgressIndicator(
                  value: isConnecting ? null : 1.0,
                  strokeWidth: 3,
                  color: isConnecting ? Colors.amberAccent : Colors.greenAccent,
                  backgroundColor: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.menu_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        currentGroup.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (currentGroup.lastUpdated != null)
                        Text(
                          'Updated: ${_formatDate(currentGroup.lastUpdated!)}',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.white.withOpacity(0.4),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                // Actions Group
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (configProvider.isUpdating)
                        const Padding(
                          padding: EdgeInsets.all(10),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.amberAccent,
                            ),
                          ),
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.auto_awesome_rounded, color: Colors.amberAccent, size: 18),
                          onPressed: () => configProvider.optimizeGroup(currentGroup.id),
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          padding: EdgeInsets.zero,
                        ),
                      
                      if (currentGroup.subscriptionUrl != null && currentGroup.subscriptionUrl!.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.sync_rounded, color: Colors.blueAccent, size: 18),
                          onPressed: () => configProvider.updateSubscription(currentGroup.id),
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          padding: EdgeInsets.zero,
                        ),
                      
                      IconButton(
                        icon: const Icon(Icons.add_link_rounded, color: Colors.white70, size: 18),
                        onPressed: () => configProvider.importFromClipboard(),
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusItem(IconData icon, String label, num? value, Color color, {bool isSpeed = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 20,
          child: _AnimatedStatusText(
            value: value,
            isSpeed: isSpeed,
            formatter: _formatSpeed,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildDrawer(BuildContext context, ConfigProvider provider) {
    return Drawer(
      backgroundColor: const Color(0xFF0F0F0F),
      child: Column(
        children: [
          // Modern Drawer Header
          Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.deepPurple.shade900,
                  const Color(0xFF0F0F0F),
                ],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -50,
                  right: -50,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.deepPurpleAccent.withOpacity(0.1),
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                              ),
                              child: const Icon(Icons.shield_rounded, size: 32, color: Colors.deepPurpleAccent),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white70, size: 28),
                              onPressed: () => _showAddGroupDialog(context, provider),
                            ),
                          ],
                        ),
                        const Spacer(),
                        const Text(
                          'Ananas VPN',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${provider.groups.length} Groups • ${provider.configs.length} Configs',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 10),
          
          // Groups List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: provider.groups.length,
              itemBuilder: (context, index) {
                final group = provider.groups[index];
                final isSelected = provider.selectedGroupId == group.id;
                final isSub = group.subscriptionUrl != null && group.subscriptionUrl!.isNotEmpty;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.deepPurpleAccent.withOpacity(0.1) : Colors.white.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? Colors.deepPurpleAccent.withOpacity(0.3) : Colors.white.withOpacity(0.05),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    onTap: () {
                      provider.selectGroup(group.id);
                      Navigator.pop(context);
                    },
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.deepPurpleAccent.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isSub ? Icons.rss_feed_rounded : Icons.folder_rounded,
                        color: isSelected ? Colors.deepPurpleAccent : Colors.white60,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      group.name,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white.withOpacity(0.8),
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                    subtitle: isSub ? Text(
                      'Subscription',
                      style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.3)),
                    ) : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            group.isAutoOptimizeEnabled ? Icons.bolt_rounded : Icons.bolt_outlined,
                            size: 20,
                            color: group.isAutoOptimizeEnabled ? Colors.amberAccent : Colors.white24,
                          ),
                          onPressed: () {
                            final updatedGroup = group.copyWith(
                              isAutoOptimizeEnabled: !group.isAutoOptimizeEnabled,
                            );
                            provider.updateGroup(updatedGroup);
                          },
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          padding: EdgeInsets.zero,
                        ),
                        if (group.id != 'default')
                          IconButton(
                            icon: const Icon(Icons.delete_sweep_rounded, size: 20, color: Colors.redAccent),
                            onPressed: () => provider.deleteGroup(group.id),
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            padding: EdgeInsets.zero,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Bottom Settings
          const Divider(color: Colors.white10, height: 1),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListTile(
              onTap: () {
                // Settings logic
              },
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              tileColor: Colors.white.withOpacity(0.02),
              leading: const Icon(Icons.settings_suggest_rounded, color: Colors.white60),
              title: const Text(
                'Settings',
                style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24),
            ),
          ),
        ],
      ),
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

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1.0).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutBack)),
            child: AlertDialog(
              backgroundColor: Colors.transparent,
              contentPadding: EdgeInsets.zero,
              content: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A).withOpacity(0.8),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: StatefulBuilder(
                      builder: (context, setState) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Add New Group',
                            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 24),
                          _buildModernTextField(nameController, 'Group Name', Icons.drive_file_rename_outline_rounded),
                          const SizedBox(height: 16),
                          _buildModernTextField(subController, 'Subscription URL (Optional)', Icons.link_rounded),
                          const SizedBox(height: 16),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: SwitchListTile(
                              title: const Text('Auto Optimize', style: TextStyle(color: Colors.white70, fontSize: 14)),
                              subtitle: const Text('Update & select best every 60m', style: TextStyle(color: Colors.white38, fontSize: 10)),
                              value: isAutoOpt,
                              activeColor: Colors.deepPurpleAccent,
                              onChanged: (val) => setState(() => isAutoOpt = val),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepPurpleAccent,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  onPressed: () {
                                    if (nameController.text.isNotEmpty) {
                                      provider.addGroup(
                                        nameController.text,
                                        subscriptionUrl: subController.text.isNotEmpty ? subController.text : null,
                                        isAutoOptimize: isAutoOpt,
                                      );
                                      Navigator.pop(context);
                                    }
                                  },
                                  child: const Text('Add Group', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModernTextField(TextEditingController controller, String hint, IconData icon) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.deepPurpleAccent, width: 1.5),
        ),
      ),
    );
  }
}

class _AnimatedStatusText extends StatefulWidget {
  final num? value;
  final bool isSpeed;
  final String Function(int) formatter;

  const _AnimatedStatusText({
    required this.value,
    required this.isSpeed,
    required this.formatter,
  });

  @override
  State<_AnimatedStatusText> createState() => _AnimatedStatusTextState();
}

class _AnimatedStatusTextState extends State<_AnimatedStatusText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _displayValue = 0;
  double _targetValue = 0;

  @override
  void initState() {
    super.initState();
    _displayValue = (widget.value ?? 0).toDouble();
    _targetValue = _displayValue;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _animation = Tween<double>(begin: _displayValue, end: _targetValue).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didUpdateWidget(_AnimatedStatusText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != null) {
      final newValue = widget.value!.toDouble();
      if (newValue != _targetValue) {
        // Start from current animated value to prevent jumps
        _displayValue = _animation.value;
        _targetValue = newValue;
        
        _animation = Tween<double>(begin: _displayValue, end: _targetValue).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
        );
        
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.value == null) {
      return const Text(
        '--',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      );
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        String displayStr = widget.isSpeed
            ? widget.formatter(_animation.value.toInt())
            : '${_animation.value.toInt()} ms';

        return Text(
          displayStr,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        );
      },
    );
  }
}

class _AnimatedConfigCard extends StatefulWidget {
  final Widget child;
  final int index;

  const _AnimatedConfigCard({super.key, required this.child, required this.index});

  @override
  State<_AnimatedConfigCard> createState() => _AnimatedConfigCardState();
}

class _AnimatedConfigCardState extends State<_AnimatedConfigCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );

    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    Future.delayed(Duration(milliseconds: (widget.index * 40).clamp(0, 500)), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: FractionalTranslation(
              translation: _slideAnimation.value,
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}
