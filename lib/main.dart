import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'services/connection_service.dart';
import 'screens/home_screen.dart';
import 'database/database_seeder.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();  
  if(kDebugMode) await DatabaseSeeder.seed();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectionService()..init()),
      ],
      child: const BFPASApp(),
    ),
  );
}

class BFPASApp extends StatelessWidget{
  const BFPASApp({super.key});

  @override
  Widget build(BuildContext context){
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
      home: const HomeScreen(),
    );
  }
}