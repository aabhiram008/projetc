import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/dispenser_controller.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => DispenserController()..initialize(),
      child: const DispenserApp(),
    ),
  );
}

class DispenserApp extends StatelessWidget {
  const DispenserApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Medicine Dispenser',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF087F8C),
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: const Color(0xFFF3F7F8),
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
          ),
        ),
        home: const HomeScreen(),
      );
}
