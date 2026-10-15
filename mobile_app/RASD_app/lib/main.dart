import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'interfaces/home.dart';
import 'list/palm_list.dart';
import 'map/palm_map.dart';
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
      //home: const HomeScreen(),
      //home: const PalmListPage(),
      home: const FarmMapPage(),
    );
  }
}