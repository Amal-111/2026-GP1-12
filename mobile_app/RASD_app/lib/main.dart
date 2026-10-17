import 'package:flutter/material.dart';
import 'screens/home.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const RasdApp());
}

class RasdApp extends StatelessWidget {
  const RasdApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RASD',
      theme: AppTheme.lightTheme,
      home: const HomeScreen(),
    );
  }
}
