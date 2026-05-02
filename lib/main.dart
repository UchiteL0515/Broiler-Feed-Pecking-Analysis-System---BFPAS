import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/connection_service.dart';
import 'screens/home_screen.dart';
import 'screens/animated_splash_screen.dart';
import 'screens/onboard/about_app_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectionService()..init()),
      ],
      child: const BFPASApp(),
    ),
  );
}

class BFPASApp extends StatelessWidget {
  const BFPASApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BFPAS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 2,
        ),
      ),
      home: const AnimatedSplashScreen(),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/onboard': (context) => AboutAppScreen(),
      },
    );
  }
}