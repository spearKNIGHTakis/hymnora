import 'package:flutter/material.dart';
import 'screens/app_shell.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const HymnoraApp());
}

class HymnoraApp extends StatelessWidget {
  const HymnoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PCG Hymns',
      theme: AppTheme.light,
      home: const AppShell(),
    );
  }
}