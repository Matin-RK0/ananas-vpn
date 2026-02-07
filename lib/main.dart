import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data/services/vpn_service.dart';
import 'presentation/providers/vpn_provider.dart';
import 'presentation/screens/home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<VpnService>(create: (_) => VpnService()..initialize()),
        ChangeNotifierProvider<VpnProvider>(
          create: (context) => VpnProvider(context.read<VpnService>()),
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
