import 'package:flutter/material.dart';
import 'app_shell.dart';
import 'app_globals.dart';

void main() {
  runApp(const SutaApp());
}

class SutaApp extends StatelessWidget {
  const SutaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: scaffoldMessengerKey, // ✅ add this
      debugShowCheckedModeBanner: false,
      title: "SUTA",
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E6BE6)),
      ),
      home: const AppShell(),
    );
  }
}