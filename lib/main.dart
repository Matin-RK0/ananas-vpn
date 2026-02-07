import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'data/services/vpn_service.dart';
import 'data/utils/hive_adapters.dart';
import 'presentation/providers/vpn_provider.dart';
import 'presentation/providers/config_provider.dart';
import 'presentation/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive
  await Hive.initFlutter();
  Hive.registerAdapter(VpnConfigAdapter());
  Hive.registerAdapter(VpnGroupAdapter());
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<VpnService>(create: (_) => VpnService()..initialize()),
        ChangeNotifierProxyProvider<VpnService, ConfigProvider>(
          create: (context) => ConfigProvider(vpnService: context.read<VpnService>()),
          update: (context, vpnService, configProvider) => configProvider!,
        ),
        ChangeNotifierProxyProvider<ConfigProvider, VpnProvider>(
          create: (context) => VpnProvider(context.read<VpnService>()),
          update: (context, configProvider, vpnProvider) {
            vpnProvider?.updateSelectedConfig(configProvider.selectedConfig);
            return vpnProvider!;
          },
        ),
      ],
      child: MaterialApp(
        title: 'Ananas VPN',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
